# LUX.Delaunay.D3
[English](../README.md) | [日本語](README.md)

Delphi 用のユークリッド３次元空間ドロネー四面体分割。サイトの追加は Bowyer–Watson のキャビティ構成で、削除は星の除去と穴の決定論的な埋め戻しでおこないます。凸包の外側は、ただ一つの無限遠頂点に接する胞で覆われます。FMX の 3D ビューアフレームが、ドロネー辺とボロノイ辺をポリゴンの立体として描画します。

## 1. 概要

`TDelaunay3D` は $\mathbb{E}^3$ の四面体分割を、面で貼り合わされた四面体（*胞*）の集合として保持します。凸包の外側が無限遠頂点を含む胞で覆われるため、**どの面にもちょうど２つの胞が接し**、すべてのアルゴリズムが境界の場合分けなしに動きます。胞の中の頂点番号は `0..3` で、すべての胞は正の向きに保たれます。

| 性質 | 内容 |
|---|---|
| 追加 | Bowyer–Watson。マークとカーブの２相方式。再帰もプレースホルダも不要 |
| 削除 | 星の除去 ＋ リンクの局所ドロネー図からの埋め戻し |
| 凸包の扱い | ただ一つの無限遠頂点（スーパーテトラもバウンディングボックスも不要） |
| 述語 | ただ一つの $4 \times 4$ リフト行列式。基準点へ平行移動して倍精度で評価 |
| 外心 | 同次座標 `( X, Y, Z, W )`。無限遠では `W = 0` へ退化 |
| 位置検索 | ジャンプ＆ウォーク、期待 $O(n^{1/4})$ |
| 保存 | `*.lxtc`。座標と接続構造の全体 |
| 失敗 | `AddPoin` → `nil`、`DeletePoin` → `False`。何も変更しない |

## 2. 数学的背景

### 2.1 ドロネー四面体分割と空球性

有限集合 $P \subset \mathbb{R}^3$ に対し、四面体 $\{p_0,p_1,p_2,p_3\} \subset P$ が $\mathrm{Del}(P)$ に属するのは、その外接開球が $P$ を含まないとき、かつそのときに限ります [3]。

```math
\{p_0,p_1,p_2,p_3\} \in \mathrm{Del}(P)
\iff
\mathrm{int}\, B(p_0,p_1,p_2,p_3) \cap P = \varnothing .
\qquad \text{(2.1)}
```

$\mathrm{Del}(P)$ はボロノイ図 $\mathrm{Vor}(P)$ の双対です。胞の外心はボロノイ頂点であり、ドロネー*面*の双対は、その面に接する２つの胞の外心を結ぶボロノイ辺です [10]。平面と異なり複体の大きさは固定されません。よく散らばったサイトでは胞は $\Theta(n)$ 個ですが、最悪では $\Theta(n^2)$ 個になります。

### 2.2 リフト写像と統一空球述語

$\ell(p) = (p, \lVert p \rVert^2)$ を $\mathbb{R}^4$ の放物面 $w = x^2 + y^2 + z^2$ へのリフトとします。空間の球はこの放物面と超平面の交わりの鉛直射影であり、$q$ が球の内側にあるのは $\ell(q)$ が超平面の真下にあるとき、かつそのときに限ります。したがって $\mathrm{Del}(P)$ は $\ell(P)$ の下側凸包の射影です [4]。述語は、すべてのオペランドを判定点 $q$ へ平行移動してから評価されます。

```math
\mathrm{Lift}(p;q) =
\bigl(\, p_x - q_x,\; p_y - q_y,\; p_z - q_z,\; \lVert p - q \rVert^2 \,\bigr),
\qquad \text{(2.2)}
```

```math
\mathrm{InSphere}(p_0,p_1,p_2,p_3;\,q) \;=\;
\det\begin{pmatrix}
\mathrm{Lift}(p_0;q) \\ \mathrm{Lift}(p_1;q) \\ \mathrm{Lift}(p_2;q) \\ \mathrm{Lift}(p_3;q)
\end{pmatrix} .
\qquad \text{(2.3)}
```

