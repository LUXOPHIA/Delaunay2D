# LUX.Delaunay.D2
[English](../README.md) | [日本語](README.md)

Delphi 用のユークリッド平面ドロネー三角形分割。サイトの追加は Bowyer–Watson のキャビティ構成で、削除は星の除去と穴の決定論的な埋め戻しでおこないます。凸包の外側は、ただ一つの無限遠頂点に接する面で覆われます。Skia ベースの FireMonkey ビューアフレームを同梱します。

## 1. 概要

`TDelaunay2D` は $\mathbb{E}^2$ の三角形分割を、辺で貼り合わされた三角形（*面*）の集合として保持します。凸包の外側が無限遠頂点を含む面で覆われるため、**どの辺にもちょうど２つの面が接し**、すべてのアルゴリズムが境界の場合分けなしに動きます。面の中の頂点番号は `1..3`（反時計回り）です。

| 性質 | 内容 |
|---|---|
| 追加 | Bowyer–Watson。マークとカーブの２相方式。再帰もプレースホルダも不要 |
| 削除 | 星の除去 ＋ リンクの局所ドロネー図からの埋め戻し |
| 凸包の扱い | ただ一つの無限遠頂点（スーパートライアングルもバウンディングボックスも不要） |
| 述語 | ただ一つの $3 \times 3$ リフト行列式。基準点へ平行移動して倍精度で評価 |
| 外心 | 同次座標 `( X, Y, W )`。無限遠では `W = 0` へ退化 |
| 位置検索 | ジャンプ＆ウォーク、期待 $O(n^{1/3})$ |
| 保存 | `*.lxtf`。座標と接続構造の全体 |
| 失敗 | `AddPoin` → `nil`、`DeletePoin` → `False`。何も変更しない |

## 2. 数学的背景

### 2.1 ドロネー三角形分割と空円性

有限集合 $P \subset \mathbb{R}^2$ に対し、三角形 $\{p_1,p_2,p_3\} \subset P$ が $\mathrm{Del}(P)$ に属するのは、その外接開円板が $P$ を含まないとき、かつそのときに限ります [3]。

```math
\{p_1,p_2,p_3\} \in \mathrm{Del}(P)
\iff
\mathrm{int}\, B(p_1,p_2,p_3) \cap P = \varnothing .
\qquad \text{(2.1)}
```

$\mathrm{Del}(P)$ はボロノイ図 $\mathrm{Vor}(P)$ の直線双対です。三角形の外心はボロノイ頂点であり、ドロネー辺の双対は、その辺に接する２つの三角形の外心を結ぶボロノイ辺です [10]。

### 2.2 リフト写像と統一空円述語

$\ell(p) = (p, \lVert p \rVert^2)$ を放物面 $z = x^2 + y^2$ へのリフトとします。平面の円はこの放物面と平面の交わりの鉛直射影であり、$q$ が円の内側にあるのは $\ell(q)$ が平面の真下にあるとき、かつそのときに限ります。したがって $\mathrm{Del}(P)$ は $\ell(P)$ の下側凸包の射影です [4]。述語は、すべてのオペランドを判定点 $q$ へ平行移動してから評価されます。

```math
\mathrm{Lift}(p;q) =
\bigl(\, p_x - q_x,\; p_y - q_y,\; (p_x-q_x)^2 + (p_y-q_y)^2 \,\bigr),
\qquad \text{(2.2)}
```

```math
\mathrm{InCircle}(p_1,p_2,p_3;\,q) \;=\;
\det\begin{pmatrix}
\mathrm{Lift}(p_1;q) \\ \mathrm{Lift}(p_2;q) \\ \mathrm{Lift}(p_3;q)
\end{pmatrix}
\;=\;
\begin{vmatrix}
x_1-q_x & y_1-q_y & (x_1-q_x)^2+(y_1-q_y)^2 \\
x_2-q_x & y_2-q_y & (x_2-q_x)^2+(y_2-q_y)^2 \\
x_3-q_x & y_3-q_y & (x_3-q_x)^2+(y_3-q_y)^2
\end{vmatrix} .
\qquad \text{(2.3)}
```

