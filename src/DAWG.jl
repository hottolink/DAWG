module DAWG
using LegacyStrings
export DictionaryMatch, SparseMatrixDAWG, DoubleArrayDAWG,
        makeSparseMatrixDAWG, makeDoubleArrayDAWG

#declare sparse matrix based DAWG type
type SparseMatrixDAWG
  m::SparseMatrixCSC
  rownum::Int64
  colnum::Int64
  edgedict::Dict{Char,Int32}
end

#declare double array based DAWG type
type DoubleArrayDAWG
  b::Array{Int32,1}
  check::Array{Int32,1}
  rownum::Int64
  colnum::Int64
  edgedict::Dict{Char,Int32}
end

#DAWG object definition
type DawgNode
    id::Int32
    final::Bool
    edges::Dict
    count::Int32

    function DawgNode(id=0)
        self = new()

        self.id = id
        self.final = false
        self.edges = Dict{Char,DawgNode}()
        self.count = -1
        return self
    end

end

function str(self::DawgNode)
    arr = IOBuffer()
    if self.final
        write(arr,'1')
    else
        write(arr,'0')
    end
    for (label, node) in sort( collect(zip(keys(self.edges), values(self.edges))) )
        write(arr,label,'_',node.id,'_')
    end
    return takebuf_string(arr)
end

function numReachable(self::DawgNode)
    if self.count > 0
        return self.count
    end
    count = 0
    if self.final
        count += 1
    end
    for (label, node) in sort( collect(zip(keys(self.edges), values(self.edges))) )
        count += numReachable(node)
    end
    self.count = count
    return count
end

#declare DAWG type
type Dawg
    NextId::Int32
    previousWord::AbstractString
    root::DawgNode
    uncheckedNodes::Array
    data::Array
    minimizedNodes::Dict
    insert::Function
    _minimize::Function
    finish::Function
    lookup::Function
    nodeCount::Function
    edgeCount::Function

    function Dawg()
        self = new()
        self.NextId = 0
        self.previousWord = ""
        self.root = DawgNode(0)
        self.NextId += 1
        self.uncheckedNodes = []
        self.data = []
        self.minimizedNodes = Dict()


        self.insert = function(word,data)
            word
            word = utf32(word)
            if(word <= self.previousWord)
                println("Error: Words must be inserted in alphabetical order: ",word)
                return
            end
            commonPrefix = 0
            for i = 1:min(length(word),length(self.previousWord))
                word[i] == self.previousWord[i] ? commonPrefix += 1 : break
            end
            self._minimize(commonPrefix)
            node = length(self.uncheckedNodes) == 0 ? self.root : self.uncheckedNodes[end][3]
            for letter in word[(commonPrefix+1):end]
                nextNode = DawgNode(self.NextId)
                self.NextId += 1
                node.edges[letter] = nextNode
                push!(self.uncheckedNodes, (node,letter,nextNode) )
                node=nextNode
            end

            node.final = true
            self.previousWord = word
        end

        self._minimize = function(downTo)
            if(length(self.uncheckedNodes)<1)
                return
            end
            for i = length(self.uncheckedNodes):-1:(downTo+1)
                (parent, letter, child) = self.uncheckedNodes[i]
                if haskey(self.minimizedNodes,str(child))
                    parent.edges[letter] = self.minimizedNodes[str(child)]
                else
                    self.minimizedNodes[str(child)] = child
                end
                pop!(self.uncheckedNodes)
            end
        end

        self.finish = function()
            self._minimize( 0 )
            numReachable(self.root)
            self.minimizedNodes[str(self.root)] = self.root
        end

        self.lookup = function(word)
            word = utf32(word)
            node = self.root
            skipped = 0
            for letter in word
                if !haskey(node.edges,letter)
                    return ""
                end
                for (label, child) in sort( collect(zip(keys(node.edges), values(node.edges))) )
                    if label == letter
                        if node.final
                            skipped += 1
                        end
                        node=child
                        break
                    end
                    skipped += child.count
                end
            end

            if(node.final)
                println("<--- This is word. ($skipped)")
            end
        end

        self.nodeCount = function()
            return length(self.minimizedNodes)
        end

        self.edgeCount = function()
            count=0
            for (key,node) in zip(keys(self.minimizedNodes),values(self.minimizedNodes))
                count += length(node.edges)
            end
            return count
        end

        return self
    end
end

#recursively collect states with paths in DAWG
#used when constructing sparse matrix DAWG
#returns nothing but fills statedict, edgedict, donepathdict, and statecollect
function travrec(node,statedict,edgedict,donepathdict,statecollect)
    for path in keys(node.edges)
        if !haskey(statedict,node.id)
            statedict[node.id] = length(statedict)+1
            statecollect[node.id] = node
        end
        if !haskey(edgedict,path)
            edgedict[path] = length(edgedict)+1
        end

        if get(donepathdict,"$(node.id)$path",0) == node.edges[path].id
            return
        end
        donepathdict["$(node.id)$path"] = node.edges[path].id

        if(node.edges[path].final)
            if length(node.edges[path].edges) > 0
                travrec(node.edges[path],statedict,edgedict,donepathdict,statecollect)
            end
        else
            travrec(node.edges[path],statedict,edgedict,donepathdict,statecollect)
        end
    end