この $4 \times 4$ 行列式は、空間成分のスカラー三重積をリフト高さで重み付けした符号付きの和として展開されます（`LiftDet` / `Det3`）。正の向きの胞では、$\mathrm{InSphere} > 0$ が「$q$ は外接球の内側」を意味します。これが `TDelaCell3D.InSphere` です。インスタンス版 `TDelaPoin3D.InSphered` は、レシーバを判定される点とした同じ行列式です。近傍の基準点へ平行移動してから倍精度で累算することが、座標が大きくても符号が信頼できる理由です [5]。本ユニットには、述語・向きの判定・外心のいずれにも、絶対座標のまま評価される式は存在しません。

### 2.3 無限遠頂点

たった一つ追加される頂点 $\infty$ が図を閉じます。凸包の各面 $(p_i,p_j,p_k)$ は*無限遠胞* $(\infty, p_i, p_j, p_k)$ を伴い、`Poin[]` に `nil` は現れません。組合せ的にはこれは一点コンパクト化 $\mathbb{R}^3 \cup \{\infty\} \cong S^3$ であり、図は $S^3$ の三角形分割で、どの面にもちょうど２つの胞が接します。図は共線でない最初の３サイトから、空間全体を二重に覆う鏡像の無限遠胞の対 $(\infty, p_0, p_1, p_2)$ と $(\infty, p_0, p_2, p_1)$ で種付けされます（`SeedCells` / `InitCell`）。４サイト目以降は通常の追加処理がそのまま働きます。

`TDelaPoin3DInf` はリフトを定数

```math
\mathrm{Lift}(\infty;q) = (0, 0, 0, 1)
\qquad \text{(2.4)}
```

で差し替えます。これは放物面の軸方向に沿った $\ell$ の極限方向です。(2.4) を (2.3) へ代入してその行に沿って展開すると、行列式は $3 \times 3$ の向きの行列式へ退化します。すなわち

```math
\mathrm{InSphere}(p_0, p_1, p_2, \infty;\, q)
= \bigl\langle\, p_0 - q,\; (p_1 - q) \times (p_2 - q) \,\bigr\rangle
= \mathrm{orient}(q, p_0, p_1, p_2) .
\qquad \text{(2.5)}
```

$\infty$ を通る球は平面 ―― 半径無限大の球 ―― であり、空球判定は自動的に半空間判定へ退化します。したがって §2.6 の歩行も同じ述語で駆動され、胞の向きの検査までもが「$\infty$ が外接球の外にあること」として書けます。述語に無限遠フラグの検査は存在しません。

### 2.4 同次外心とボロノイ図

胞の有限頂点 $B$ を基準として $L_i = \mathrm{Lift}(p_i;B)$ とし、$p_i$ の同次成分を $w_i \in \{1, 0\}$（$\infty$ では 0）とします。リフトの同次座標を $(X, Y, Z, U, W)$（$U$ が放物面の高さ）と書くと、４つのリフト点を通る超平面は

```math
\begin{vmatrix}
X & Y & Z & U & W \\
L_{0x} & L_{0y} & L_{0z} & L_{0u} & w_0 \\
L_{1x} & L_{1y} & L_{1z} & L_{1u} & w_1 \\
L_{2x} & L_{2y} & L_{2z} & L_{2u} & w_2 \\
L_{3x} & L_{3y} & L_{3z} & L_{3u} & w_3
\end{vmatrix} = 0
\;\;\Longleftrightarrow\;\;
a X + b Y + c Z + d U + e W = 0
\qquad \text{(2.6)}
```

であり、$a, b, c, d, e$ は $4 \times 4$ の符号付き小行列式です。(2.6) と $U = X^2 + Y^2 + Z^2$ の交わりは中心 $\bigl(-a/(2d),\, -b/(2d),\, -c/(2d)\bigr)$ の球なので、`Circum` は

```math
\mathrm{Circum} = (\,-a,\; -b,\; -c,\; 2d\,)
\qquad \text{(2.7)}
```

を返します（基準点ぶんは最後に同次のまま戻されます）。有限胞では外心が $(X/W, Y/W, Z/W)$、無限遠胞では超平面 (2.6) が鉛直になって $W = 2d = 0$ となり、$(X, Y, Z)$ が凸包面に双対な非有界ボロノイ辺の外向きの方向になります。計算に分岐も除算もなく、中心＋半径という表現を呼び出し側に押し付けることもありません。`Circum` の型は `TSingle4D` で、その第４成分が同次成分 `W` です。