反時計回りの三角形では、$\mathrm{InCircle} > 0$ が「$q$ は外接円の内側」を意味します。これが `TDelaFace2D.InCircle` です。インスタンス版 `TDelaPoin2D.InCircled` は役割を入れ替えた同じ行列式（判定される点がレシーバ）です。近傍の基準点へ平行移動してから倍精度で累算することが、座標が大きくても符号が信頼できる理由です [5]。本ユニットに、絶対座標のまま評価される式は存在しません。

### 2.3 無限遠頂点

たった一つ追加される頂点 $\infty$ が図を閉じます。凸包の各辺 $(p_i,p_j)$ は*無限遠面* $(\infty, p_i, p_j)$ を伴い、`Poin[]` に `nil` は現れません。組合せ的には $\infty$ の追加は一点コンパクト化 $\mathbb{R}^2 \cup \{\infty\} \cong S^2$ なので、$n \ge 3$ サイトの図は $n+1$ 頂点をもつ球面の三角形分割です。$2E = 3F$ のもとでオイラーの公式 $V - E + F = 2$ から

```math
V = n + 1, \qquad E = 3n - 3, \qquad F = 2n - 2
\qquad \text{(2.4)}
```

が従います（$F$ は無限遠面を含む）。図は最初の２サイトから、平面全体を二重に覆う鏡像の無限遠面の対 $(\infty, p_1, p_2)$ と $(\infty, p_2, p_1)$ で種付けされます（`SeedFace` / `InitFace`）。３サイト目以降は通常の追加処理がそのまま働きます。

`TDelaPoin2DInf` はリフトを定数

```math
\mathrm{Lift}(\infty;q) = (0, 0, 1)
\qquad \text{(2.5)}
```

で差し替えます。これは放物面の軸方向に沿った $\ell$ の極限方向です。(2.5) を (2.3) へ代入してその行に沿って展開すると、行列式は $2 \times 2$ の向きの行列式へ退化します。すなわち

```math
\mathrm{InCircle}(p_1, p_2, \infty;\, q)
= (x_1 - q_x)(y_2 - q_y) - (y_1 - q_y)(x_2 - q_x)
= \mathrm{orient}(q, p_1, p_2) .
\qquad \text{(2.6)}
```

$\infty$ を通る円は直線 ―― 半径無限大の円 ―― であり、空円判定は自動的に半平面判定へ退化します。§2.6 の歩行が同じ述語で駆動できるのはこのためであり、述語に無限遠フラグの検査が存在しないのもこのためです。

### 2.4 同次外心とボロノイ図

面の有限頂点 $B$ を基準として $L_i = \mathrm{Lift}(p_i;B)$ とし、$p_i$ の同次成分を $w_i \in \{1, 0\}$（$\infty$ では 0）とします。リフトの同次座標を $(X, Y, Z, W)$ と書くと、３つのリフト点を通る平面は

```math
\begin{vmatrix}
X & Y & Z & W \\
L_{1x} & L_{1y} & L_{1z} & w_1 \\
L_{2x} & L_{2y} & L_{2z} & w_2 \\
L_{3x} & L_{3y} & L_{3z} & w_3
\end{vmatrix} = 0
\;\;\Longleftrightarrow\;\;
a X + b Y + c Z + e W = 0
\qquad \text{(2.7)}
```

であり、$a, b, c, e$ は $3 \times 3$ の符号付き小行列式です。(2.7) と $Z = X^2 + Y^2$ の交わりは中心 $\bigl(-a/(2c),\, -b/(2c)\bigr)$ の円なので、`Circum` は

```math
\mathrm{Circum} = (\,-a,\; -b,\; 2c\,)
\qquad \text{(2.8)}
```

を返します（基準点ぶんは最後に同次のまま戻されます）。有限面では外心が $(X/W, Y/W)$、無限遠面では平面 (2.7) が鉛直になって $W = 2c = 0$ となり、$(X, Y)$ が凸包辺に双対な非有界ボロノイ辺の外向きの方向になります。計算に分岐も除算もなく、中心＋半径という表現を呼び出し側に押し付けることもありません。

