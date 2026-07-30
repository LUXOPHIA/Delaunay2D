# LUX.Delaunay.D2.Periodic
[English](../README.md) | [日本語](README.md)

Delphi 用の平坦トーラス $\mathbb{T}^2 = \mathbb{R}^2 / L\mathbb{Z}^2$ 上のドロネー三角形分割。ゴースト点の複製も被覆空間も使わず、常に最小表現 ―― 頂点 $n$ 個・面 $2n$ 枚の $\Delta$ 複体 ―― を保ち、$n = 1$ でも成立します。すべての述語は量子化された格子上の厳密整数述語であり、追加も削除も局所操作です。

## 1. 概要

`TPeriDelaunay2D` は、格子周期的な点集合のドロネー三角形分割を商空間の上で直接保持します。頂点はサイトと1対1 ―― コピーは存在しません ―― で、各面は角ごとの格子オフセットを持ち、それによって３つの角が「その面自身の、普遍被覆 $\mathbb{R}^2$ へのリフト」に配置されます。

| 性質 | 内容 |
|---|---|
| 領域 | 正方形トーラス `Size` × `Size`。すなわち $L = \texttt{Size}$ |
| 表現 | 最小表現。すべての $n \ge 1$ に対し頂点 $n$・辺 $3n$・面 $2n$ |
| 複体の種類 | $\Delta$ 複体（一つの面が同じ頂点を２または３つの角で参照し得る） |
| 演算 | 座標を2の冪グリッドへ量子化し、述語を 64/128 ビット整数で厳密に評価 |
| 退化 | サイト順位による記号摂動（Simulation of Simplicity） |
| 追加 | 普遍被覆上の Bowyer–Watson。疎な段階ではスターを直接構築 |
| 削除 | 局所的な星の除去 ＋ ドロネー耳による埋め戻し。$n \le 3$ のみ $O(1)$ 再構築 |
| 失敗 | `AddPoin` → `nil`、`DeletePoin` → `False`。何も変更しない |

設計上の帰結として、本モデルは被覆空間方式 [2] および商空間の二相方式 [3] と次の２点で異なります。

- 最小表現から離れません。「単体性が保証されたので表現を切り替える」という遷移はなく、周期的な巻き戻しのパスも存在しません。格子オフセットが面の生成時に必ず正規化されるからです（§2.3）。
- 削除はトーラス上の真に局所的な操作であり、再構築ではありません。一様乱数200サイトを1つずつ全削除した実測では、局所削除の経路が 200 回のうち 197 回選ばれ、残る 3 回は末尾の $n \le 3$ です。

## 2. 数学的背景

### 2.1 周期ドロネー三角形分割

$\Lambda = L\mathbb{Z}^2$ を格子、$\mathbb{T}^2 = \mathbb{R}^2/\Lambda$ を平坦トーラス、$S \subset [0,L)^2$ を $n$ 個のサイトの集合とします。ドロネー構成の入力は、$\Lambda$ 周期的な無限点集合

```math
\widetilde{S} = S + \Lambda = \{\, s + \lambda \;:\; s \in S,\ \lambda \in \Lambda \,\}
\qquad \text{(2.1)}
```

です。$\mathrm{Del}(\widetilde S)$ は $\mathbb{R}^2$ の局所有限かつ $\Lambda$ 不変な三角形分割であり、目的の対象はその商 $\mathrm{Del}(\widetilde S)/\Lambda$ ―― $\mathbb{T}^2$ の三角形分割 ―― です [2]。$\mathrm{Del}(\widetilde S)$ の単体とその $\Lambda$ 平行移動像はすべて、商のただ一つの同じ単体へ射影されます。

### 2.2 最小表現と $\Delta$ 複体

$\chi(\mathbb{T}^2) = 0$ なので商は $V - E + F = 0$ をみたします。各面は3辺を持ち各辺には2面が接するので $2E = 3F$、したがって

```math
V = n, \qquad E = 3n, \qquad F = 2n
\qquad \text{(2.2)}
```