### 2.5 追加と削除

**追加**（公開 API は `AddPoin`、実処理は非公開の `InsertPoin`）は Bowyer–Watson 法 [1][2] です。新しいサイト $p$ のキャビティ

```math
\mathcal{C}(p) = \{\, \sigma \in \mathrm{Del}(P) \;:\; p \in \mathrm{int}\, B_\sigma \,\}
\qquad \text{(2.8)}
```

は $p$ に関して星型であり、

```math
\mathrm{Del}(P \cup \{p\}) = \bigl(\mathrm{Del}(P) \setminus \mathcal{C}(p)\bigr) \;\cup\; \{\, p * f \;:\; f \in \partial\mathcal{C}(p) \,\}
\qquad \text{(2.9)}
```

が成り立ちます。実装は２相です。①**マーク**: 着地した胞から Flag の塗り広げで $\mathcal{C}(p)$ を集めます。３次元ではキャビティの双対が木にならないため、同じ胞へ複数の経路から到達し得ますが、塗りは冪等なので二重処理は起こりません。②**カーブ**: 境界面ごとに新しい胞を張り、外側および $p$ の周りの隣どうしと縫い、最後に塗った胞をまとめて解放します。解放は縫合の後なので、削除済みの胞への再突入は構造的に起こりません。プレースホルダも再帰もありません。

**削除**（公開 API は `DeletePoin`、実処理は非公開の `RemovePoin`）は $v$ の星を取り除きます（`CollectStar`）。すると境界が $\mathrm{link}(v)$ である星型の穴が開き、

```math
\mathrm{Del}(P \setminus \{v\}) \;=\; \bigl(\mathrm{Del}(P) \setminus \mathrm{star}(v)\bigr) \;\cup\; \mathcal{F},
\qquad
\mathcal{F} \subset \mathrm{Del}\bigl(\mathrm{link}(v)\bigr)
\qquad \text{(2.10)}
```

によって埋め戻されます ―― 穴の再分割がリンク頂点だけを使うという古典的な事実です [8][11]。そこでリンクの小さなドロネー図を、*同じ胞集合の中の独立した成分*として逐次添加法で作り（入れ子の `TDelaunay3D` は作りません）、穴を埋める胞をそこから切り出して `Weld` で縁に縫い付けます。切り出しは、穴の境界面へ鏡像の向きで貼り合わせられる胞（`CanWeld`）から始め、境界を越えずに届くものすべてへ塗り広げます。「削除点を外接球に含む胞」という述語は**用いません**。一般の配置では両者は一致しますが、共球の退化では削除点がちょうど外接球面上に乗る胞が穴の中に現れ、述語が破れるためです。全ての工程はフリップの探索を含まない組合せ的な検査であり、退化配置で検査に通らなければ、元の図を一切変えずに `False` を返します。

### 2.6 クエリ

`HitSphereCell` は、判定点を外接球に含む胞を*ジャンプ＆ウォーク* [6] で探します。$n^{1/4}$ 個のサイトを無作為に引き、最も近いもののアンカー胞から出発し、判定点が外側にある面を越え続けます。面の判定は統一述語の退化形 (2.5) なので、凸包の外の点では歩行が自然に無限遠胞へ入って止まります。期待計算量は $O(n^{1/4})$。標本は呼び出しごとに引き直されるため、性能は領域全体で一様で、クエリの履歴に依りません。

`FindNearPoin` は着地した胞 ―― その頂点は必ず判定点の近くにあります ―― から始め、ドロネー辺を伝ってより近い隣接頂点へ貪欲に降下します。各段で距離が厳密に縮むため、降下は判定点をボロノイ領域に含むサイトで停止します。期待 $O(n^{1/4})$ ＋ $O(1)$ 段の降下です。

`FindMaxCircle` は最大の空球をもつ有限胞を返します。空球の半径が無限大となる無限遠胞は除かれます。

## 3. アーキテクチャ

### 3.1 クラス図