> **フィールド名の注意。** `Circum` の型は `TSingle3D` で、その成分は `X`・`Y`・`Z` です。`W` フィールドは存在せず、**`Z` 成分が (2.8) の同次成分 $W$ を担います**。コードでは `Circum.W` ではなく `Circum.Z` を読む必要があります。

### 2.5 追加と削除

**追加**（公開 API は `AddPoin`、実処理は非公開の `InsertPoin`）は Bowyer–Watson 法 [1][2] です。新しいサイト $p$ のキャビティ

```math
\mathcal{C}(p) = \{\, \sigma \in \mathrm{Del}(P) \;:\; p \in \mathrm{int}\, B_\sigma \,\}
\qquad \text{(2.9)}
```

は $p$ に関して星型であり、

```math
\mathrm{Del}(P \cup \{p\}) = \bigl(\mathrm{Del}(P) \setminus \mathcal{C}(p)\bigr) \;\cup\; \{\, p * f \;:\; f \in \partial\mathcal{C}(p) \,\}
\qquad \text{(2.10)}
```

が成り立ちます。実装は２相です。①**マーク**: 着地した面から Flag の塗り広げで $\mathcal{C}(p)$ を集めます。塗りは冪等なので、共円の退化で同じ面へ複数の経路から到達しても二重処理は起こりません。②**カーブ**: 境界辺ごとに新しい面を張り、外側および $p$ の周りの隣どうしと縫い、最後に塗った面をまとめて解放します。解放は縫合の後なので、削除済みの面への再突入は構造的に起こりません。

**削除**（公開 API は `DeletePoin`、実処理は非公開の `RemovePoin`）は $v$ の星を取り除きます。すると境界が $\mathrm{link}(v)$ である星型の穴が開き、

```math
\mathrm{Del}(P \setminus \{v\}) \;=\; \bigl(\mathrm{Del}(P) \setminus \mathrm{star}(v)\bigr) \;\cup\; \mathcal{F},
\qquad
\mathcal{F} \subset \mathrm{Del}\bigl(\mathrm{link}(v)\bigr)
\qquad \text{(2.11)}
```

によって埋め戻されます ―― 穴の再分割がリンク頂点だけを使うという古典的な事実です [8]。そこでリンクの小さなドロネー図を、*同じ面集合の中の独立した成分*として逐次添加法で作り（入れ子の `TDelaunay2D` は作りません）、穴を埋める面をそこから切り出して縁に縫い付けます。切り出しは、穴の境界辺に鏡像の向きで貼り合う面からの位相的な塗り広げでおこない、「削除点を外接円に含む面」という述語は**用いません**。一般の配置では両者は一致しますが、共円の退化では削除点がちょうど外接円上に乗る面が穴の中に現れ、述語が破れるためです。どの工程にもフリップの探索は含まれません。退化配置で組合せ的な検査に通らなければ、元の図を一切変えずに `False` を返します。

### 2.6 クエリ

`HitCircleFace` は、判定点を外接円に含む面を*ジャンプ＆ウォーク* [6] で探します。$n^{1/3}$ 個のサイトを無作為に引き、最も近いもののアンカー面から出発し、判定点が外側にある辺を越え続けます。辺の判定は統一述語の退化形 (2.6) なので、凸包の外の点では歩行が自然に無限遠面へ入って止まります。期待計算量は $O(n^{1/3})$。標本は呼び出しごとに引き直されるため、性能は領域全体で一様で、クエリの履歴に依りません。

`FindNearPoin` は着地した面 ―― その頂点は必ず判定点の近くにあります ―― から始め、ドロネー辺を伝ってより近い隣接頂点へ貪欲に降下します。各段で距離が厳密に縮むため、降下は判定点をボロノイ領域に含むサイトで停止します。期待 $O(n^{1/3})$ ＋ $O(1)$ 段の降下です。

`FindMaxCircle` は最大の空円をもつ有限面を返します。空円の半径が無限大となる無限遠面は除かれます。

## 3. アーキテクチャ

### 3.1 クラス図