が**すべての** $n \ge 1$ に対して成り立ちます。特に $n = 1$ でも、1頂点・2面の正しい三角形分割になります ―― 正方形 $[0,L)^2$ を正の向きの２枚に割ったもので、その角はすべて、異なる格子オフセットのもとで同じ頂点の実体を参照します（`SeedTwo`）。

商が単体的複体になるのは、どの単体も互いの平行移動像である２頂点を持たないときに限ります。これはサイトが $L$ に比して疎であればいつでも破れます。被覆空間方式 [2] は領域の $3 \times 3$（3Dでは $3^3$）コピーを三角形分割することでこの状況を回避し、二相方式 [3] は単体性が保証されてから商空間で直接挿入します。本モデルは代わりに $\Delta$ 複体を直接載せます。TriFlip の接続構造（`Poin` / `Face` / `Corn`）は角番号で巡回し、頂点の同一性を用いないため、一つの面が同じ頂点の実体を２または３つの角で参照しても特別な扱いは要りません。TriFlip 本体は無変更で使われ、格子オフセットとリフト幾何だけを派生クラスが加えます。

### 2.3 格子オフセットと正準化

頂点の座標は常に正準、$\mathrm{Pos} \in [0,L)^2$ です。各面は角ごとに格子オフセット $o_K \in \{0,1,2\}^2$ を持ち（`_Offs` に軸ごと2ビット）、その面自身のリフトにおける角 $K$ の幾何座標は

```math
\mathrm{CornPos}(K) = \mathrm{Poin}[K].\mathrm{Pos} + L \cdot o_K
\qquad \text{(2.3)}
```

です。したがって各面は普遍被覆への独自のリフトを持ちます。隣接する２面のリフトは格子ベクトルだけずれ得て、その差は `NeigShift` から得られます（これは角番号で解決され、頂点の同一性は決して使いません）。面の生成時に `NewFaceG` が軸ごとの最小値を引きます。

```math
o_K \;\longleftarrow\; o_K - \min_{J} o_J \quad \text{（成分ごと）}
\qquad \text{(2.4)}
```

これにより、すべての面のリフトが基本領域に接するよう正規化されます。保持されている実体が基本領域から限りなく乖離していくことが原理的に起こらないのはこのためであり、周期的な「巻き戻しパス」が一切不要なのもこのためです。

**オフセットが2ビットに収まること。** $\mathbb{T}^2$ 上の空円は、少なくとも1サイトの格子コピーを避けなければならないので、その半径は基本正方形の半分の外接円半径で抑えられます。

```math
r \le \frac{L}{\sqrt{2}}, \qquad \text{ゆえに} \qquad \mathrm{diam} \le \sqrt{2}\,L < 2L .
\qquad \text{(2.5)}
```

面は外接円に内接するので、軸方向の張り出しは $2L$ 未満です。したがって正規化 (2.4) の後のオフセットは $\{0,1,2\}$ に収まり、軸ごと2ビットで格納できます。

### 2.4 量子化と厳密整数述語

`Size` は2の冪グリッドへスナップされます。$q = 2^{E-17}$ を

```math
K = L/q \in [\,2^{16},\, 2^{17}\,]
\qquad \text{(2.6)}
```

となるように選ぶことで、$L$ もすべてのサイト座標も $q$ の整数倍になります。相対量子化誤差は高々 $1/K \le 2^{-16}$、絶対では $L \cdot 2^{-16}$ 程度 ―― 実用上不可視です。

これにより全幾何が整数格子に載り、述語は**厳密に**評価されます。オフセットが $\{0,1,2\}$、$K \le 2^{17}$ なので、リフト内の格子座標の差は $|\Delta| < 2^{21}$ をみたし、

```math
\mathrm{Orient}(Q,U,V) = (U_x - Q_x)(V_y - Q_y) - (U_y - Q_y)(V_x - Q_x),
\qquad |\mathrm{Orient}| < 2^{43}
\qquad \text{(2.7)}
```

は `Int64` に収まります。一方、空円行列式

