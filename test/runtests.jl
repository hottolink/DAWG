using DAWG
using Base.Test

l = ["aaa","aab","aac","aaaxx","nmj","mit"]
println("testing Sparse Matrix DAWG...")
smdawg = makeSparseMatrixDAWG(l)
olist = DictionaryMatch("aaaaac",smdawg)
println(olist)
@test length(olist) == 2
@test olist[1][1] == 1
@test olist[1][2] == 3
@test olist[2][1] == 4
@test olist[2][2] == 6

println("testing Double Array DAWG...")
dadawg = makeDoubleArrayDAWG(l)
olist = DictionaryMatch("aaaaac",dadawg)
println(olist)
@test length(olist) == 2
@test olist[1][1] == 1
@test olist[1][2] == 3
@test olist[2][1] == 4
@test olist[2][2] == 6
