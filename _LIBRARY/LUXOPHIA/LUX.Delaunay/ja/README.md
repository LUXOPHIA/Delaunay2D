# LUX.Delaunay
[English](../README.md) | [日本語](README.md)

Delphi 用のドロネー複体ライブラリ。ユークリッド平面の三角形分割、ユークリッド３次元空間の四面体分割、および平坦トーラスの三角形分割を提供します。いずれの図もサイトの追加**と**削除をいつでも受け付け、どの操作の後も正しいドロネー複体であり続けます。[MIT License](../LICENSE) で公開しています。

## 利用ライブラリ

* [**LUX**](https://github.com/LUXOPHIA/LUX) ：ベクトル型（`LUX.D2` … `LUX.D4`）・デリゲート・リスト・TriFlip / TetraFlip メッシュモデル（`LUX.Data.Model.*`）を提供する基盤ライブラリ。
* [**LUX.CG2D**](https://github.com/LUXOPHIA/LUX.CG2D) ：2D ビューアのみが使う Skia4Delphi 上の 2D シーングラフ。

## 1. 概要

本ライブラリは３つの独立したモデルからなり、それぞれに貼るだけで使える FireMonkey ビューアフレームが付属します。

| パッケージ | 領域 | モデルクラス | 胞 |
|---|---|---|---|
| [`LUX.Delaunay.D2`](../D2/ja/README.md) | ユークリッド平面 $\mathbb{E}^2$ | `TDelaunay2D` | 三角形（`TDelaFace2D`） |
| [`LUX.Delaunay.D2.Periodic`](../D2/Periodic/ja/README.md) | 平坦トーラス $\mathbb{T}^2 = \mathbb{R}^2 / L\mathbb{Z}^2$ | `TPeriDelaunay2D` | 三角形（`TPeriFace2D`） |
| [`LUX.Delaunay.D3`](../D3/ja/README.md) | ユークリッド３次元空間 $\mathbb{E}^3$ | `TDelaunay3D` | 四面体（`TDelaCell3D`） |

３つのモデルに共通する性質は次の通りです。

- **完全に動的。** `AddPoin` は Bowyer–Watson のキャビティ構成 [1][2] でサイトを追加し、`DeletePoin` は星を取り除いた上でリンク頂点から穴を決定論的に再分割して削除します [8]。どちらもフリップの探索を含みません。
- **失敗の全面的な規約。** 退化した入力が構造を壊すことはありません。`AddPoin` は `nil` を返し、`DeletePoin` は何も変えずに `False` を返します。
- **ただ一つの述語。** 内接円・内接球の判定、向きの判定、歩行方向の判定は、すべて単一のリフト行列式（§2.2）として評価されます。したがってコードには胞の種類による場合分けが存在しません。
- **多播の変更通知。** `OnChange :TDelegates` が構造の変化ごとに発火します。ビューアはこれを購読し、シーンを自動的に再構築します。

さらに２つのユークリッドモデルは、スーパーシンプレックスの代わりに**無限遠頂点**によるコンパクト化（§2.3）を用い、外心を**同次座標**（§2.4）で公開します。これにより半直線を含むボロノイ図の全体が、分岐のない一つの式から得られます。周期モデルは代わりに、商空間上の**最小表現**（§2.5）を保ち、述語を**厳密な整数演算**で評価します。

## 2. 数学的背景

### 2.1 ドロネー複体

$P \subset \mathbb{R}^d$ を有限集合とします。$P$ に頂点を持つ $d$ 単体 $\sigma$ がドロネー複体 $\mathrm{Del}(P)$ に属するのは、その外接開球が $P$ の点を一つも含まないとき、かつそのときに限ります。

```math
\sigma = \{p_0,\dots,p_d\} \in \mathrm{Del}(P)
\iff
\exists\, B \text{ 開球}: \partial B \supset \sigma \;\wedge\; B \cap P = \varnothing
\qquad \text{(2.1)}
```

$\mathrm{Del}(P)$ はボロノイ図 $\mathrm{Vor}(P)$ の幾何的双対です。$\mathrm{Del}(P)$ の $k$ 面は $\mathrm{Vor}(P)$ の $(d-k)$ 面に対応し、$d$ 単体の外心はボロノイ頂点になります [10]。

### 2.2 リフト写像と統一述語

$\ell : \mathbb{R}^d \to \mathbb{R}^{d+1}$ を標準的な放物面へのリフト写像とします。

```math
\ell(p) = \bigl(p,\; \lVert p \rVert^2 \bigr) .
\qquad \text{(2.2)}
```

$\mathbb{R}^d$ の球は、放物面とアフィン超平面の交わりの鉛直射影であり、$q$ がその球の内側にあるのは $\ell(q)$ が超平面の真下にあるとき、かつそのときに限ります。したがって $\mathrm{Del}(P)$ は $\ell(P)$ の下側凸包の鉛直射影です [4][6]。

本ライブラリは (2.1) をリフト座標で直接評価します。その際、判定点 $q$ へ平行移動してから評価するため、絶対座標のまま評価される式は存在しません。

```math
\mathrm{Lift}(p; q) = \bigl(\, p - q,\; \lVert p - q \rVert^2 \,\bigr) \in \mathbb{R}^{d+1},
\qquad
\mathrm{InBall}(p_0,\dots,p_d;\, q) = \det \begin{pmatrix} \mathrm{Lift}(p_0;q) \\ \vdots \\ \mathrm{Lift}(p_d;q) \end{pmatrix}
\qquad \text{(2.3)}
```

正の向きの単体では、$\mathrm{InBall} > 0$ が「$q$ は外接球の内側」を意味します。行列式は平行移動の後に `Double` で累算されます。これが、原点から遠く離れたデータでも述語が使える理由です [5]。

### 2.3 無限遠頂点

ユークリッドモデルは特別な頂点 $\infty$ を一つだけ加え、凸包の外側をそれを含む胞で覆います。これによりどの facet にもちょうど２つの胞が接し、境界の場合分けが存在しなくなります。組合せ的にはこれは一点コンパクト化であり、$n$ サイトの図は $n+1$ 頂点をもつ $S^d$ の三角形分割になります。平面ではオイラーの公式によって大きさが厳密に決まります。

```math
V = n+1, \quad E = 3n-3, \quad F = 2n-2 \qquad (n \ge 3),
\qquad \text{(2.4)}
```

ここで $F$ は無限遠面を含みます。

無限遠頂点は、自分のリフトを差し替えることで実現されます。

```math
\mathrm{Lift}(\infty; q) = (0,\dots,0,1),
\qquad \text{(2.5)}
```

これは放物面の軸方向に沿った $\ell$ の極限方向です。(2.5) を (2.3) へ代入すると、その行に沿った余因子展開によって行列式が退化し、残る $d$ 頂点の $q$ に対する向きの行列式になります。すなわち $\infty$ を通る球は超平面 ―― 半径無限大の球 ―― であり、内外判定は自動的に半空間判定へ退化します。`TDelaPoin2DInf` / `TDelaPoin3DInf` はこの代入を `Lift` の多態でおこなうため、述語にフラグの分岐は存在しません。

### 2.4 同次外心

胞の基準頂点 $B$ を固定し、$L_i = \mathrm{Lift}(p_i;B)$、同次成分を有限頂点で $w_i = 1$、$\infty$ で $w_i = 0$ とします。リフトの同次座標を $(X_1,\dots,X_d, Z, W)$ と書くと、$d+1$ 個のリフト点を通る超平面は

```math
a_1 X_1 + \cdots + a_d X_d + c\,Z + e\,W = 0
\qquad \text{(2.6)}
```

であり、その係数は $(d+1) \times (d+2)$ 行列 $[\,L_i \mid w_i\,]$ の符号付き小行列式です。(2.6) と $Z = \lVert X \rVert^2$ の交わりは中心 $-a/(2c)$ の球なので、モデルは外心を同次形

```math
\mathrm{Circum} = (\,-a_1,\; \dots,\; -a_d,\; 2c\,)
\qquad \text{(2.7)}
```

で返します。同次成分が消える $2c = 0$ となるのは、超平面が鉛直のとき、すなわち胞が $\infty$ を含むときに限ります。そのとき $(-a_1,\dots,-a_d)$ は、凸包 facet に双対な非有界ボロノイ辺の外向きの方向です。有界な辺と非有界な辺が同じ式から得られ、分岐も除算も要りません。

### 2.5 周期の場合

平坦トーラス $\mathbb{T}^2 = \mathbb{R}^2/L\mathbb{Z}^2$ では、入力は格子周期的な無限点集合 $P + L\mathbb{Z}^2$ であり、ドロネー三角形分割は普遍被覆で取ってから射影します。$\chi(\mathbb{T}^2) = 0$ なので、$n$ サイトの商複体は**すべての** $n \ge 1$ に対して

```math
V = n, \quad E = 3n, \quad F = 2n
\qquad \text{(2.8)}
```

をみたします。`TPeriDelaunay2D` はこの最小表現そのものを保持します。ゴースト点を複製することも、$3 \times 3$ の被覆空間へ領域を拡張することもありません [7]。射影は一般に単体的複体ではなく $\Delta$ 複体にしかなりません ―― 一つの面が、異なる格子オフセットのもとで同じ頂点の実体を２つまたは３つの角で参照し得ます ―― が、本モデルはその場合を避けるのではなく直接扱うように作られています [9]。オフセットの管理、厳密整数述語、記号摂動については [`D2/Periodic/ja/README.md`](../D2/Periodic/ja/README.md) を参照してください。

### 2.6 クエリ

点の位置検索は*ジャンプ＆ウォーク* [6] です。$m = n^{1/(d+1)}$ 個のサイトを無作為に引き、最も近いもののアンカー胞から出発し、判定点の側へ facet を越え続けます。期待計算量は $O(n^{1/(d+1)})$、すなわち平面で $O(n^{1/3})$、空間で $O(n^{1/4})$ であり、標本をクエリごとに引き直すため領域全体で一様です。`FindNearPoin` は着地した胞から始め、ドロネー辺を伝って貪欲に降下します。各段で距離が厳密に縮むため、判定点をボロノイ領域に含むサイトで必ず停止します。

## 3. アーキテクチャ

### 3.1 パッケージ構成

```
基盤ライブラリ

・LUX
  ┣・LUX.D2 / LUX.D3 / LUX.D4   ･･･ ベクトル
  ┣・LUX.Data.Model.TriFlip.*   ･･･ 2D メッシュ
  ┗・LUX.Data.Model.TetraFlip.* ･･･ 3D メッシュ

LUX 上に構築されるパッケージ（各モデルパッケージと、そのビューア）

・LUX.Delaunay.D2                ･･･ ∞ 頂点・E²
  ┣・TDelaunay2D
  ┣・TDelaPoin2D
  ┣・TDelaPoin2DInf
  ┣・TDelaFace2D
  ┗・LUX.Delaunay.D2.Viewer
     ┗・TDelaunayViewer         ･･･ (LUX.CG2D / Skia)

・LUX.Delaunay.D2.Periodic       ･･･ トーラス・最小表現・T²
  ┣・TPeriDelaunay2D
  ┣・TPeriPoin2D
  ┣・TPeriFace2D
  ┗・LUX.Delaunay.D2.Periodic.Viewer
     ┗・TPeriDelaunayViewer     ･･･ (LUX.CG2D / Skia)

・LUX.Delaunay.D3                ･･･ ∞ 頂点・E³
  ┣・TDelaunay3D
  ┣・TDelaPoin3D
  ┣・TDelaPoin3DInf
  ┣・TDelaCell3D
  ┗・LUX.Delaunay.D3.Viewer
     ┗・TDelaunayViewer         ･･･ (FMX TViewport3D)
```

`TDelaunay2D` と `TPeriDelaunay2D` はいずれも [LUX](https://github.com/LUXOPHIA/LUX) の TriFlip 三角形メッシュ層の派生、`TDelaunay3D` は TetraFlip 四面体メッシュ層の派生です。これらの層が点と胞の所有・接続構造（`Poin` / `Face` または `Cell` / `Corn` / `Bond`）・角の巡回表・facet の縫合・列挙を担い、各 `LUX.Delaunay.*` ユニットはドロネー固有の機能だけを加えます。

### 3.2 ファイル構成

```
・LUX.Delaunay/
  ┣・README.md                                       ･･･ 英語版
  ┣・ja/README.md                                    ･･･ 本ドキュメント
  ┣・LICENSE                                         ･･･ MIT
  ┣・D2/                                             ･･･ 2D ユークリッド平面
  ┃  ┣・LUX.Delaunay.D2.pas                         ･･･ TDelaunay2D ― E²
  ┃  ┣・LUX.Delaunay.D2.Viewer.pas / .fmx           ･･･ TDelaunayViewer (Skia)
  ┃  ┣・README.md , ja/README.md                    ･･･ パッケージの文書
  ┃  ┗・Periodic/                                   ･･･ 2D 平坦トーラス
  ┃     ┣・LUX.Delaunay.D2.Periodic.pas             ･･･ TPeriDelaunay2D ― T²
  ┃     ┣・LUX.Delaunay.D2.Periodic.Viewer.pas/.fmx ･･･ TPeriDelaunayViewer
  ┃     ┗・README.md , ja/README.md                 ･･･ パッケージの文書
  ┗・D3/                                             ･･･ 3D ユークリッド空間
     ┣・LUX.Delaunay.D3.pas                          ･･･ TDelaunay3D ― E³
     ┣・LUX.Delaunay.D3.Viewer.pas / .fmx            ･･･ TDelaunayViewer (FMX)
     ┗・README.md , ja/README.md                     ･･･ パッケージの文書
```

### 3.3 依存関係

- [LUX](https://github.com/LUXOPHIA/LUX) ― 基盤ライブラリ。ベクトル型（`LUX.D2` … `LUX.D4`）、デリゲート、リスト、TriFlip / TetraFlip メッシュモデル（`LUX.Data.Model.*`）。
- [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) ― Skia4Delphi 上の 2D シーングラフ。**2D ビューア**のみが必要とします。
- FireMonkey を含む Delphi。モデルのユニットは純粋な Object Pascal です。2D ビューアは Skia 対応の FMX キャンバス、3D ビューアは標準の `TViewport3D` を使います。

完全な対話的アプリケーションは [Delaunay2D](https://github.com/LUXOPHIA/Delaunay2D) と [Delaunay3D](https://github.com/LUXOPHIA/Delaunay3D) にあります。いずれも `git subtree` で `_LIBRARY\LUXOPHIA\` 以下にライブラリをベンダリングしています。

## 4. 使い方

### 4.1 平面

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

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), P ) < 10       // 最近傍サイトと、そこまでの距離
     then D.DeletePoin( P );                                     // 削除

     for F in D.Faces do                                         // 三角形を列挙
     begin
          if F.InfCorn = 0 then { F.Poin[1] … F.Poin[3] が有限の三角形 };
     end;

     D.Free;
end;
```

### 4.2 トーラス

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2.Periodic;

var
   D :TPeriDelaunay2D;
   F :TPeriFace2D;
   N :Integer;
begin
     D := TPeriDelaunay2D.Create;

     D.Size := 300;                                              // 基本領域 [0,300)²

     for N := 1 to 100 do                                        // 追加（領域内へ巻き込まれる）
     begin
          D.AddPoin( TSingle2D.Create( 300 * Random, 300 * Random ) );
     end;

     for F in D.Faces do                                         // 面は常にちょうど 2n 枚
     begin
          { F.CornPos( 1 ) … F.CornPos( 3 ) が、その面自身のリフト上の三角形 };
     end;

     D.Free;
end;
```

### 4.3 空間

```pascal
uses LUX, LUX.D3, LUX.D4, LUX.Delaunay.D3;

var
   D :TDelaunay3D;
   P :TDelaPoin3D;
   C :TDelaCell3D;
   N :Integer;
begin
     D := TDelaunay3D.Create;

     for N := 1 to 100 do D.AddPoin( TSingle3D.RandG );          // 追加

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1     // 最近傍サイトと、そこまでの距離
     then D.DeletePoin( P );                                      // 削除

     for C in D.Cells do                                          // 四面体を列挙
     begin
          if C.InfCorn < 0 then { C.Poin[0] … C.Poin[3] が有限の四面体 };
     end;

     D.Free;
end;
```

## 5. 参考文献

1. Bowyer, A., [*Computing Dirichlet tessellations*](https://doi.org/10.1093/comjnl/24.2.162), The Computer Journal, 24(2), 162–166, 1981.
2. Watson, D. F., [*Computing the n-dimensional Delaunay tessellation with application to Voronoi polytopes*](https://doi.org/10.1093/comjnl/24.2.167), The Computer Journal, 24(2), 167–172, 1981.
3. Delaunay, B., [*Sur la sphère vide*](https://www.mathnet.ru/eng/im4937), Bulletin de l'Académie des Sciences de l'URSS, 6, 793–800, 1934.
4. Brown, K. Q., [*Voronoi diagrams from convex hulls*](https://doi.org/10.1016/0020-0190(79)90074-7), Information Processing Letters, 9(5), 223–228, 1979.
5. Shewchuk, J. R., [*Adaptive precision floating-point arithmetic and fast robust geometric predicates*](https://doi.org/10.1007/PL00009321), Discrete & Computational Geometry, 18(3), 305–363, 1997.
6. Mücke, E. P., Saias, I., Zhu, B., [*Fast randomized point location without preprocessing in two- and three-dimensional Delaunay triangulations*](https://doi.org/10.1016/S0925-7721(98)00035-2), Computational Geometry, 12(1–2), 63–83, 1999.
7. Caroli, M., Teillaud, M., [*Computing 3D periodic triangulations*](https://doi.org/10.1007/978-3-642-04128-0_6), ESA 2009, LNCS 5757, 59–70, 2009.
8. Devillers, O., [*On deletion in Delaunay triangulations*](https://doi.org/10.1142/S0218195902000815), International Journal of Computational Geometry & Applications, 12(3), 193–205, 2002.
9. Osang, G., Rouxel-Labbé, M., Teillaud, M., [*Generalizing CGAL periodic Delaunay triangulations*](https://doi.org/10.4230/LIPIcs.ESA.2020.75), ESA 2020, LIPIcs 173, 75:1–75:17, 2020.
10. Edelsbrunner, H., Seidel, R., [*Voronoi diagrams and arrangements*](https://doi.org/10.1007/BF02187681), Discrete & Computational Geometry, 1(1), 25–44, 1986.

## 💖 [Embarcadero](https://www.embarcadero.com/jp/) [**Delphi**](https://www.embarcadero.com/jp/products/delphi)
ネイティブなクロスプラットフォームアプリを開発するための統合開発環境（ＩＤＥ）。
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/jp/products/delphi/starter)
