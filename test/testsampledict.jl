using DAWG
using BenchmarkTools

#download csv dict from https://github.com/neologd/mecab-unidic-neologd/tree/master/seed
#decompress to any directory such as c:/tmp
#use only word with 3 to 11 characters (about 1.5 million words)

cd("C:/tmp")
sampledict = Dict()
f = open("mecab-unidic-user-dict-seed.20161215.csv")
for ln in eachline(f)
  word = (split(ln,","))[1]
  wlen = length(word)
  if wlen < 3 || wlen > 11
    continue
  end

  if !haskey(sampledict,word)
    sampledict[word]=true
  end
end
close(f)

l = collect(keys(sampledict))
println(length(l)," words in dictionary.")

@time smdawg = makeSparseMatrixDAWG(l)
#534.940754 seconds (673.87 M allocations: 30.877 GB, 18.57% gc time)

@time dadawg = makeDoubleArrayDAWG(l)

teststring = """
公開当日に生放送された。
出演者
木村拓哉
北川景子
陣内智則のプレゼンは時間の関係で省略になった（エンディングの浜辺のシーンで松たか子とのアドリブ）。
"""

smdawglist = DictionaryMatch(teststring,smdawg)
dadawglist = DictionaryMatch(teststring,dadawg)

@benchmark smdawglist = DictionaryMatch(teststring,smdawg,extract=false)

@benchmark dadawglist = DictionaryMatch(teststring,dadawg,extract=false)
