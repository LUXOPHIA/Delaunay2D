# Delaunay2D

[English](../README.md) | [日本語](README.md)

Delphi（FireMonkey）による対話的な 2D ドロネー図／ボロノイ図のデモです。クリックで点を追加・削除すると、ドロネー三角形分割・外接円・ボロノイ図がリアルタイムに更新されます。アプリケーションは [LUX.Delaunay](https://github.com/LUXOPHIA/LUX.Delaunay) ライブラリの上の薄いフォームであり、逐次添加アルゴリズム（`TDelaunay2D`）と Skia ベースのビューア（`TDelaunayViewer`）はどちらもライブラリが提供します。

![Delaunay2D](../--------/_SCREENSHOT/Delaunay2D.png)

## 利用ライブラリ

* [**LUX**](https://github.com/LUXOPHIA/LUX) ：ベクトル・行列・色・曲線などを提供する基盤数学ライブラリ。
* [**LUX.CG2D**](https://github.com/LUXOPHIA/LUX.CG2D) ：Skia4Delphi による２Ｄシーングラフ描画ライブラリ。
* [**LUX.Delaunay**](https://github.com/LUXOPHIA/LUX.Delaunay) ：動的な追加・削除に対応するドロネー複体ライブラリ（平面・空間・トーラス）。

## 1. 概要

- Bowyer–Watson 法 [1][2] による **逐次追加** と、リンクの小さなドロネー図による決定論的な埋め戻しを伴う星の除去 [4] による **削除**。どの操作の後も図は常にドロネーであり、退化した入力には `AddPoin` が `nil` を、`DeletePoin` が `False` を返して図を一切変更しません。
- **無限遠頂点方式** — スーパートライアングルもバウンディングボックスも使いません。ただ一つの無限遠頂点が凸包を閉じるため、凸包上の点も内部の点とまったく同じように扱え、空円判定に場合分けが要りません。
- **同次外心** — 各面の外心を分岐も除算もなしに同次座標 $(C_X, C_Y, C_W)$ として取り出します。無限遠面は自然に $C_W = 0$ へ退化し、非有界なボロノイ辺の方向を与えます。
- **ジャンプ＆ウォーク位置検索** [5]（期待コスト $O(n^{1/3})$）。最近傍検索にも再利用されます。
- 描画はすべてライブラリの `TDelaunayViewer` フレーム（[LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) 上の Skia シーングラフ）が担い、アプリケーション自体は描画コードを持ちません。

## 2. 数学的背景

### 2.1 ドロネー三角形分割と空円性

一般の位置にある有限点集合 $S \subset \mathbb{R}^2$ に対し、ドロネー三角形分割 $\mathrm{DT}(S)$ は、どの三角形の開外接円板も $S$ の点を含まない唯一の三角形分割です [6]。これは $S$ のボロノイ図の幾何学的双対であり、ボロノイ頂点はドロネー三角形の外心、各ボロノイ辺は隣接する三角形の間のドロネー辺に直交する双対辺です。

### 2.2 リフトによる空円判定

空円判定は、放物面 $z = x^2 + y^2$ への古典的なリフト写像で評価します。点が $P_1, P_2, P_3$（反時計回り）を通る円の内側にあることは、リフトされた像が $P_1, P_2, P_3$ のリフト像を通る平面の下側にあることと同値です。判定点 $Q$ を原点へ平行移動すると、これは単一の $3 \times 3$ 行列式になります。

```math
\mathrm{InCircle}(P_1,P_2,P_3;\,Q)
=
\begin{vmatrix}
x_1 - q_x & y_1 - q_y & (x_1 - q_x)^2 + (y_1 - q_y)^2 \\
x_2 - q_x & y_2 - q_y & (x_2 - q_x)^2 + (y_2 - q_y)^2 \\
x_3 - q_x & y_3 - q_y & (x_3 - q_x)^2 + (y_3 - q_y)^2
\end{vmatrix}
> 0
\;\Longleftrightarrow\;
Q \text{ inside.}
\qquad \text{(2.1)}
```

これがまさに `TDelaFace2D.InCircle` です。各頂点は `TDelaPoin2D.Lift( Q )` で自分の行を供給し、行列式は3行のスカラー三重積として計算されます。評価の前に近傍の点へ平行移動することは数値的頑健性の要です — `Single` 座標の差は `Double` で取るため正確であり、絶対座標のままでは起こる桁落ちが決して起こりません。外心（2.4節）も同じ平行移動評価を用います。

### 2.3 無限遠頂点方式

入力をスーパートライアングルで囲む代わりに、モデルはただ一つの **無限遠頂点** $P_\infty$（クラス `TDelaPoin2DInf`）を持ち、凸包の各辺 $(P_i, P_j)$ は *無限遠面* $(P_\infty, P_i, P_j)$ で閉じられます。したがってすべての辺はちょうど2つの面に接し、`Poin[]` に `nil` は現れません。

述語はリフトの同次化で拡張されます。点は同次成分 $w$ を持つ行 $(x - w b_x,\; y - w b_y,\; \dots,\; w)$ を供給し、有限点は $w = 1$、$P_\infty$ は $w = 0$ で、そのリフト行は $(0, 0, 1)$ になります（`TDelaPoin2DInf.Lift`）。この行を (2.1) に代入すると、行列式は $2 \times 2$ の向き判定に潰れます。

```math
\begin{vmatrix}
x_1 - q_x & y_1 - q_y & \ast \\
x_2 - q_x & y_2 - q_y & \ast \\
0 & 0 & 1
\end{vmatrix}
=
\begin{vmatrix}
x_1 - q_x & y_1 - q_y \\
x_2 - q_x & y_2 - q_y
\end{vmatrix}
= \mathrm{orient2d}(P_1, P_2, Q).
\qquad \text{(2.2)}
```

つまり $P_\infty$ を含む面の「外接円」は半径無限大の円 — 凸包辺で区切られた半平面 — であり、まったく同じ式が半平面判定を行います。リフト空間では円も直線もただの平面なので場合分けは不要です。差し替えは多態で行われ（`TDelaPoin2DInf` が `Lift` と `InCircled` をオーバーライド）、述語自体にフラグの分岐は存在しません。逆に、$P_\infty$ が円の内側にあるかの判定（`TDelaPoin2DInf.InCircled`）は円の向きの符号に帰着します。無限遠点を内側に置くのは負の向きの円だけです。

### 2.4 同次外心とボロノイ双対性

面の外心は同次座標 $\mathrm{Circum} = (C_X, C_Y, C_W)$ — リフトされた3頂点を通る平面の係数（小行列式）— として取り出されます。2.2節と同様に有限の基準頂点 $B$ へ平行移動した同次リフト行 $(x_i, y_i, z_i, w_i)$ を用いて、

```math
C_X = -\begin{vmatrix} y_1 & z_1 & w_1 \\ y_2 & z_2 & w_2 \\ y_3 & z_3 & w_3 \end{vmatrix},
\qquad
C_Y = +\begin{vmatrix} x_1 & z_1 & w_1 \\ x_2 & z_2 & w_2 \\ x_3 & z_3 & w_3 \end{vmatrix},
\qquad
C_W = 2\begin{vmatrix} x_1 & y_1 & w_1 \\ x_2 & y_2 & w_2 \\ x_3 & y_3 & w_3 \end{vmatrix}.
\qquad \text{(2.3)}
```

- **有限面**（$w_1 = w_2 = w_3 = 1$）では外心は $(C_X / C_W,\; C_Y / C_W)$ で、外接半径は任意の頂点までの距離として得られます。
- **無限遠面** では $P_\infty$ の行が $x, y, w$ 列で零になるため、(2.3) は自然に $C_W = 0$ へ退化し、$(C_X, C_Y)$ は凸包辺に双対な非有界ボロノイ辺の外向きの方向になります。

計算に分岐も除算もなく、外心を持たない面に「中心＋半径」という表現を押し付けることもありません。ビューアはこの双対性からボロノイ図を直接描画します。各有限面について、その外心から3つの隣接面の外心へ向かう半辺を描き、無限遠の隣接面は方向ベクトルに沿った遠方の点で寄与します。

### 2.5 追加：Bowyer–Watson 法

新しい点 $P$ は2相の Bowyer–Watson 方式 [1][2] で挿入されます（公開 API は `AddPoin`、実処理は非公開の `TDelaunay2D.InsertPoin`）。

1. **マーク。** $P$ を外接円に含むひとつの面から出発し、隣接面へ塗り広げて、$P$ を外接円に含むすべての面に印を付けます。この集合 — *キャビティ* — は連結で、$P$ に関して星型です。マークは冪等なので、共円の退化で同じ面へ複数の経路から到達しても二重処理は起こりません。
2. **カーブ。** キャビティの各境界辺 $(A, B)$ に新しい面 $(A, P, B)$ を張り、辺を越えて外側の面と縫い、次に新しい面どうしを $P$ の周りで縫います。最後に印を付けた面をまとめて解放します（解放は縫合の後なので、削除済みの面への再突入は構造的に起こりません）。

凸包は無限遠面で閉じられているため、現在の凸包の外への挿入は特別扱いになりません。キャビティが無限遠面を含むだけです。含む面が見つからない場合（重複点や、退化した共線辺の延長上の点）は `AddPoin` が `nil` を返し、何も変更されません。

### 2.6 削除：星の除去と埋め戻し

頂点 $V$ の削除は、その *星*（$V$ を含む面）を取り除き、境界が $V$ の *リンク* である星型の穴を残します（公開 API は `DeletePoin`、実処理は非公開の `TDelaunay2D.RemovePoin`）。

1. **収集。** 頂点アンカーを用いて $V$ の周りを巡り、星・境界辺（それぞれ外側の面を「フック」として控える）・重複を除いた有限のリンク頂点を集めます。構造を読むだけで、何も壊しません。
2. **構築。** リンク頂点 *だけ* の小さなドロネー図を、同じ面集合の中の独立した成分として（入れ子の `TDelaunay2D` は作らずに）同じ逐次添加法で作ります。どの外接円にもまだ入らず見送られた頂点（種の直線上の退化）は、挿入が起きなくなるまで再試行し、それでも残れば埋め戻し不能です。
3. **縫い目の照合。** 穴の各境界辺 $P_A \to P_B$ について、その辺を *同じ向きで* 含む小さなドロネー図の面（穴の側の面）を探します。境界辺が現れない場合や、2本の境界辺が同じ縫い目に割り当たる場合（潰れた穴）は中止します。
4. **埋め草の塗り広げ。** 縫い目の面から出発し、縫い目を越えずに塗り広げ、閉包の境界が穴の境界とちょうど一致することを組合せ的に確かめます（埋め草に無限遠面が現れてよいのは、穴が凸包に接しているときだけです）。
5. **縫い付け。** 埋め草の面をフックに縫い付け、星と小さなドロネー図の使わなかった面を解放し、頂点アンカーを張り直します。

選別も縫合もすべて組合せ的な検査だけで確定し、フリップの探索はありません。いずれかの検査に失敗した場合（退化配置）、元の三角形分割には一切触れておらず、`DeletePoin` は `False` を返します。次数2の頂点（共線被覆の端点など）は、外側の2面を直接貼り合わせて処理します。これはドロネー頂点削除における局所再三角形分割のアプローチ [4] に対応します。

### 2.7 位置検索と最近傍検索

判定点 $Q$ を外接円に含む面は **ジャンプ＆ウォーク** [5]（`HitCircleFace`）で見つけます。$\lceil n^{1/3} \rceil$ 個の頂点を無作為に引き、最も近い標本のアンカー面から出発して、(2.2) の退化形 $\mathrm{InCircle}(A, B, P_\infty; Q) = \mathrm{orient2d}(A, B, Q)$ で決まる「$Q$ が外側にある辺」を越えて渡り続けます。標本数は歩行距離との釣り合いで選ばれ、期待合計コストは $O(n^{1/3})$ です。標本は毎回引き直すため、性能は領域全体で一様であり、クエリの履歴に依存しません。$Q$ が凸包の外にあれば、歩行は自然に無限遠面へ入って止まります。共円や収束しない退化は全面走査へ退避します。

最近傍検索（`FindNearPoin`）は、着地面の最も近い頂点から出発してドロネー辺に沿って降下します。$Q$ により近いドロネー隣接頂点がある限りそこへ移る、を繰り返します。距離が厳密に縮むため歩行は必ず停止し、その停止点は $Q$ をボロノイ領域に含む頂点 — すなわち真の最近傍点です。ドロネー三角形分割では、最近傍でない頂点は必ずクエリにより近いドロネー隣接頂点を持つからです。期待コストは位置検索のコストに $O(1)$ 段の降下を加えたものです。

## 3. アーキテクチャ

```
[Composition]
・TForm1 (Main.pas / Main.fmx)    ：Application
  ┣・_Delaunay :TDelaunay2D    ：model, owned by the form (LUX.Delaunay.D2)
  ┗・Viewer1 :TDelaunayViewer (TFrame)    ：Skia view (LUX.Delaunay.D2.Viewer)
     ┗・_Layers :TCGLayers    ：LUX.CG2D scene
        ┣・TDelaunayTrias    ：triangles
        ┣・TDelaunayCircs    ：circumcircles
        ┣・TDelaunayVolos    ：Voronoi
        ┣・TDelaunayPoins    ：vertices
        ┗・TCGLayer
           ┗・TCGCamera    ：viewpoint

[Call and notification flow]
・TForm1
  ┗・AddPoin / DeletePoin / Clear    ：form → model
     ┗・TDelaunay2D
        ┗・OnChange (multicast)    ：model → view
           ┗・TDelaunayViewer    ：holds the model; rebuilds its scene

[Inheritance: TriFlip mesh layer (LUX) → Delaunay classes]
・TTriPoin2D<F>
  ┗・TDelaPoin2D
     ┗・TDelaPoin2DInf

・TTriPoinSet2D<P>
  ┗・TDelaPoinSet2D

・TTriFace2D<P,F>
  ┗・TDelaFace2D

・TTriFaceSet2D
  ┗・TDelaFaceSet2D
```

モデルは構造の変化を多播デリゲート `TDelaunay2D.OnChange` で発行し、ビューアはそれを購読してシーンを遅延再構築します — 再構築は `Paint` の直前まで遅延され、`BeginUpdate` / `EndUpdate` で束ねて1フレームに最大1回だけ走ります。頂点・面の接続（`Poin` / `Face` / `Corn`）、巡回表（`VertTableInc` / `VertTableDec`）、所有はジェネリックな TriFlip メッシュ層が提供し、ドロネー側のクラスはリフト・述語・同次外心・アルゴリズムだけを加えます。

```
・Delaunay2D.dpr / .dproj    ：application project (FMX, Win32 / Win64)
・Main.pas / Main.fmx    ：TForm1: thin form; no drawing code
・_LIBRARY\LUXOPHIA\    ：git-subtree copies of separate library repos
  ┣・LUX\    ：base library: vectors, lists/trees, TriFlip mesh model
  ┣・LUX.CG2D\    ：2D scene graph on Skia (TCGLayer, TCGCamera, shapes)
  ┗・LUX.Delaunay\
     ┣・D2\LUX.Delaunay.D2.pas    ：TDelaunay2D and companion classes (model)
     ┣・D2\LUX.Delaunay.D2.Viewer.pas/.fmx    ：TDelaunayViewer frame (view)
     ┗・D2\Periodic\, D3\    ：bundled with the subtree; unused by this demo
```

## 4. 使い方／操作

| 入力 | 動作 |
|---|---|
| 空白をクリック | カーソル位置に点を追加 |
| 点（の近く）をクリック | その点を削除（ワールド座標で距離 6 以内の最近傍点） |
| `Add x10` ボタン | ガウス分布の乱数点を10個追加（各軸 $100 \cdot \mathcal{N}(0,1)$） |
| `Del x10` ボタン | 無作為に選んだ点を最大10個削除 |
| `Clear` ボタン | 全点を削除 |

フォームは `FormCreate` でビューを設定します。カメラの視野（`Camera.SizeX/Y = 600`）と各レイヤのスタイル（`Poins` / `Trias` / `Circs` / `Volos` → `Style.FillColor` / `LineColor` / `LineThick`）です。マウス座標は `Viewer1.ScrToPos` でモデル座標へ変換します。

## 5. ビルド

1. RAD Studio で `Delaunay2D.dproj` を開きます（Skia 対応の FMX が必要。RAD Studio 12 以降は Skia 統合を同梱）。
2. Win32 または Win64 を選んで実行します（プロジェクトは両方をターゲットにしています）。

プロジェクトは起動時に `GlobalUseSkia := True` を設定します。ビューアは FMX キャンバスが Skia キャンバス（`TSkCanvasCustom`）であることを要求し、そうでなければ何も描画しません。その他の外部依存はありません — ライブラリのコードはすべて git subtree として `_LIBRARY\` 以下に含まれています。

## 6. 参考文献

1. A. Bowyer, *Computing Dirichlet tessellations*, The Computer Journal, 24(2), pp. 162–166, 1981.
2. D. F. Watson, *Computing the n-dimensional Delaunay tessellation with application to Voronoi polytopes*, The Computer Journal, 24(2), pp. 167–172, 1981.
3. L. J. Guibas, J. Stolfi, *Primitives for the Manipulation of General Subdivisions and the Computation of Voronoi Diagrams*, ACM Transactions on Graphics, 4(2), pp. 74–123, 1985.
4. O. Devillers, *On Deletion in Delaunay Triangulations*, International Journal of Computational Geometry & Applications, 12(3), pp. 193–205, 2002.
5. E. P. Mücke, I. Saias, B. Zhu, *Fast randomized point location without preprocessing in two- and three-dimensional Delaunay triangulations*, Computational Geometry, 12(1–2), pp. 63–83, 1999.
6. Wikipedia, [*Delaunay triangulation*](https://en.wikipedia.org/wiki/Delaunay_triangulation).

## 💖 [Embarcadero](https://www.embarcadero.com/jp/) [**Delphi**](https://www.embarcadero.com/jp/products/delphi)
ネイティブなクロスプラットフォームアプリを開発するための統合開発環境（ＩＤＥ）。
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/jp/products/delphi/starter)