```
継承関係

・TTriPoin2D<TDelaFace2D>    ：(LUX)
  ┗・TDelaPoin2D
     ┗・TDelaPoin2DInf

・TTriPoinSet2D<TDelaPoin2D>    ：(LUX)
  ┗・TDelaPoinSet2D

・TTriFace2D<TDelaPoin2D,TDelaFace2D>    ：(LUX)
  ┗・TDelaFace2D

・TTriFaceSet2D<TDelaFace2D,TDelaPoinSet2D>    ：(LUX)
  ┗・TDelaFaceSet2D
     ┗・TDelaunay2D

・TFrame    ：(FMX)
  ┗・TDelaunayViewer

・TCGLayer    ：(LUX.CG2D)
  ┣・TDelaunayTrias
  ┣・TDelaunayCircs
  ┣・TDelaunayVolos
  ┗・TDelaunayPoins

所有・参照関係

・TDelaunay2D    ：( = TDelaFaceSet2D = 面集合そのもの )
  ┣・Poins :TDelaPoinSet2D
  ┃  ┗・1..* TDelaPoin2D
  ┃     ┣・Pos
  ┃     ┗・Face, Corn    ：アンカー
  ┣・Faces :TDelaFaceSet2D    ：( = Self )
  ┃  ┗・1..* TDelaFace2D
  ┃     ┣・Poin[1..3]    ：反時計回り。無限遠面はここに PoinInf を持つ
  ┃     ┣・Face[1..3]    ：隣接面
  ┃     ┗・Corn[1..3]
  ┣・PoinInf :TDelaPoin2DInf    ：全ての無限遠面が共有
  ┗・OnChange :TDelegates    ：ビューアへ通知

・TDelaunayViewer
  ┗・Layers :TCGLayers    ：生成順が描画順（下から上へ）
     ┣・TDelaunayTrias    ：最下
     ┣・TDelaunayCircs
     ┣・TDelaunayVolos
     ┣・TDelaunayPoins    ：最上
     ┗・TCGCamera のレイヤ
```

### 3.2 ファイル構成

```
・D2/
  ┣・LUX.Delaunay.D2.pas    ：unit LUX.Delaunay.D2
  ┃  ┣・TDelaPoin2D    ：頂点: Inf, Lift, InCircled
  ┃  ┣・TDelaPoin2DInf    ：無限遠頂点: Lift ≡ ( 0, 0, 1 )
  ┃  ┣・TDelaPoinSet2D    ：点集合（有限頂点のみ）
  ┃  ┣・TDelaFace2D    ：三角形: InfCorn, Circum, InCircle, IsHitCircle
  ┃  ┣・TDelaFaceSet2D    ：面集合
  ┃  ┗・TDelaunay2D    ：モデル: AddPoin / DeletePoin / クエリ / 入出力
  ┣・LUX.Delaunay.D2.Viewer.pas / .fmx    ：unit LUX.Delaunay.D2.Viewer
  ┃  ┣・TDelaunayTrias / Circs / Volos / Poins    ：LUX.CG2D のシーンレイヤ
  ┃  ┗・TDelaunayViewer    ：TFrame 本体
  ┣・README.md    ：英語版
  ┣・ja/README.md    ：本ドキュメント
  ┗・Periodic/    ：LUX.Delaunay.D2.Periodic ― 平坦トーラス版
```