```
継承関係

・TTetraPoin3D<TDelaCell3D>    ：(LUX)
  ┗・TDelaPoin3D
     ┗・TDelaPoin3DInf

・TTetraPoinSet3D<TDelaPoin3D>    ：(LUX)
  ┗・TDelaPoinSet3D

・TTetraCell3D<TDelaPoin3D,TDelaCell3D>    ：(LUX)
  ┗・TDelaCell3D

・TTetraCellSet3D<TDelaCell3D,TDelaPoinSet3D>    ：(LUX)
  ┗・TDelaCellSet3D
     ┗・TDelaunay3D

・TControl3D    ：(FMX)
  ┗・TDelaunayLayer
     ┣・TDelaunayEdges
     ┗・TDelaunayVoros

・TViewport3D    ：(FMX)
  ┗・TDelaunayViewport

・TFrame    ：(FMX)
  ┗・TDelaunayViewer

所有・参照関係

・TDelaunay3D    ：( = TDelaCellSet3D = 胞集合そのもの )
  ┣・Poins :TDelaPoinSet3D
  ┃  ┗・1..* TDelaPoin3D
  ┃     ┣・Pos
  ┃     ┗・Cell, Corn    ：アンカー
  ┣・Cells :TDelaCellSet3D    ：( = Self )
  ┃  ┗・1..* TDelaCell3D
  ┃     ┣・Poin[0..3]    ：正の向き。無限遠胞はここに PoinInf を持つ
  ┃     ┣・Cell[0..3]    ：隣接胞
  ┃     ┗・Corn / Bond / Join
  ┣・PoinInf :TDelaPoin3DInf    ：全ての無限遠胞が共有
  ┗・OnChange :TDelegates    ：ビューアへ通知

・TDelaunayViewer
  ┗・Viewport :TDelaunayViewport
     ┣・TDummy    ：ヨー
     ┃  ┗・TDummy    ：ピッチ
     ┃     ┣・TCamera
     ┃     ┗・TLight    ：ヘッドライト
     ┣・TDelaunayEdges
     ┗・TDelaunayVoros
```

### 3.2 ファイル構成

```
・D3/
  ┣・LUX.Delaunay.D3.pas    ：unit LUX.Delaunay.D3
  ┃  ┣・TDelaPoin3D    ：頂点: Inf, Lift, InSphered
  ┃  ┣・TDelaPoin3DInf    ：無限遠頂点: Lift ≡ ( 0, 0, 0, 1 )
  ┃  ┣・TDelaPoinSet3D    ：点集合（有限頂点のみ）
  ┃  ┣・TDelaCell3D    ：四面体: InfCorn, Circum, InSphere, IsHitSphere
  ┃  ┣・TDelaCellSet3D    ：胞集合
  ┃  ┗・TDelaunay3D    ：モデル: AddPoin / DeletePoin / クエリ / 入出力
  ┣・LUX.Delaunay.D3.Viewer.pas / .fmx    ：unit LUX.Delaunay.D3.Viewer
  ┃  ┣・TDelaunayLayer    ：レイヤの基底: メッシュの器と材質、Render
  ┃  ┣・TDelaunayEdges    ：ドロネー辺（多角形の管）
  ┃  ┣・TDelaunayVoros    ：ボロノイ辺（三角柱と錐）
  ┃  ┣・TDelaunayViewport    ：内部の TViewport3D
  ┃  ┗・TDelaunayViewer    ：TFrame 本体（軌道リグ・ヘッドライト・ピッキング）
  ┣・README.md    ：英語版
  ┗・ja/README.md    ：本ドキュメント
```

