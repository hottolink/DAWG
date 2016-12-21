A Julia implementation of Directed Acyclic Word Graph (DAWG) on sparse matrix and Double-Array.

##How to install

### Install
In Julia terminal, just clone the package like below:

```
julia>Pkg.clone("https://github.com/hottolink/DAWG.git")
```

### Test the installation
Make sure the package is ready.

```
julia>Pkg.test("DAWG")
```
If everything is fine, you should get the following results:

```
INFO: Testing DAWG
testing Sparse Matrix DAWG...
aaa
aac
Any[(1,3),(4,6)]
testing Double Array DAWG...
aaa
aac
Any[(1,3),(4,6)]
INFO: DAWG tests passed
```


## Getting Started
The following code constructs and tests DAWG sample in Ref.1 with sparse matrix and Double-Array respectively. The "olist" variable holds the tuples of start and stop position of word(s) that matched the dictionary. (the variable "l" here)

```
using DAWG

#The toy sample dictionary in Ref.1
l =  ["aaa", "aba","bbc", "cbc", "cc"]

#try DAWG on sparse matrix
#construct a DAWG on sparse matrix
smdawg = makeSparseMatrixDAWG(l)

#now use the DAWG to find matched word(s) in a sample string.
olist = DictionaryMatch("aaaxxabacdecbc",smdawg)

#try DAWG on Double-Array in the same manner.
dadawg = makeDoubleArrayDAWG(l)
olist = DictionaryMatch("aaaxxabacdecbc",dadawg)
```
Both should return the following results:

```
aaa
aba
cbc
3-element Array{Any,1}:
 (1,3)
 (6,8)
 (12,14)
```

That's it! You may try with millions of words on your own and compare both approaches. However, I modified the Double-Array implementation myself so it might not follow what stated in the reference papers. And in all cases, I recommend using the sparse matrix DAWG!

## References
1. Comparisons of Efficient Implementations for DAWG: Masao Fuketa, Kazuhiro Morita, and Jun-ichi Aoe, International Journal of Computer Theory and Engineering, Vol. 8, No. 1, February 2016
2. A Retrieval Method for Double Array Structures by Using Byte N-Gram: Masao Fuketa, Kazuhiro Morita, and Jun-Ichi Aoe, International Journal of Computer Theory and Engineering, Vol. 6, No. 2, April 2014
3. Importance of Aho-Corasick String Matching Algorithm in Real World Applications: Saima Hasib, Mahak Motwani, Amit Saxena, International Journal of Computer Science and Information Technologies, Vol. 4 (3) , 2013, 467-469
4. Compressing dictionaries with a DAWG: [Steve Hanov’s Blog](http://stevehanov.ca/blog/index.php?id=115)


