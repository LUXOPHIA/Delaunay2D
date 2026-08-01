# LUX.CG2D

[English](../README.md) | [日本語](README.md)

Skia レンダリングエンジンをベースとした、Delphi 用の保持モード（retained-mode）２Ｄグラフィックスライブラリ。描画プリミティブはシーン木に繋がれたオブジェクトであり、各ノードは 3×3 の同次変換行列と継承可能な描画スタイルを持つ。シーンはカメラノードを通してラスタライズされ、変化のたびに自動で再描画する FireMonkey フレームへ描かれる。

## 利用ライブラリ

* [**LUX**](https://github.com/LUXOPHIA/LUX) ：ベクトル・行列・デリゲート・木層 `LUX.Data.Tree` を提供する基底ライブラリ。

## 1. 概要

`LUX.CG2D` が提供するのは即時モードの描画 API ではなく *シーングラフ* である。アプリケーションは図形オブジェクトの永続的な木を構築して書き換えるだけであり、いつどのように再描画するかはライブラリが決める。

| ユニット | 内容 |
|:---|:---|
| `LUX.CG2D.pas` | コア：`TCGStyle`, `TCGObject`, `TCGShaper`, `TCGCamera`, `TCGLayer`, `TCGLayers` |
| `LUX.CG2D.Shapers.pas` | プリミティブ：`TCGCirc`, `TCGTria`, `TCGLine`, `TCGPlots` |
| `LUX.CG2D.Viewer.pas` / `.fmx` | `TCGViewer`：カメラ1台を描く FireMonkey の `TFrame` |

以下の性質はコードによって保証されている。

1. **木の意味論は委譲される。** ノードの生成・移籍・部分木ごとの解放・循環の禁止・子型の検査は、すべて `LUX.Data.Tree` が担う。`TCGObject` は `TTreeKnot<TCGObject,TCGObject>` の派生、`TCGLayers` は `TTreeRoot<TCGLayer>` の派生であり、違反は `ETreeError` となる。
2. **階層は型で制約される。** `TCGLayers` は `TCGLayer` だけを子として受け入れ、`TCGObject.AcceptChildr` は `TCGLayer` を拒否する（レイヤはルート直下専用）。また `TCGLayers` はどのノードの子にもなれない。
3. **スタイルは継承される。** `TCGObject.Style` は自分が所有していなければ親を遡って解決される。`TCGLayer` はコンストラクタで既定の `TCGStyle` を強制生成するため、シーンに属す限り遡りは必ず終端する。代入されたスタイルはノードの *所有物* であり破棄時に解放されるので、ひとつのスタイルを複数ノードで共有してはならない（共有したい場合は共通の先祖に代入して継承させる）。
4. **ペイントはキャッシュされる。** `TCGStyle` は `ISkPaint` を遅延生成し、属性が変わったときにだけ破棄する。ひとつの Skia ペイントで塗りと線を異なる色にはできないため、図形は `PaintFill` と `PaintLine` で2回描かれる。完全に透明な色では `nil` が返り、その走査は省かれる。
5. **変更はルートへ伝わる。** ノードの挿抜・行列の代入・スタイル属性の変更は、すべて `Changed` としてルートの `TCGLayers` へ遡り、`OnChange`（`TDelegates`）で多播される。`TCGCamera` は属すシーンの `OnChange` を購読して `OnScene` として転送するため、ビューアはカメラだけを受け取ればよい。大量の変更は `BeginUpdate` / `EndUpdate` で束ねられ、部分木の発火を止めて最外殻の `EndUpdate` で1回だけ発火する。破棄中のノードは更新中扱いであり通知しない。

描画は RTL の `System.Skia` / `FMX.Skia` ユニットが公開する Skia キャンバス、すなわち Skia4Delphi の同梱版 [1][2] を通して行われる。`TCGViewer.Paint` は `GlobalUseSkia = True` を前提とし [3]、FireMonkey のキャンバスが `TSkCanvasCustom` でない場合は何も描かずに戻る。

## 2. 数学的背景

### 2.1 同次変換

ノードの姿勢は、列ベクトルに作用する 3×3 同次行列（`TSingleM3`）として保持される２Ｄアフィン変換である。

```math
p' = M\,p, \qquad
M = \begin{pmatrix}
m_{11} & m_{12} & m_{13} \\
m_{21} & m_{22} & m_{23} \\
0 & 0 & 1
\end{pmatrix}, \qquad
p = \begin{pmatrix} x \\ y \\ 1 \end{pmatrix}
\tag{1}
```

第1・第2列は局所基底ベクトルの像（`AxisX`, `AxisY`）、第3列は局所原点の像（`AxisP`）、すなわち平行移動成分である。FireMonkey の `TMatrix` は行ベクトルに作用するため、`TSingleM3` ⇄ `TMatrix` の型変換は転置となる。

```math
M_{\mathrm{FMX}} = M^{\mathsf T}, \qquad p'^{\mathsf T} = p^{\mathsf T} M_{\mathrm{FMX}}
\tag{2}
```

`TSingleM3` は `Single` からの暗黙変換を持つため、姿勢へスカラー `1` を代入すると恒等行列になる。

### 2.2 姿勢の合成

`LocalPose` は自ノード座標系を親ノード座標系へ写す。`GlobalPose` はルートへの経路に沿った積である。

```math
M^{\mathrm{g}}_{k} = M^{\mathrm{g}}_{\pi(k)}\, M^{\mathrm{l}}_{k}
= \prod_{j \in \mathrm{path}(k)} M^{\mathrm{l}}_{j}
\tag{3}
```

ここで $\pi(k)$ はノード $k$ の親である。`TCGLayers` は行列を持たないため `TCGLayer.GlobalPose` は自身の `LocalPose` を返し、再帰はレイヤで止まる。すなわちレイヤがシーンの最上位の座標系となる。`GlobalPose` への代入は (3) の逆である。

```math
M^{\mathrm{l}}_{k} = \bigl( M^{\mathrm{g}}_{\pi(k)} \bigr)^{-1} M^{\mathrm{g}}_{k}
\tag{4}
```

行列の実体を持つのは `TCGShaper` だけである。`TCGObject.GetLocalPose` は恒等行列を返し、セッタは何もしないため、変換を要さないノード（`TCGCamera` を含む）は費用ゼロであり、その姿勢は先祖の姿勢のみで決まる。

### 2.3 走査とキャンバスの行列スタック

`TCGObject.Draw` は局所行列を Skia の行列スタック [4] に積んで再帰する。

```
//// Draw — シーングラフを Skia キャンバスへ載せる連鎖（ノード毎に1本）

・TCGObject.Draw
  ┣・Save                ･･･ キャンバスの行列スタックへ退避する
  ┣・Concat( LocalPose ) ･･･ 自ノードの行列をスタックへ積む
  ┣・DrawMain            ･･･ 式 (5) の C_k のもとで自分を描く
  ┣・child.Draw          ･･･ × N  再帰：各々の子が同じ連鎖を繰り返す
  ┃  ┣・Save
  ┃  ┣・Concat( LocalPose )
  ┃  ┣・DrawMain
  ┃  ┣・child.Draw      ･･･ × N  任意の深さに入れ子となる
  ┃  ┗・Restore
  ┗・Restore             ･･･ キャンバスの行列スタックを復帰する
```

したがってノード $k$ が自分を描く時点で有効な変換は

```math
C_k = D\,V\,M^{\mathrm{g}}_{k}
\tag{5}
```

であり、$V$ と $D$ は §2.4 のビュー変換とデバイス変換である。描画時に `GlobalPose` を評価する必要はなく、スタックがそれを蓄積する。

### 2.4 カメラとビューポートへの収め方

`TCGCamera.Render` はカメラの大域行列の逆行列を前置し、ワールド座標系をカメラ座標系へ写す。

```math
V = \bigl( M^{\mathrm{g}}_{\mathrm{cam}} \bigr)^{-1}
\tag{6}
```

`TCGViewer.Paint` はカメラ原点をコントロールの中央に置き、視野 $S_x \times S_y$（`SizeX`, `SizeY`）が $W \times H$ のコントロールにぴったり収まる等方スケールを適用する。

```math
s = \min\!\left( \frac{W}{S_x}, \frac{H}{S_y} \right), \qquad
D = T\!\left( \frac{W}{2}, \frac{H}{2} \right) S(s,s)
\tag{7}
```

$s$ が最小値であるため、可視領域が視野より狭くなることはなく、コントロールの長い辺の方向へ広がる。

```math
\left( W_{\mathrm{view}}, H_{\mathrm{view}} \right) = \left( \frac{W}{s}, \frac{H}{s} \right) \ \ge\ \left( S_x, S_y \right)
\tag{8}
```

ゆえに $2 \times 2$ の視野を 3:2 のコントロールに映すと、水平は $-1.5 \ldots +1.5$、垂直は $-1 \ldots +1$ を覆う。

## 3. アーキテクチャ

### 3.1 クラス

```
・TCGStyle           ･･･ FillColor/LineColor/… → PaintFill/PaintLine

・TTreeRoot<TCGLayer>
  ┗・TCGLayers      ･･･ シーンのルート：BackColor, OnChange, Render

・TTreeKnot<TCGObject,TCGObject>
  ┗・TCGObject      ･･･ LocalPose/GlobalPose :TSingleM3, Style :TCGStyle, Draw
     ┣・TCGLayer    ･･･ 最上位の座標系。既定の TCGStyle を所有する
     ┣・TCGCamera   ･･･ SizeX / SizeY, OnScene :TDelegates, Render
     ┗・TCGShaper   ･･･ _LocalPose を保持する唯一のノード
        ┣・TCGCirc  ･･･ Pos, Radius
        ┣・TCGTria  ･･･ Vert1, Vert2, Vert3
        ┣・TCGLine  ･･･ Pos1, Pos2
        ┗・TCGPlots ･･･ Poins :TArray<TPointF>  （Skia の点群として描画）

・TFrame  (FMX)
  ┗・TCGViewer      ･･･ Camera :TCGCamera; Paint → ISkCanvas
```

### 3.2 シーン木

```
・TCGLayers           ･･･ ルート — TCGObject ではなく、行列もスタイルも持たない
  ┗・TCGLayer        ･･･ × N  ここにはレイヤだけが入る
     ┗・TCGObject    ･･･ × N  レイヤ以外の TCGObject（TCGShaper, …）
        ┗・TCGObject ･･･ × N  任意の深さに入れ子にできる
```

### 3.3 ファイル

```
・LUX.CG2D/
  ┣・LUX.CG2D.pas         ･･･ スタイル・ノード・図形・カメラ・レイヤ・ルート
  ┣・LUX.CG2D.Shapers.pas ･･･ 図形プリミティブ（各々が DrawMain を上書き）
  ┣・LUX.CG2D.Viewer.pas  ･･･ TCGViewer（TCGCamera.OnScene を購読）
  ┗・LUX.CG2D.Viewer.fmx  ･･･ フレームのリソース（既定 400 × 300）
```

本ライブラリは `TSingle2D`・`TSingleM3`・`TDelegates` および木層のために LUX 基底ライブラリに依存する。

## 4. 使い方

プログラムの初期化時に `GlobalUseSkia := True` を設定しておく必要がある [3]。

```pascal
uses System.UITypes,
     LUX, LUX.D2, LUX.D3x3,
     LUX.CG2D, LUX.CG2D.Shapers;

var
   Layers :TCGLayers;
   Layer  :TCGLayer;
   Pivot  :TCGShaper;
   Camera :TCGCamera;
   Circ   :TCGCirc;
   Line   :TCGLine;
begin
     Layers           := TCGLayers.Create;
     Layers.BackColor := TAlphaColorF.Create( 1, 1, 1, 1 );

     Layer := TCGLayer.Create( Layers );                 // ルート直下にはレイヤだけ

     with Layer.Style do                                 // 部分木の全体へ継承される
     begin
          FillColor := TAlphaColors.Orange;
          LineColor := TAlphaColors.Black;
          LineThick := 0.02;
     end;

     Circ        := TCGCirc.Create( Layer );
     Circ.Pos    := TSingle2D.Create( 0.3, 0 );          // LocalPose の平行移動成分
     Circ.Radius := 0.2;

     Line      := TCGLine.Create( Layer );
     Line.Pos1 := TSingle2D.Create( -1, 0 );
     Line.Pos2 := TSingle2D.Create( +1, 0 );

     Pivot           := TCGShaper.Create( Layer );       // カメラは行列を持たないので、
     Pivot.LocalPose := TSingleM3.Translate( 0.5, 0 );   // 親ノードで位置を与える
     Camera          := TCGCamera.Create( Pivot );
     Camera.SizeX    := 2;                               // 視野（ワールド単位）
     Camera.SizeY    := 2;

     CGViewer1.Camera := Camera;                         // シーンの変化ごとに再描画される

     Layer.BeginUpdate;                                  // 通知を1回に束ねる
     try
          Circ.Radius := 0.25;
          Circ.Pos    := TSingle2D.Create( 0.4, 0.1 );
     finally
          Layer.EndUpdate;
     end;

     CGViewer1.Camera := nil;                            // 解放前に購読を外す
     Layers.Free;                                        // シーン全体を解放する
end;
```

## 5. 参考文献

1. Skia4Delphi, [*skia4delphi — Cross-platform 2D graphics API for Delphi based on Google's Skia*](https://github.com/skia4delphi/skia4delphi).
2. Google, [*Skia Graphics Library*](https://skia.org/).
3. Embarcadero, [*Skia4Delphi — RAD Studio*](https://docwiki.embarcadero.com/RADStudio/en/Skia4Delphi).
4. Google, [*SkCanvas Overview*](https://skia.org/docs/user/api/skcanvas_overview/).

## 💖 [Embarcadero](https://www.embarcadero.com/jp/) [**Delphi**](https://www.embarcadero.com/jp/products/delphi)
ネイティブなクロスプラットフォームアプリを開発するための統合開発環境（ＩＤＥ）。
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/jp/products/delphi/starter)