```math
\mathrm{InCircle}(A,B,C;Q) =
\begin{vmatrix}
X_1 & Y_1 & X_1^2 + Y_1^2 \\
X_2 & Y_2 & X_2^2 + Y_2^2 \\
X_3 & Y_3 & X_3^2 + Y_3^2
\end{vmatrix},
\qquad (X_i, Y_i) = \cdot_i - Q
\qquad \text{(2.8)}
```

は次数4で約85ビットを要するため、128ビット整数（`TInt128` / `Acc128` / `Sign128`）で累算し、その符号を厳密に読み取ります。浮動小数の丸めによる述語の誤判定 ―― 退化配置での構造破壊の源 ―― は、したがって原理的に存在しません。

### 2.5 サイト順位による記号摂動

(2.8) が消える共円の退化は、Simulation of Simplicity [4] で裁きます。順位 $r$ のサイトはリフトを無限小 $\delta^{r}$ だけ持ち上げたものとみなされ、これは無限小重み付き（正則）ドロネー三角形分割と等価です。符号は、順位の順に見て最初に消えない余因子和の符号

```math
\mathrm{sign} \sum_{i \,:\, r_i = r} \frac{\partial \det}{\partial z_i}
\quad \text{（和が 0 でない最小の } r \text{ について）}
\qquad \text{(2.9)}
```

となります。余因子 $\partial\det/\partial z_i$ は残る3点の向きの行列式です（`InCirclePert`）。

摂動は**サイト**の関数なので、そのサイトのすべての格子像で共通、すなわち $\Lambda$ 同変です。これが商空間で使える理由です。同一頂点の平行移動対 $(w,\, w + L e)$ による*構造的*な共円も、これによって解消されます ―― 実体ごとの摂動では一貫した扱いが不可能な場合です。同順位の余因子を符号を取る前に足し合わせるのは、まさに1サイトの周期像が順位を共有するからです。それでも決まらない超退化 ―― 4点が共線、または疎な段階での厳密に対称な格子点配置 ―― だけが 0 を返し、拒否されます。

### 2.6 普遍被覆上の追加

追加サイト $p$ のリフト $\hat p$ をひとつ固定します。キャビティは普遍被覆の中で幅優先探索によって集められ、その要素は（面の実体 × 格子平行移動）の対です。*同じ*面の実体が異なる平行移動で2回入ることが正当に起こり得ます ―― その外接円が $p$ の複数の周期像を含む場合です。したがって訪問済み判定は面だけではなく (面, 平行移動) を鍵とします。

- **通常の場合。** $p$ が自分の周期像とドロネー隣接しないなら ―― これは厳密に判定されます ―― 普通の Bowyer–Watson の錐で正しく、キャビティ境界辺ごとに面 $(A, p, B)$ を1枚張ります。妥当性は「どの錐面の外接円も $p$ の周期像を含まない」ことを厳密に確かめて確認します。新しい面どうしの縫合は、平面版ライブラリと同じく `CanWeld` の走査で行いますが、普遍被覆では2つのリフトが同一の頂点実体を共有するため、`TPeriFace2D.CanWeld` は追加で**辺の格子変位が鏡像で一致すること**を要求します。
- **疎な場合。** そうでなければ $p$ は自分の像と隣接し、自己辺 $p$–$p$ を持つ面が必要になるため、錐は正しくありません。このとき **$\hat p$ のスターを候補点集合からギフトラッピングで直接構築**します ―― 候補は穴の境界頂点とその平行移動像、および $p$ の格子像です。扇をトーラスへ射影すると同じ面が2回現れ得るので、回転・平行移動正規化キーで面を同一視し、縫合の相手は幾何計算（辺の反対側の第3頂点）で一意に解決します。この経路が選ばれた回数はカウンタ `StarInsN` に記録されます。

どちらの場合も、計画が完全に検証されてから初めてメッシュに触れます。共円のタイを検出しても何も壊さず、`AddPoin` は `nil` を返します。