[LUX](https://github.com/LUXOPHIA/LUX) の TriFlip メッシュ層（`LUX.Data.Model.TriFlip.core`・`LUX.Data.Model.TriFlip.D2`）の上に構築されています。これらの層が点と面を所有し、接続構造・角の巡回表（`VertTableInc` / `VertTableDec`）・辺の縫合・隣接検査（`CheckEdges`）・列挙を担います。`LUX.Delaunay.D2` はドロネー固有の機能だけを加え、TriFlip の型付け層には自分の派生クラスを型引数として与えます。

### 3.3 クラス一覧 ― `LUX.Delaunay.D2`

#### `TDelaPoin2D` ― 頂点

| メンバ | 説明 |
|---|---|
| `Pos :TSingle2D` | 座標。*(継承)* |
| `Face :TDelaFace2D` / `Corn :Byte` | アンカー: この頂点を含む面の一つと、その中での角番号。*(継承)* |
| `Inf :Boolean` | 無限遠頂点かどうか。 |
| `Lift( Pos_ ) :TDouble3D` | 基準点 `Pos_` から見たリフト (2.2)。 |
| `InCircled( P1_,P2_,P3_ ) :Double` | 円 `( P1, P2, P3 )` に対する自分の内外の符号 ― 正 = 内側。 |

#### `TDelaPoin2DInf` ― 無限遠頂点

`TDelaPoin2D` の派生。`Lift`（定数 `( 0, 0, 1 )`・式 2.5）と `InCircled`（円の向きへの退化）を多態で差し替えます。図につき唯一のインスタンス `TDelaunay2D.PoinInf` で、点集合には属さず `Poins` にも現れません。

#### `TDelaFace2D` ― 三角形

| メンバ | 説明 |
|---|---|
| `Poin[1..3] :TDelaPoin2D` | 頂点（反時計回り）。*(継承)* |
| `Face[1..3] :TDelaFace2D` | 頂点 `K` の対辺で接する隣接面。*(継承)* |
| `Corn[1..3] :Byte` | 隣接面から見た、共有辺の対頂点の番号。*(継承)* |
| `InfCorn :Byte` | 無限遠頂点の角番号 ― `0` は有限面。 |
| `Circum :TSingle3D` | 同次外心 (2.8)。**`Z` が同次成分 $W$**。有限面 → 外心 `( X/Z, Y/Z )`、無限遠面 → `Z = 0` で `( X, Y )` が双対ボロノイ辺の外向きの方向。 |
| `InCircle( P1_,P2_,P3_, Pos_ ) :Double` *(class)* | 統一リフト行列式 (2.3) ― 正 = `Pos_` が円 `( P1, P2, P3 )` の内側。 |
| `IsHitCircle( Pos_ ) :Boolean` | `Pos_` がこの面の外接円の内側にあるか。 |

#### `TDelaPoinSet2D` / `TDelaFaceSet2D` ― 集合

列挙可能なコンテナ（`for P in …`・`Count`・`[I]`）。`TDelaFaceSet2D.Poins` は**有限の**頂点だけを見せます。

#### `TDelaunay2D` ― ドロネー図

| メンバ | 説明 |
|---|---|
| `Create` / `Destroy` | 空の図。点集合と無限遠頂点を所有します。 |
| `PoinInf :TDelaPoin2D` | 唯一の無限遠頂点。 |
| `Faces :TDelaFaceSet2D` | 無限遠面を含む全ての面（自分自身の別名）。 |
| `Poins :TDelaPoinSet2D` | 全ての有限頂点。 |
| `OnChange :TDelegates` | 構造が変化するたびに発火する多播通知。`Add` で購読、`Del` で解除。 |
| `HitCircleFace( Pos_ ) :TDelaFace2D` | `Pos_` を外接円に含む面 ― ジャンプ＆ウォーク、期待 $O(n^{1/3})$。 |
| `FindMaxCircle :TDelaFace2D` | 最大の空円をもつ有限面。無ければ `nil`。 |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | 最近傍頂点と、そこまでの距離（位置検索＋貪欲降下）。図が空なら `Poin_ = nil` と `Infinity`。 |
| `AddPoin( Pos_ ) :TDelaPoin2D` | サイトの追加（§2.5）。追加できない場合（座標が数でない・重複・既存の辺の延長上などの退化配置）は `nil`。 |
| `AddPoin( Pos_, Face_ ) :TDelaPoin2D` | 所属面が既知の追加。検索を省き、検証もおこないません。`Face_` は `Pos_` を外接円に含む面でなければなりません。 |
| `DeletePoin( Poin_ ) :Boolean` | 頂点の削除（§2.5）。不正な入力や埋め戻せない退化配置では、何も変えずに `False`。 |
| `Clear` | 全ての点と面を消去します（`PoinInf` は残ります）。 |
| `SaveToFile( FileName_ )` | 図を `*.lxtf` ファイルへ保存します。座標と接続構造の全体を含むため、構造がそのまま往復します。 |
| `LoadFromFile( FileName_ )` | `*.lxtf` ファイルから図を復元します。現在の内容は全て置き換わり、無限遠頂点も接続ごと再現され、`OnChange` が一度発火します。 |

#### ファイル形式 `*.lxtf`

Radiance HDR 形式と同じ構成です。冒頭は UTF-8 テキストで、1行目が固有のヘッダ `LUXOPHIA TriFlip 1.0`、以降は `名前=値` のオプション行（`PoinsN` / `FacesN` / `PosSize`。未知の行は読み飛ばされます）。1行の空行でヘッダが終わり、それ以降はバイナリです ―― 点の座標列、続いて面ごとに頂点番号 ×3・隣接面番号 ×3（`Int32`。`-1` = nil、`-2` = 無限遠頂点）と、角・旗のパックバイト。

### 3.4 クラス一覧 ― `LUX.Delaunay.D2.Viewer`

`TDelaunay2D` を [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) のシーングラフ（Skia4Delphi）で描画する `TFrame`。`OnChange` を購読し、シーンを自動的に再構築します。再構築は次の描画の直前まで遅延され、1フレームに1回だけおこなわれます。自前の描画処理は持ちません。

#### `TDelaunayViewer` ― フレーム

| メンバ | 説明 |
|---|---|
| `Delaunay :TDelaunay2D` | 表示する図。代入で `OnChange` を購読します。`nil` の代入で解除（図を解放する前におこなうこと）。 |
| `Layers :TCGLayers` | 構築されたシーン。 |
| `Camera :TCGCamera` | 視点。`SizeX` / `SizeY` がモデル座標での視野の広さ（既定は 400 × 400）。 |
| `Poins` / `Trias` / `Circs` / `Volos` | シーンのレイヤ（下記）。 |
| `ScrToPos( S_ ) :TSingle2D` / `PosToScr( P_ ) :TPointF` | スクリーン座標とモデル座標の相互変換。 |

#### レイヤ

各レイヤは `Style`（`FillColor` / `LineColor` / `LineThick`）を持つ `TCGLayer` です。スタイルの変更は自動的に再描画されます。生成順が描画順（下から上へ）です。

| レイヤ | 表示内容 |
|---|---|
| `TDelaunayTrias` | ドロネー三角形。 |
| `TDelaunayCircs` | 有限面の外接円。 |
| `TDelaunayVolos` | ボロノイ図。非有界の辺は外向きの半直線として描かれます。 |
| `TDelaunayPoins` | 頂点（`Radius` はモデル座標での半径）。 |

## 4. 使い方

### 4.1 構築とクエリ

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2;

var
   D :TDelaunay2D;
   P :TDelaPoin2D;
   F :TDelaFace2D;
   N :Integer;
begin
     D := TDelaunay2D.Create;

     for N := 1 to 100 do D.AddPoin( 100 * TSingle2D.RandG );   // 追加

     for F in D.Faces do                                        // 三角形を列挙
     begin
          if F.InfCorn = 0 then { F.Poin[1..3] が有限の三角形 };
     end;

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), P ) < 10      // 最近傍頂点と、そこまでの距離
     then D.DeletePoin( P );                                    // 削除

     D.Free;