[LUX](https://github.com/LUXOPHIA/LUX) の TetraFlip メッシュ層（`LUX.Data.Model.TetraFlip.core`・`LUX.Data.Model.TetraFlip.D3`）の上に構築されています。これらの層が点と胞を所有し、接続構造・角と回転の巡回表（`VertTable` / `BondTable`）・面の縫合（`Weld` / `CanWeld`）・隣接検査（`CheckCells`）・列挙を担います。`LUX.Delaunay.D3` はドロネー固有の機能だけを加え、TetraFlip の型付け層には自分の派生クラスを型引数として与えます。

### 3.3 クラス一覧 ― `LUX.Delaunay.D3`

#### `TDelaPoin3D` ― 頂点

| メンバ | 説明 |
|---|---|
| `Pos :TSingle3D` | 座標。*(継承)* |
| `Cell :TDelaCell3D` / `Corn :Byte` | アンカー: この頂点を含む胞の一つと、その中での頂点番号。*(継承)* |
| `Inf :Boolean` | 無限遠頂点かどうか。 |
| `Lift( Pos_ ) :TDouble4D` | 基準点 `Pos_` から見たリフト (2.2)（倍精度）。 |
| `InSphered( P0_,P1_,P2_,P3_ ) :Double` | 球 `( P0, P1, P2, P3 )` に対する自分の内外の符号 ― 正 = 内側。 |

#### `TDelaPoin3DInf` ― 無限遠頂点

`TDelaPoin3D` の派生。`Lift`（定数 `( 0, 0, 0, 1 )`・式 2.4）と `InSphered`（球の向きへの退化）を多態で差し替えます。図につき唯一のインスタンス `TDelaunay3D.PoinInf` で、点集合には属さず `Poins` にも現れません。

#### `TDelaCell3D` ― 四面体

| メンバ | 説明 |
|---|---|
| `Poin[0..3] :TDelaPoin3D` | 頂点（正の向き）。*(継承)* |
| `Cell[0..3] :TDelaCell3D` | 頂点 `K` の対面で接する隣接胞。*(継承)* |
| `Corn[0..3] :Byte` | 隣接胞から見た、共有面の対頂点の番号。*(継承)* |
| `Bond[0..3] :Byte` | 共有面の貼り合わせの回転コード。*(継承)* |
| `Join[K,I] :Byte` | 面 `K` を挟む頂点対応: こちら側の枠番号 `I` → 隣接胞での頂点番号。*(継承)* |
| `InfCorn :Shortint` | 無限遠頂点の番号 ― `-1` は有限胞。 |
| `Circum :TSingle4D` | 同次外心 (2.7)。有限胞 → 外心 `( X/W, Y/W, Z/W )`、無限遠胞 → `W = 0` で `( X, Y, Z )` が双対ボロノイ辺の外向きの方向。 |
| `InSphere( P0_..P3_, Pos_ ) :Double` *(class)* | 統一リフト行列式 (2.3) ― 正 = `Pos_` が球 `( P0 … P3 )` の内側。 |
| `IsHitSphere( Pos_ ) :Boolean` | `Pos_` がこの胞の外接球の内側にあるか。 |

#### `TDelaPoinSet3D` / `TDelaCellSet3D` ― 集合

列挙可能なコンテナ（`for C in …`・`Count`・`[I]`）。`TDelaCellSet3D.Poins` は**有限の**頂点だけを見せます。

#### `TDelaunay3D` ― ドロネー図

| メンバ | 説明 |
|---|---|
| `Create` / `Destroy` | 空の図。点集合と無限遠頂点を所有します。 |
| `PoinInf :TDelaPoin3D` | 唯一の無限遠頂点。 |
| `Cells :TDelaCellSet3D` | 無限遠胞を含む全ての胞（自分自身の別名）。 |
| `Poins :TDelaPoinSet3D` | 全ての有限頂点。 |
| `OnChange :TDelegates` | 構造が変化するたびに発火する多播通知。`Add` で購読、`Del` で解除。 |
| `HitSphereCell( Pos_ ) :TDelaCell3D` | `Pos_` を外接球に含む胞 ― ジャンプ＆ウォーク、期待 $O(n^{1/4})$。 |
| `FindMaxCircle :TDelaCell3D` | 最大の空球をもつ有限胞。無ければ `nil`。 |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | 最近傍頂点と、そこまでの距離（位置検索＋貪欲降下）。図が空なら `Poin_ = nil` と `Infinity`。 |
| `AddPoin( Pos_ ) :TDelaPoin3D` | サイトの追加（§2.5）。追加できない場合（座標が数でない・重複・最初の２点と共線の３点目・既存の稜線の延長上などの退化配置）は `nil`。最初の２点は無条件に受け入れられ、３点目以降は常に胞が存在します。 |
| `AddPoin( Pos_, Cell_ ) :TDelaPoin3D` | 所属胞が既知の追加。検索を省き、検証もおこないません。`Cell_` は `Pos_` を外接球に含む胞でなければなりません。 |
| `DeletePoin( Poin_ ) :Boolean` | 頂点の削除（§2.5）。不正な入力や埋め戻せない退化配置では、何も変えずに `False`。 |
| `Clear` | 全ての点と胞を消去します（`PoinInf` は残ります）。 |
| `SaveToFile( FileName_ )` | 図を `*.lxtc` ファイルへ保存します。座標と接続構造の全体を含むため、構造がそのまま往復します。 |
| `LoadFromFile( FileName_ )` | `*.lxtc` ファイルから図を復元します。現在の内容は全て置き換わり、無限遠頂点も接続ごと再現され、`OnChange` が一度発火します。 |

#### ファイル形式 `*.lxtc`

Radiance HDR 形式と同じ構成です。冒頭は UTF-8 テキストで、1行目が固有のヘッダ `LUXOPHIA TetFlip 1.0`、以降は `名前=値` のオプション行（`PoinsN` / `CellsN` / `PosSize`。未知の行は読み飛ばされます）。1行の空行でヘッダが終わり、それ以降はバイナリです ―― 点の座標列、続いて胞ごとに頂点番号 ×4・隣接胞番号 ×4（`Int32`。`-1` = nil、`-2` = 無限遠頂点）と、`Corn` / `Bond` / `Flag` の3バイト。

### 3.4 クラス一覧 ― `LUX.Delaunay.D3.Viewer`

`TDelaunay3D` を内部の `TViewport3D` で描画する `TFrame`。FMX のシーン生成コードはすべてこのフレームの中に閉じています。`OnChange` を購読し、シーンを（全廃棄・全構築で）自動的に再構築します。再構築は次の描画の直前まで遅延され、1フレームに1回だけおこなわれます。曲面は使いません。どちらのレイヤも、辺からマージンだけ切り下げた平面の帯・柱・錐だけで構成されるため、フラットな面法線が図の稜線をそのまま見せます。

#### `TDelaunayViewer` ― フレーム

| メンバ | 説明 |
|---|---|
| `Delaunay :TDelaunay3D` | 表示する図。代入で `OnChange` を購読します。`nil` の代入で解除（図を解放する前におこなうこと）。 |
| `Camera :TCamera` | 内蔵の軌道リグ（ヨー → ピッチ → カメラ、ヘッドライト付き）の先端のカメラ。 |
| `Color :TAlphaColor` | 背景色。 |
| `Distance :Single` | 原点からのカメラ距離。 |
| `Edges :TDelaunayEdges` | ドロネー辺レイヤ（下記）。 |
| `Voros :TDelaunayVoros` | ボロノイ辺レイヤ（下記）。 |
| `Orbit( DYaw_, DPitch_ )` | 軌道リグを回します（度）。 |
| `Dolly( DDistance_ )` | カメラ距離を変えます。 |
| `FindPoin( Scr_, Radius_ ) :TDelaPoin3D` | 投影がスクリーン座標に最も近い頂点（`Radius_` 論理ピクセル以内）。無ければ `nil`。ピッキング用。 |

#### `TDelaunayEdges` ― ドロネー辺

各有限胞の各頂点 `K` について、その頂点を囲む3面のコーナー点を結ぶ4枚の三角形（中央の1枚＋辺沿いの3枚）を張ります。コーナー点は `MarginCorner`（角の二等分線上・両辺から距離 `Margin` の点。`Margin` は三角形の内接円半径 $2A/\ell$ でクランプ）です。各ドロネー辺のまわりでは、辺の環をなす胞の帯が繋がって閉じた多角形の管になります。凸包の面 ―― 無限遠胞に接する面 ―― にはさらに外側の帯を張り、管を外から閉じます。

| メンバ | 説明 |
|---|---|
| `Color :TAlphaColor` | 材質の色。 |
| `Margin :Single` | 辺から測った帯の幅。 |

#### `TDelaunayVoros` ― ボロノイ辺

各有限胞の外心はボロノイ頂点です。そのまわりに、そこから出る4本の辺方向の対ごとのコーナー三角形が小さな殻を作ります。有限の隣へは三角柱の半分を渡し、両側の半分が合わさってボロノイ辺1本につき1本の柱になります。非有界の辺は長さ `RayLength` の錐で閉じます。辺の方向は隣接胞の同次外心から得られます ―― 有限の隣 → その外心へ、無限遠の隣 → `W = 0` の外向きの方向 (2.7) ―― 幾何の側に場合分けはありません。

| メンバ | 説明 |
|---|---|
| `Color :TAlphaColor` | 材質の色。 |
| `Margin :Single` | ボロノイ辺から柱の面までの距離。 |
| `RayLength :Single` | 非有界の辺の錐の長さ。 |

## 4. 使い方

### 4.1 構築とクエリ

```pascal
uses LUX, LUX.D3, LUX.D4, LUX.Delaunay.D3;

var
   D :TDelaunay3D;
   P :TDelaPoin3D;
   C :TDelaCell3D;
   N :Integer;
begin
     D := TDelaunay3D.Create;

     for N := 1 to 100 do D.AddPoin( 2 * TSingle3D.RandG );     // 追加

     for C in D.Cells do                                        // 四面体を列挙
     begin
          if C.InfCorn < 0 then { C.Poin[0..3] が有限の四面体 };
     end;

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1     // 最近傍頂点と、そこまでの距離
     then D.DeletePoin( P );                                     // 削除

     D.Free;
end;
```

### 4.2 ボロノイ図の取り出し

ボロノイ頂点は有限胞の外心です。各ボロノイ辺はドロネー面の双対で、面に接する２胞の外心を結びます。式 (2.7) は有界・非有界の辺を同じ式で扱います。

```pascal
var
   C      :TDelaCell3D;
   K      :Byte;
   V0, V1 :TSingle4D;
   P0, P1 :TSingle3D;
begin
     for C in D.Cells do
     begin
          if C.InfCorn >= 0 then Continue;                 // ボロノイ頂点は有限胞の上にある

          V0 := C.Circum;  P0 := TSingle3D.Create( V0.X, V0.Y, V0.Z ) / V0.W;

          for K := 0 to 3 do
          begin
               V1 := C.Cell[ K ].Circum;

               if V1.W > 0
               then P1 := TSingle3D.Create( V1.X, V1.Y, V1.Z ) / V1.W                    // 隣の外心までの線分
               else P1 := P0 + RayLength * TSingle3D.Create( V1.X, V1.Y, V1.Z ).Unitor;  // 凸包面の外向きの半直線

               // P0 – P1 を描く（内部の辺は両側から訪れるので、中点まで描くか
               //                 C < C.Cell[K] の側だけ描いて重複を避ける）
          end;
     end;
end;
```

### 4.3 ビューア

フォームに `TDelaunayViewer` を置き（実行時に `Parent` を与えて生成しても可）、図を渡します。

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
     _Delaunay := TDelaunay3D.Create;

     with Viewer1 do
     begin
          Delaunay := _Delaunay;

          Distance := 15;

          Edges.Margin    := 0.05;
          Voros.Margin    := 0.05;
          Voros.RayLength := 10;
     end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
     Viewer1.Delaunay := nil;  // モデルを解放する前に購読を解除する

     _Delaunay.Free;
end;
```

編集はすべてモデルに対しておこないます ―― ビューアは勝手に追従します。マウス操作はアプリケーション側に置き、フレームは `Orbit` / `Dolly` / `FindPoin` だけを提供します。

```pascal
procedure TForm1.Viewer1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
     if _Dragging then Viewer1.Orbit( X - _MouseP.X, -( Y - _MouseP.Y ) );  // ドラッグ = 回転
end;

procedure TForm1.Viewer1MouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
     Viewer1.Dolly( - WheelDelta / 120 );  Handled := True;                 // ホイール = ズーム
end;

procedure TForm1.Viewer1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   V :TDelaPoin3D;
begin
     V := Viewer1.FindPoin( TPointF.Create( X, Y ), 16 );                   // クリック = 拾って削除

     if Assigned( V ) then _Delaunay.DeletePoin( V );
end;
```

完全な対話的アプリケーションは [Delaunay3D](https://github.com/LUXOPHIA/Delaunay3D) にあります。

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
11. Devillers, O., Teillaud, M., [*Perturbations and vertex removal in a 3D Delaunay triangulation*](https://inria.hal.science/inria-00166710), Proc. 14th ACM-SIAM Symposium on Discrete Algorithms (SODA), 313–319, 2003.

## 💖 [Embarcadero](https://www.embarcadero.com/jp/) [**Delphi**](https://www.embarcadero.com/jp/products/delphi)
ネイティブなクロスプラットフォームアプリを開発するための統合開発環境（ＩＤＥ）。
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/jp/products/delphi/starter)