### 2.7 局所的な星の除去による削除

頂点のひとつのリフト $\hat v$ の周りの星を角の巡回で集め、穴の境界多角形をリフト座標で取り出し、**ドロネー耳** ―― 他のリンク頂点*とその平行移動像*を外接円に含まない耳 ―― で穴を埋めます。縫合は二段方式です。まずリフト内の厳密な座標一致で縫い、次に、外側も消える境界辺については、隣の穴の格子平行移動 $\mu$ を幾何的に特定して埋め草どうしを縫います。これは穴がトーラスを巻いて自分の平行移動像と接する場合です。

埋め草は、メッシュに触れる前に完全に計画・検証されます。退化による失敗時は**何も変更せず `False` を返します** ―― 平面版と同じ流儀です。$n \le 3$ だけがサイト列からの $O(1)$ 再構築で扱われ、これは平面版の少数点の特別扱いに相当します。２つの経路の回数はカウンタ `LocalDelN` と `RebuildDelN` に記録されます。

### 2.8 クエリ

点の位置検索は、累積格子平行移動と厳密述語を伴うジャンプ＆ウォークで、退化時には全面走査の保険が働きます。`FindNearPoin` は**トーラス距離**

```math
d_{\mathbb{T}}(a,b)^2 = \min_{\lambda \in \Lambda} \lVert a - b + \lambda \rVert^2
\qquad \text{(2.10)}
```

（`TorusDist2`）による最近傍サイトを返します。コンパクトな商空間には無限遠点が存在しないため、すべての面が有限の外接円を持ち、`FindMaxCircle` は全面を対象とします。

## 3. アーキテクチャ

### 3.1 クラス図

```
継承関係

・TTriPoin2D<TPeriFace2D>    ：(LUX)
  ┗・TPeriPoin2D
     ┗・Site

・TTriPoinSet2D<TPeriPoin2D>    ：(LUX)
  ┗・TPeriPoinSet2D

・TTriFace2D<TPeriPoin2D,TPeriFace2D>    ：(LUX)
  ┗・TPeriFace2D
     ┣・Off[1..3]    ：格子オフセット
     ┣・CornGrid / CornPos
     ┣・CircumD / CircumPos / CircumRadius
     ┗・NeigShift

・TTriFaceSet2D<TPeriFace2D,TPeriPoinSet2D>    ：(LUX)
  ┗・TPeriFaceSet2D
     ┗・TPeriDelaunay2D

・TFrame    ：(FMX)
  ┗・TPeriDelaunayViewer

・TCGLayer    ：(LUX.CG2D)
  ┣・TPeriDelaunayTrias
  ┣・TPeriDelaunayCircs
  ┣・TPeriDelaunayVolos
  ┣・TPeriDelaunayGrids
  ┗・TPeriDelaunayPoins

所有・参照関係

・TPeriDelaunay2D    ：( = TPeriFaceSet2D = 面集合 )
  ┣・Poins :TPeriPoinSet2D
  ┃  ┗・1..1 TPeriPoin2D    ：サイトと1対1
  ┃     ┣・Pos    ：正準・格子上
  ┃     ┗・Site    ：番号
  ┣・Faces :TPeriFaceSet2D    ：( = Self )
  ┃  ┗・2n TPeriFace2D
  ┃     ┣・Poin[1..3]    ：重複し得る
  ┃     ┣・Off [1..3]    ：∈ {0,1,2}²
  ┃     ┗・Face[1..3], Corn[1..3]
  ┣・Size :Single    ：L（グリッドへスナップ）
  ┣・Site[] :TSingle2D    ：サイトの正準座標
  ┣・SitePoin[] :TPeriPoin2D
  ┣・LocalDelN / RebuildDelN / StarInsN    ：統計
  ┗・OnChange :TDelegates    ：ビューアへ通知

・TPeriDelaunayViewer
  ┗・Layers :TCGLayers    ：生成順が描画順（下から上へ）
     ┣・Trias（コピー）    ：最下
     ┣・Trias（実体）
     ┣・Circs
     ┣・Grids
     ┣・Volos
     ┣・Poins（コピー）
     ┣・Poins（実体）    ：最上
     ┗・TCGCamera のレイヤ
```

