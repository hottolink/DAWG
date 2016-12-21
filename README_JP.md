今回は、テキストマイニングのエンジニア向けに、以前ご紹介した「[大規模辞書マッチングを手軽に高速化してみた](https://www.hottolink.co.jp/blog/20161031-2)」のソースコードを、実験のために公開します。正式な資料は特にありませんが、下記の手順を一通り実行いただければ基本的な操作を体験できると思います。　
なお、前提としてある程度Julia言語が使える、またはJulia言語を始めても抵抗がないことを想定しています。初版では非効率な部分がまだまだ沢山ありますので、皆様からの改良改善点の共有をお待ちしております。

まず、DAWGパッケージの公開リポジトリは下記の通りです。 

https://github.com/hottolink/DAWG

このパッケージは、Julia言語で記述した疎行列及びダブル配列ベースDAWG(Directed Acyclic Word Graph)の実装です。ソースコードはリポジトリの「src」ディレクトリの下にあるDAWG.jlファイルにあります。約５００行程度で、２種類の省メモリDAWGの生成と参照機能が揃っています。

##How to install

###インストール
まず、Julia言語の実行環境をお持ちかどうかご確認ください。はじめての方はJulia言語の[正式ダウンロードサイト](http://julialang.org/downloads/)からバージョンv0.5.0をダウンロードし、インストールしてください。　各OS環境ごとのインストール方法については[各OSのインストール詳細ページ](http://julialang.org/downloads/platform.html)をご参考下さい。
※弊社ではv.0.5.0で動作確認を実施しています。


正常にインストールが完了したら、Juliaを実行し、Juliaコンソールを立ち上げましょう。 
次にJuliaコンソールから下記のコマンドを実行します。

```
julia>Pkg.clone("https://github.com/hottolink/DAWG.git")
```

## パッケージの検証
取得したパッケージが正しく動作しているかを検証するには下記のコマンドを実行します。 

```
julia>Pkg.test("DAWG")
```
特に問題がなければ、下記のような出力となります。 

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


##Getting started
下記のコードは参考論文１にあるDAWGのサンプルを再現し、検証します。ただし、ここではDAWGの情報を疎行列及びダブル配列で保持し、それぞれのタイプでの動作を確認します。「olist」変数はマッチした単語の開始と終了位置（元本文中の位置）のタプルです。なお、サンプル辞書は変数「l」で定義しています。 

```
using DAWG

#参考論文１にあったサンプル辞書
l =  ["aaa", "aba","bbc", "cbc", "cc"]

#まずは疎行列ベースのDAWGを試します。
#辞書から疎行列を作成します。
smdawg = makeSparseMatrixDAWG(l)

#次にサンプル文字列から辞書にマッチした単語を列挙します。
olist = DictionaryMatch("aaaxxabacdecbc",smdawg)

#今度はダブル配列ベースのDAWGを試します。
dadawg = makeDoubleArrayDAWG(l)
olist = DictionaryMatch("aaaxxabacdecbc",dadawg)
```
問題なく動作してくれた場合は、両方の実行は下記のように出力します。

```
aaa
aba
cbc
3-element Array{Any,1}:
 (1,3)
 (6,8)
 (12,14)
```

ここまでは、元辞書から２種類のDAWGの生成及び参照が簡単にできることを紹介しました。 次にもっと大きな辞書で作成時間と動作を確認します。 

サンプル辞書はオープンソースの[neologd](https://github.com/neologd/mecab-unidic-neologd)のユーザ辞書を題材にします。規模的にも質的にも十分本パッケージの性能が発揮できるのではないかと思います。辞書自体は再配布しませんので、どうぞ下記のサイトから「mecab-unidic-user-dict-seed.xxxxxxxx.csv.xz」といったファイルを取得し、好きなディレクトリに解凍して下さい。ここでは「c:\tmp」とします。この実験では辞書の中にある単語で長さ３文字から１１文字までだけに絞ります。それでも約２１２万語の辞書が出来上がります。

https://github.com/neologd/mecab-unidic-neologd/tree/master/seed

対象単語数が多いかつ生成アルゴリズムの効率化を今後の課題としているように、一旦実行するとかなり時間かかります。不安になるくらいかかりますが、焦らずにお待ち下さい。実験用の環境はCore i5-6200U @2.3GHz, メモリ8GB搭載のノートパソコンですが、作成時の統計は下記のとおりです。

| DAWGの種類 | 生成時間(秒) |
| ----- | -----  |
| 疎行列ベース | 535 |
| ダブル配列ベース | 3,845 |

ダブル配列ベースの生成部分は、コーディング時間短縮のため、論文の生成方法では実装せず、著者独自の方式で実装しておりますが、時間的な効率が良くないせいか、かなり時間がかかります。配列を最小限に抑えたいがために、空間的な効率を重視しすぎているかもしれません。この点はご容赦ください。 

では下記のコードを順番に実行してDAWGを生成してみましょう。

```
using DAWG

#辞書ファイルを読み込みます。
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

#単語リストを取得し、単語数を表示します。
l = collect(keys(sampledict))
println(length(l)," words in dictionary.")

#単語リストから疎行列ベースDAWGを生成する。ついでに作成時間や消費メモリを表示させる。
@time smdawg = makeSparseMatrixDAWG(l)

#単語リストからダブル配列ベースDAWGを生成する。ついでに作成時間や消費メモリを表示させる。
@time dadawg = makeDoubleArrayDAWG(l)

#テスト文はWikipediaから抜粋
#https://ja.wikipedia.org/wiki/HERO_(2015%E5%B9%B4%E3%81%AE%E6%98%A0%E7%94%BB)

teststring = """
公開当日に生放送された。
出演者
木村拓哉
北川景子
陣内智則のプレゼンは時間の関係で省略になった（エンディングの浜辺のシーンで松たか子とのアドリブ）。
"""

#疎行列ベースDAWGの参照
smdawglist = DictionaryMatch(teststring,smdawg)

#ダブル配列ベースDAWGの参照
dadawglist = DictionaryMatch(teststring,dadawg)

```

正常に動作すれば、下記のような出力となります。

```
生放送
出演者
木村拓哉
北川景子
陣内智則
プレゼン
エンディング
シーン
松たか子
アドリブ
10-element Array{Any,1}:
 (6,8)
 (14,16)
 (18,21)
 (23,26)
 (28,31)
 (33,36)
 (51,56)
 (61,63)
 (65,68)
 (71,74)
```

生成したDAWGがしっかりと動作していることが分かりました。 
最後に２種類のDAWGのパフォーマンスを比較しましょう。この作業には「BenchmarkTools」というパッケージが必要です。お持ちでない方は下記のコマンドを実行してインストールして下さい。


```
Pkg.add("BenchmarkTools")
```

準備が整ったら２種類のDAWGをベンチマークしてみましょう。 
コードの先頭に@benchmarkをつけるとJuliaはその後ろに来るコードを沢山実行し、かかる時間の統計を取りまとめてくれます。目安は10,000回程度での統計となります。 

最初に疎行列ベースをベンチマークします。

```
using BenchmarkTools

@benchmark smdawglist = DictionaryMatch(teststring,smdawg,extract=false)
```
すると下記のようにレポートされます。

```
BenchmarkTools.Trial:
  memory estimate:  4.61 kb
  allocs estimate:  233
  --------------
  minimum time:     12.800 μs (0.00% GC)
  median time:      13.653 μs (0.00% GC)
  mean time:        15.026 μs (3.86% GC)
  maximum time:     2.996 ms (98.01% GC)
  --------------
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
```

次にダブル配列ベースをベンチマークします。

```
@benchmark dadawglist = DictionaryMatch(teststring,dadawg,extract=false)
```

すると下記のようにレポートされます。

```
BenchmarkTools.Trial:
  memory estimate:  10.52 kb
  allocs estimate:  611
  --------------
  minimum time:     20.053 μs (0.00% GC)
  median time:      21.760 μs (0.00% GC)
  mean time:        24.401 μs (6.63% GC)
  maximum time:     5.523 ms (98.61% GC)
  --------------
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
```

わずかでありますが、実行時間の最小値、中央値、平均値、最大値すべての項目において疎行列ベースの方が高速であることが分かります。生成時間及び参照速度の傾向を考慮すると疎行列ベースDAWGがおすすめといった結論に至ったわけです。より技術的な詳しい情報が知りたい方は是非参考文献をご覧ください。


## 参考論文
1. Comparisons of Efficient Implementations for DAWG: Masao Fuketa, Kazuhiro Morita, and Jun-ichi Aoe, International Journal of Computer Theory and Engineering, Vol. 8, No. 1, February 2016
2. A Retrieval Method for Double Array Structures by Using Byte N-Gram: Masao Fuketa, Kazuhiro Morita, and Jun-Ichi Aoe, International Journal of Computer Theory and Engineering, Vol. 6, No. 2, April 2014
3. Importance of Aho-Corasick String Matching Algorithm in Real World Applications: Saima Hasib, Mahak Motwani, Amit Saxena, International Journal of Computer Science and Information Technologies, Vol. 4 (3) , 2013, 467-469
4. Compressing dictionaries with a DAWG: [Steve Hanov’s Blog](http://stevehanov.ca/blog/index.php?id=115)