end;
```

### 4.2 ボロノイ図の取り出し

ボロノイ頂点は有限面の外心です。各ボロノイ辺はドロネー辺の双対で、辺に接する２面の外心を結びます。式 (2.8) は有界・非有界の辺を同じ式で扱います ―― 同次成分は `TSingle3D` の `Z` 成分であることに注意してください。

```pascal
var
   F      :TDelaFace2D;
   K      :Byte;
   C0, C1 :TSingle3D;
   P0, P1 :TSingle2D;
begin
     for F in D.Faces do
     begin
          if F.InfCorn > 0 then Continue;                  // ボロノイ頂点は有限面の上にある

          C0 := F.Circum;  P0 := TSingle2D.Create( C0.X, C0.Y ) / C0.Z;

          for K := 1 to 3 do
          begin
               C1 := F.Face[ K ].Circum;

               if C1.Z > 0
               then P1 := TSingle2D.Create( C1.X, C1.Y ) / C1.Z                    // 隣の外心までの線分
               else P1 := P0 + RayLength * TSingle2D.Create( C1.X, C1.Y ).Unitor;  // 凸包辺の外向きの半直線

               // P0 – P1 を描く（内部の辺は両側から訪れるので、中点まで描くか
               //                 F < F.Face[K] の側だけ描いて重複を避ける）
          end;
     end;