### 3.2 ファイル構成

```
・D2/Periodic/
  ┣・LUX.Delaunay.D2.Periodic.pas    ：unit LUX.Delaunay.D2.Periodic
  ┃  ┣・TInt128 / Acc128 / Sign128    ：厳密空円判定のための128ビット累算
  ┃  ┣・OrientG / InCircleSign / InCirclePert    ：述語 ＋ サイト順位 SoS
  ┃  ┣・TPeriPoin2D    ：頂点。サイトと1対1（Site）
  ┃  ┣・TPeriPoinSet2D    ：点集合
  ┃  ┣・TPeriFace2D    ：三角形: 角ごとのオフセット・リフト幾何
  ┃  ┣・TPeriFaceSet2D    ：面集合
  ┃  ┗・TPeriDelaunay2D    ：モデル: AddPoin / DeletePoin / クエリ
  ┣・LUX.Delaunay.D2.Periodic.Viewer.pas / .fmx    ：ビューアのユニット
  ┃  ┣・TPeriDelaunayTrias / Circs / Volos / Grids / Poins    ：シーンレイヤ
  ┃  ┗・TPeriDelaunayViewer    ：TFrame 本体
  ┣・README.md    ：英語版
  ┗・ja/README.md    ：本ドキュメント
```

平面モデルと同じ [LUX](https://github.com/LUXOPHIA/LUX) の TriFlip メッシュ層（`LUX.Data.Model.TriFlip.core`・`LUX.Data.Model.TriFlip.D2`）の上に構築されています。これらの層が点と面を所有し、接続構造・角の巡回表（`VertTableInc` / `VertTableDec`）・列挙を担います。

### 3.3 クラス一覧 ― `LUX.Delaunay.D2.Periodic`

#### `TPeriPoin2D` ― 頂点

| メンバ | 説明 |
|---|---|
| `Pos :TSingle2D` | 正準座標。$\in [0,L)^2$ かつ格子上。*(継承)* |
| `Face :TPeriFace2D` / `Corn :Byte` | アンカー: この頂点を含む面の一つと、その中での角番号。*(継承)* |
| `Site :Integer` | サイト番号 ― `TPeriDelaunay2D.Site[]` の添字。 |

#### `TPeriFace2D` ― 三角形

| メンバ | 説明 |
|---|---|
| `Poin[1..3] :TPeriPoin2D` | 頂点（反時計回り）。同じ実体が２または３つの角に現れ得ます。*(継承)* |
| `Face[1..3] :TPeriFace2D` / `Corn[1..3] :Byte` | 角 `K` の対辺で接する隣接面と、その角番号。*(継承)* |
| `Model :TPeriDelaunay2D` | 属すモデル（`Parent` の別名）。 |
| `Off[ I ] :TPoint` | 角 `I` の格子オフセット。$\in \{0,1,2\}^2$ で、(2.4) により正規化済み。 |
| `CornGrid( I ) :TPoint` | この面自身のリフトにおける角 `I` の格子座標（$q$ 単位・厳密）。 |
| `CornPos( I ) :TSingle2D` | この面自身のリフトにおける角 `I` の幾何座標 (2.3)。格子上なので厳密。 |
| `CircumD( out Center_, out Radius2_ )` | この面のリフトにおける外心と半径の平方（倍精度）。 |
| `CircumPos :TSingle2D` / `CircumRadius :Single` | 同じものを単精度スカラーで。 |
| `NeigShift( I ) :TSingle2D` | `Face[I]` のリフトをこの面のリフトへ移す平行移動量。角番号で解決され、頂点の同一性は使いません。 |

#### `TPeriPoinSet2D` / `TPeriFaceSet2D` ― 集合

列挙可能なコンテナ（`for F in …`・`Count`・`[I]`）。`TPeriFaceSet2D.Poins` は頂点集合です。トーラス上ではすべての頂点が有限で、サイトと1対1です。

#### `TPeriDelaunay2D` ― ドロネー図

| メンバ | 説明 |
|---|---|
| `Create` / `Destroy` | 空の図。点集合を所有します。 |
| `Faces :TPeriFaceSet2D` | 全ての面 ― トーラスの面そのもので、常にちょうど $2n$ 枚（自分自身の別名）。 |
| `Size :Single` | 基本領域の一辺 $L$。代入すると $L$ を2の冪グリッド (2.6) へスナップし、サイトを巻き直して再構築します。 |
| `SitesN :Integer` | サイトの数。 |
| `Site[ I ] :TSingle2D` | サイト `I` の正準座標。$\in [0,L)^2$。 |
| `SitePoin[ I ] :TPeriPoin2D` | サイト `I` の頂点。 |
| `OnChange :TDelegates` | 構造が変化するたびに発火する多播通知。`Add` で購読、`Del` で解除。 |
| `LocalDelN` / `RebuildDelN` / `StarInsN` | 統計: 局所削除の回数、再構築へ退避した削除の回数、スターの直接構築を要した追加の回数。 |
| `WrapPos( Pos_ ) :TSingle2D` | 任意の座標を $[0,L)^2$ の正準な格子上の代表へ写します。 |
| `TorusDist2( A_, B_ ) :Single` | ２つの正準座標間のトーラス距離の平方 (2.10)。 |
| `HitCircleFace( Pos_ ) :TPeriFace2D` | `Pos_` を外接円に含む面 ― 累積平行移動つきジャンプ＆ウォーク。 |
| `FindMaxCircle :TPeriFace2D` | 最大の空円をもつ面。面が無ければ `nil`。半径無限大の面が存在しないため、全面が対象です。 |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | 最近傍サイトの頂点と、そのトーラス距離。 |
| `AddPoin( Pos_ ) :TPeriPoin2D` | サイトの追加（§2.6）。座標は領域内へ巻き込まれます。座標が数でない場合・重複・解消できない超退化では、何も変えずに `nil`。 |
| `DeletePoin( Poin_ ) :Boolean` | サイトの削除（§2.7）。退化配置では何も変えずに `False`。$n \le 3$ は $O(1)$ で再構築されます。 |
| `TorusFaces :TArray<TPeriFace2D>` | トーラスの全ての面を配列で（= `Faces` の内容）。ビューア用。 |
| `Clear` | 全てのサイトと面を消去します。 |
| `SaveToFile` / `LoadFromFile` | **非対応** ― TriFlip の形式が格子オフセットを保存できないため、例外を投げて封じてあります。 |

### 3.4 クラス一覧 ― `LUX.Delaunay.D2.Periodic.Viewer`

`TPeriDelaunay2D` を [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) のシーングラフ（Skia4Delphi）で描画する `TFrame`。平面版のビューアと同じ流儀で、自前の描画処理は持ちません。`OnChange` を購読し、シーンを次の描画の直前まで遅延して自動的に再構築します。

基本領域は原点中心 $[-L/2, +L/2)^2$ に置かれ、トーラスの面は固定の $3 \times 3$ タイルで貼り並べられます。実体面の配置は、アンカー（角1）を基本領域へ巻き戻すだけの単純規則です。面ごとの局所規準（外心・重心など）で中央代表を辺連結な塊に見せることは一般に不可能で ―― 連結な基本領域の選択は双対グラフ上の全域木選択と同型になるため ―― 行いません。`Camera.SizeX` / `SizeY` はアプリケーション側で設定します（$2L \times 2L$ で領域に余白をつけて表示。フレーム自身の既定は 400 × 400）。ウインドウのアスペクト比が極端な場合、$3 \times 3$ の外が見えることは許容します。

#### `TPeriDelaunayViewer` ― フレーム

| メンバ | 説明 |
|---|---|
| `Delaunay :TPeriDelaunay2D` | 表示する図。代入で `OnChange` を購読します。`nil` の代入で解除（図を解放する前におこなうこと）。 |
| `Layers :TCGLayers` | 構築されたシーン。 |
| `Camera :TCGCamera` | 視点。`SizeX` / `SizeY` がモデル座標での視野の広さ。 |
| `Poins` / `Trias` / `Circs` / `Volos` / `Grids` | シーンのレイヤ（下記）。スタイルはこの実体レイヤで設定します。 |
| `ScrToPos( S_ ) :TSingle2D` / `PosToScr( P_ ) :TPointF` | スクリーン座標とワールド座標の相互変換（領域の中心が原点）。 |
| `ScrToTorus( S_ ) :TSingle2D` | スクリーン座標 → トーラスの正準座標。$\in [0,L)^2$。 |

#### レイヤ

各レイヤは `Style`（`FillColor` / `LineColor` / `LineThick`）を持つ `TCGLayer` です。生成順が描画順（下から上へ）です。

| レイヤ | 表示内容 |
|---|---|
| `TPeriDelaunayTrias` | ドロネー三角形。実体（中央）用とコピー（周囲8枚）用の２つのインスタンス。 |
| `TPeriDelaunayCircs` | 空円 ― 中央の実体のぶんだけ。周囲8タイルのコピー円は描きません。 |
| `TPeriDelaunayGrids` | 周期境界の直線: $3 \times 3$ のマス、縦4本・横4本。 |
| `TPeriDelaunayVolos` | ボロノイ辺。 |
| `TPeriDelaunayPoins` | 頂点（`Radius` はモデル座標での半径）。実体（中央）用とコピー（周囲8個）用の２つのインスタンス。 |

スタイルは実体レイヤで設定します（`Viewer1.Poins.Style.FillColor` など）。コピーレイヤの淡色は、実体レイヤの現在のスタイルからアルファを半分にして導出し、再構築のたびに専用のコピーレイヤのスタイルへ写します。中間ノードによるスタイル継承は使いません ―― このシーングラフではスタイルが子へ伝播しないためです。

## 4. 使い方

### 4.1 構築とクエリ

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2.Periodic;

var
   D :TPeriDelaunay2D;
   V :TPeriPoin2D;
   F :TPeriFace2D;
   N :Integer;
begin
     D := TPeriDelaunay2D.Create;

     D.Size := 300;                                              // 基本領域 [0,300)²

     for N := 1 to 200 do                                        // 追加（領域内へ巻き込まれる）
     begin
          D.AddPoin( TSingle2D.Create( 300 * Random, 300 * Random ) );
     end;

     for F in D.Faces do                                         // 面は常にちょうど 2n 枚
     begin
          { F.CornPos( 1 ) … F.CornPos( 3 ) が、その面自身のリフト上の三角形。
            F.CircumPos と F.CircumRadius も同じリフト上。
            F.NeigShift( K ) は F.Face[K] のリフトを F のリフトへ移す }
     end;

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), V ) < 10       // 最近傍サイト（トーラス距離）
     then D.DeletePoin( V );                                     // 局所削除

     D.Free;