end

#recursively collect states with paths in DAWG
#used when constructing double array DAWG
#returns nothing but fills statedict, edgedict, donepathdict, and statecollect
function travrecBC(node,statedict,edgedict,donepathdict,statecollect,termnode)
    if !haskey(statedict,node.id)
        statedict[node.id] = length(statedict)+1
        statecollect[node.id] = node
    end

    if node.final && length(node.edges) == 0
        termnode[node.id] = node.id
        return
    end

    for path in keys(node.edges)
        if !haskey(edgedict,path)
            edgedict[path] = length(edgedict)+1
        end

        if get(donepathdict,(node.id,path),0) == node.edges[path].id
           return
        end
        donepathdict[(node.id,path)] = node.edges[path].id

        travrecBC(node.edges[path],statedict,edgedict,donepathdict,statecollect,termnode)
    end
    return termnode
end

#directly fill sparse matrix with DAWG states and transition information
function fillmatrixStraightIJV(rownum,colnum,statedict,edgedict,statecollect)
    const block = colnum
    I = zeros(Int32,block)
    J = zeros(Int32,block)
    V = zeros(Int32,block)

    cnt = 0
    element = 0
    statesize = length(statecollect)
    for k in sort(collect(keys(statecollect)))
        node = statecollect[k]
        cnt += 1
        if cnt%100000 == 0
            println("Done: $cnt / $statesize")
        end

        if length(I) < (element+block)
            I = vcat(I,zeros(Int32,block))
            J = vcat(J,zeros(Int32,block))
            V = vcat(V,zeros(Int32,block))
        end

        for path in keys(node.edges)
            element += 1
            I[element] = statedict[node.id]
            J[element] = edgedict[path]

            if(node.edges[path].final)
                if length(node.edges[path].edges) > 0
                    V[element] = -statedict[node.edges[path].id]
                else
                    V[element] = -rownum
                end
                continue
            end
            V[element] = statedict[node.edges[path].id]
        end
    end
    len = findlast(I)
    return sparse(I[1:len],J[1:len],V[1:len],rownum,colnum)
end

#perform dictionary match using sparse matrix DAWG
#input: sentence as a valid string, dawgdict as a sparse matrix based DAWG
#set extract = true (default) will display matched word as progressing
function DictionaryMatch(sentence,dawgdict::SparseMatrixDAWG; extract::Bool=true)
  rettuple = tokenizetuple(sentence,dawgdict.m,dawgdict.edgedict,dawgdict.rownum,dawgdict.colnum)
  if extract
    usentence = utf32(sentence)
    for (from,to) in rettuple
      println(usentence[from:to])
    end
  end
  rettuple
end

#perform dictionary matching scan with spare matrix based DAWG(inner use only)
function tokenizetuple(sentence,m::SparseMatrixCSC,edgedict,rownum,def)
    curstate = 1
    cutat = []
    curpos = 1
    lastbegin = 1
    lastgood = 1
    sentence = utf32(sentence)
    senlen = length(sentence)

    while curpos <= senlen
        @inbounds col = get(edgedict,sentence[curpos],def)
        @inbounds curstate = m[curstate,col]

        if (curstate > 0)
            curpos += 1
        elseif (curstate == 0)
             if (lastgood>lastbegin)
                push!(cutat,(lastbegin,lastgood))
            end
            curstate = 1
            lastbegin = curpos = lastgood+=1
        elseif (curstate<0)
            if (curstate==-rownum)
                push!(cutat,(lastbegin,curpos))
                curstate = 1
                lastbegin = lastgood = curpos+=1
            else
                curstate = -curstate
                lastgood = curpos
                curpos += 1
            end
        end
    end

    ##flush
    if (lastgood>lastbegin)
        push!(cutat,(lastbegin,lastgood))
    end

    return cutat
end

#perform dictionary match using double array DAWG
#input: sentence as a valid string, dawgdict as a sparse matrix based DAWG
#set extract = true (default) will display matched word as progressing
function DictionaryMatch(sentence,dawgdict::DoubleArrayDAWG; extract::Bool=true)
  rettuple = tokenizedoublearrayBC(sentence,dawgdict.edgedict,dawgdict.b,dawgdict.check)
  if extract
    usentence = utf32(sentence)
    for (from,to) in rettuple
      println(usentence[from:to])
    end
  end
  rettuple
end

#perform dictionary matching scan with double array based DAWG(inner use only)
function tokenizedoublearrayBC(sentence,edgedict,b,check)
    curstate = 2
    cutat = []
    curpos = 1
    lastbegin = 1
    lastgood = 1
    sentence = utf32(sentence)
    senlen = length(sentence)

    while curpos <= senlen
        @inbounds col = get(edgedict,sentence[curpos],0)
        if col == 0
            curstate = -1
        else
            if curstate > 1
                @inbounds p = b[curstate] + col
                @inbounds curstate = check[p] == b[curstate] ? p : -1
            end
        end

        if(curstate < 1)
            if(lastgood>lastbegin)
                push!(cutat,(lastbegin,lastgood))
            end
            curstate = 2
            lastbegin = curpos = lastgood+=1
        elseif(b[b[curstate]]==-1)
            push!(cutat,(lastbegin,curpos))
            curstate = 2
            lastbegin = lastgood = curpos+=1
        elseif(b[b[curstate]]==0)
            lastgood = curpos
            curpos += 1
        else
            curpos += 1
        end
    end

    ##flush
    if(lastgood>lastbegin)
        push!(cutat,(lastbegin,lastgood))
    end

    return cutat