end;
```

### 4.3 ビューア

フォームに `TDelaunayViewer` を置き（実行時に `Parent` を与えて生成しても可）、図を渡します。

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
     _Delaunay := TDelaunay2D.Create;

     with Viewer1 do
     begin
          Delaunay := _Delaunay;

          with Camera do begin  SizeX := 600;  SizeY := 600;  end;   // 視野の広さ

          Poins.Style.FillColor := TAlphaColors.Red;
          Trias.Style.FillColor := TAlphaColors.Cornflowerblue;
          Circs.Style.LineColor := TAlphaColors.Lime;
          Volos.Style.LineColor := TAlphaColors.Black;
     end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
     Viewer1.Delaunay := nil;  // モデルを解放する前に購読を解除する

     _Delaunay.Free;
end;
```

編集はすべてモデルに対しておこないます ―― ビューアは勝手に追従します。最小のマウス操作の例:

```pascal
procedure TForm1.Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   P :TSingle2D;
   V :TDelaPoin2D;
begin
     P := Viewer1.ScrToPos( TPointF.Create( X, Y ) );

     if _Delaunay.FindNearPoin( P, V ) < 6
     then _Delaunay.DeletePoin( V )   // 近くに既存の頂点 → 削除
     else _Delaunay.AddPoin   ( P );  // 空白　　　　　　 → 追加
end;
```

完全な対話的アプリケーションは [Delaunay2D](https://github.com/LUXOPHIA/Delaunay2D) にあります。

## 5. 参考文献

1. Bowyer, A., [*Computing Dirichlet tessellations*](https://doi.org/10.1093/comjnl/24.2.162), The Computer Journal, 24(2), 162–166, 1981.
2. Watson, D. F., [*Computing the n-dimensional Delaunay tessellation with application to Voronoi polytopes*](https://doi.org/10.1093/comjnl/24.2.167), The Computer Journal, 24(2), 167–172, 1981.
3. Delaunay, B., [*Sur la sphère vide*](https://www.mathnet.ru/eng/im4937), Bulletin de l'Académie des Sciences de l'URSS, 6, 793–800, 1934.
4. Brown, K. Q., [*Voronoi diagrams from convex hulls*](https://doi.org/10.1016/0020-0190(79)90074-7), Information Processing Letters, 9(5), 223–228, 1979.
5. Shewchuk, J. R., [*Adaptive precision floating-point arithmetic and fast robust geometric predicates*](https://doi.org/10.1007/PL00009321), Discrete & Computational Geometry, 18(3), 305–363, 1997.
6. Mücke, E. P., Saias, I., Zhu, B., [*Fast randomized point location without preprocessing in two- and three-dimensional Delaunay triangulations*](https://doi.org/10.1016/S0925-7721(98)00035-2), Computational Geometry, 12(1–2), 63–83, 1999.
7. Edelsbrunner, H., Mücke, E. P., [*Simulation of simplicity: a technique to cope with degenerate cases in geometric algorithms*](https://doi.org/10.1145/77635.77639), ACM Transactions on Graphics, 9(1), 66–104, 1990.
8. Devillers, O., [*On deletion in Delaunay triangulations*](https://doi.org/10.1142/S0218195902000815), International Journal of Computational Geometry & Applications, 12(3), 193–205, 2002.
9. Aurenhammer, F., [*Voronoi diagrams — a survey of a fundamental geometric data structure*](https://doi.org/10.1145/116873.116880), ACM Computing Surveys, 23(3), 345–405, 1991.
10. Edelsbrunner, H., Seidel, R., [*Voronoi diagrams and arrangements*](https://doi.org/10.1007/BF02187681), Discrete & Computational Geometry, 1(1), 25–44, 1986.

## 💖 [Embarcadero](https://www.embarcadero.com/jp/) [**Delphi**](https://www.embarcadero.com/jp/products/delphi)
ネイティブなクロスプラットフォームアプリを開発するための統合開発環境（ＩＤＥ）。
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/jp/products/delphi/starter)