end;
```

`AddPoin` や `FindNearPoin` が返す頂点参照は、その頂点が削除された時点で無効になります ―― すぐに使ってください。

### 4.2 統計

```pascal
Caption := Format( 'サイト %d / 面 %d ― 局所 %d, 再構築 %d, スター %d',
                   [ D.SitesN, D.Faces.Count, D.LocalDelN, D.RebuildDelN, D.StarInsN ] );
```

### 4.3 ビューア

フォームに `TPeriDelaunayViewer` を置き（実行時に `Parent` を与えて生成しても可）、図を渡します。

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
     _Delaunay := TPeriDelaunay2D.Create;

     _Delaunay.Size := 300;

     with Viewer1 do
     begin
          Delaunay := _Delaunay;

          with Camera do begin  SizeX := 600;  SizeY := 600;  end;   // 2L × 2L

          Poins.Style.FillColor := TAlphaColors.Red;
          Trias.Style.FillColor := TAlphaColors.Cornflowerblue;
          Circs.Style.LineColor := TAlphaColors.Lime;
          Volos.Style.LineColor := TAlphaColors.Black;
          Grids.Style.LineColor := TAlphaColors.Pink;
     end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
     Viewer1.Delaunay := nil;  // モデルを解放する前に購読を解除する

     _Delaunay.Free;
end;
```