end

#constrct a sparse matrix based DAWG from word list(dictionary)
#return SparseMatrixDAWG type
function makeSparseMatrixDAWG(list)
   println("Making DAWG... Please wait...")
   d = Dawg()
    for w in sort(list)
    d.insert(w,"hello")
   end
   d.finish()
   statedict = Dict()
   statenum = d.nodeCount()

   edgedict = Dict{Char,Int32}()
   edgenum = d.edgeCount()

   donepathdict = Dict()
   statecollect = Dict{Int32,DawgNode}()

   travrec(d.root,statedict,edgedict,donepathdict,statecollect)
   colnum = 1+length(edgedict)
   rownum = 1+length(statedict)

   m = fillmatrixStraightIJV(rownum,colnum,statedict,edgedict,statecollect)
   println("Done!")
   return  SparseMatrixDAWG(m,rownum,colnum,edgedict)
end

#find vacant space in double array (inner use only)
function x_checkBC(check,c_set)
    minc = minimum(c_set)
    firstvac = findnext(check,0,minc+2)
    bf = firstvac-minc
    runningbf = bf
    if maximum(bf .+ c_set) >= length(check)
        return 0
    end

    while sum(abs(check[ bf .+ c_set])) > 0  || bf<1
      firstvac = findnext(check,0,runningbf)
      if firstvac == 0
          return 0
      end
      #runningbf += 1
      runningbf = firstvac+1
      bf = firstvac-minc
      if maximum(bf .+ c_set) >= length(check)
          return 0
      end
    end
    check[ bf .+ c_set ] = bf
    return bf
end

#constrct double array based on data collected from tree based DAWG
function getdoublearrayBC(statedict,edgedict,statecollect,termnode)

    invn = Dict()
    fv = Dict()
    maxchmap = 5*(1+length(edgedict))
    check = zeros(Int32,maxchmap)
    b = zeros(Int32,maxchmap)

    check[1] = 1
    b[1] = -1
    check[2] = 0
    b[2] = 2

    for k in keys(termnode)
      fv[abs(statedict[k])] = 1
    end

    #filling check
    cnt = 0
    statesize = length(statecollect)
    for k in sort(collect(keys(statecollect))) #values(statecollect)

        node = statecollect[k]
        if haskey(termnode,node.id)
            continue
        end
        cnt += 1
        if cnt%10000 == 0
            println("1st Done: $cnt / $statesize")
        end

        c_set = [0]
        if(length(node.edges)>0)
            c_set = [c_set; map(x->edgedict[x],collect(keys(node.edges)))]
        end

        firstvac = 0
        while firstvac <= 0
            firstvac = x_checkBC(check,c_set)
            if firstvac <= 0
                b = vcat(b,zeros(Int32,maxchmap))
                check = vcat(check,zeros(Int32,maxchmap))
            end
        end

        fv[abs(statedict[node.id])] = firstvac
        if !node.final
          b[firstvac] = 2
        end
    end

    #filling base

    cnt = 0
    for node in values(statecollect)
        cnt += 1
        if cnt%10000 == 0
            println("2nd Done: $cnt / $statesize")
        end

        bf = fv[abs(statedict[node.id])]

        for path in keys(node.edges)
            if haskey(fv,abs(statedict[node.edges[path].id]))
              b[bf+edgedict[path]] = fv[abs(statedict[node.edges[path].id])]
            end
        end
    end

    maxb = maximum(b)+length(edgedict)
    sizediff = maxb-length(b)
    if maxb > length(b)
        b = [b;zeros(Int32,sizediff)]
        check = [check;zeros(Int32,sizediff)]
    end
    return (b,check,fv)
end

#constrct a sparse matrix based DAWG from word list(dictionary)
#return DoubleArrayDAWG type
function makeDoubleArrayDAWG(list)
   println("Making DAWG... Please wait...")
   d = Dawg()
   for w in sort(list)
     d.insert(w,"hello")
   end
   d.finish()
   statedict = Dict()
   statenum = d.nodeCount()

   edgedict = Dict{Char,Int32}()
   edgenum = d.edgeCount()

   donepathdict = Dict()
   statecollect = Dict{Int32,DawgNode}()

   termnode = Dict()
   travrecBC(d.root,statedict,edgedict,donepathdict,statecollect,termnode)
   colnum = 1+length(edgedict)
   rownum = 1+length(statedict)


   (b,check,fv) = getdoublearrayBC(statedict,edgedict,statecollect,termnode);
   println("Done!")
   return DoubleArrayDAWG(b,check,rownum,colnum,edgedict)
end

end # module