編集はすべてモデルに対しておこないます ―― ビューアは勝手に追従します。トーラス対応の座標変換を使った最小のマウス操作の例:

```pascal
procedure TForm1.Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   P :TSingle2D;
   V :TPeriPoin2D;
begin
     P := Viewer1.ScrToTorus( TPointF.Create( X, Y ) );   // → 正準座標

     if _Delaunay.FindNearPoin( P, V ) < 6
     then _Delaunay.DeletePoin( V )   // 近くに既存のサイト → 削除
     else _Delaunay.AddPoin   ( P );  // 空白　　　　　　　 → 追加
end;
```

## 5. 制限

- 領域は**正方形**トーラス（`Size` × `Size`）です。一般の格子には対応しません。
- 厳密に共円な配置 ―― グリッド上の対称配置など ―― は、点集合が疎な段階、すなわちスターの直接構築（§2.6）が必要な局面に限り、追加が拒否されることがあります。錐の経路で済むほど密になれば拒否は起きません。
- TriFlip コンテナの `SaveToFile` / `LoadFromFile` は、形式が格子オフセットを保存できないため封じてあります。
- `AddPoin` / `FindNearPoin` が返す頂点参照は、その頂点の削除で無効になります。

## 6. 参考文献

1. Bowyer, A., [*Computing Dirichlet tessellations*](https://doi.org/10.1093/comjnl/24.2.162), The Computer Journal, 24(2), 162–166, 1981.
2. Caroli, M., Teillaud, M., [*Computing 3D periodic triangulations*](https://doi.org/10.1007/978-3-642-04128-0_6), ESA 2009, LNCS 5757, 59–70, 2009.
3. Osang, G., Rouxel-Labbé, M., Teillaud, M., [*Generalizing CGAL periodic Delaunay triangulations*](https://doi.org/10.4230/LIPIcs.ESA.2020.75), ESA 2020, LIPIcs 173, 75:1–75:17, 2020.
4. Edelsbrunner, H., Mücke, E. P., [*Simulation of simplicity: a technique to cope with degenerate cases in geometric algorithms*](https://doi.org/10.1145/77635.77639), ACM Transactions on Graphics, 9(1), 66–104, 1990.
5. Shewchuk, J. R., [*Adaptive precision floating-point arithmetic and fast robust geometric predicates*](https://doi.org/10.1007/PL00009321), Discrete & Computational Geometry, 18(3), 305–363, 1997.
6. Devillers, O., [*On deletion in Delaunay triangulations*](https://doi.org/10.1142/S0218195902000815), International Journal of Computational Geometry & Applications, 12(3), 193–205, 2002.
7. Mücke, E. P., Saias, I., Zhu, B., [*Fast randomized point location without preprocessing in two- and three-dimensional Delaunay triangulations*](https://doi.org/10.1016/S0925-7721(98)00035-2), Computational Geometry, 12(1–2), 63–83, 1999.
8. Caroli, M., Teillaud, M., [*Delaunay triangulations of closed Euclidean d-orbifolds*](https://doi.org/10.1007/s00454-016-9782-6), Discrete & Computational Geometry, 2016.
9. Delaunay, B., [*Sur la sphère vide*](https://www.mathnet.ru/eng/im4937), Bulletin de l'Académie des Sciences de l'URSS, 6, 793–800, 1934.

## 💖 [Embarcadero](https://www.embarcadero.com/jp/) [**Delphi**](https://www.embarcadero.com/jp/products/delphi)
ネイティブなクロスプラットフォームアプリを開発するための統合開発環境（ＩＤＥ）。
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/jp/products/delphi/starter)
