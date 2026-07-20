# LUX.Delaunay.D2

**Delphi 用 2D ドロネー三角形分割** — 三角形メッシュ上での逐次的な点の追加と削除、および Skia ベースの FMX ビューアフレーム。

[English](../README.md) | [日本語](README.md)

ドロネー図は、辺で貼り合わされた三角形（*面*）の集合です。凸包の外側は、ただ一つの *無限遠頂点* を含む面で覆われるため、どの辺にも常にちょうど2つの面が接し、すべてのアルゴリズムが境界の場合分けなしに動きます。面の中の頂点番号は **1..3**（反時計回り）です。

---

## クラス — `LUX.Delaunay.D2`

[LUX](https://github.com/LUXOPHIA/LUX) の TriFlip メッシュ層（`LUX.Data.Model.TriFlip.*`）が接続・所有・列挙を担い、`LUX.Delaunay.D2` はドロネー固有の機能だけを加えます。

### `TDelaPoin2D` — 頂点

| メンバ | 説明 |
|---|---|
| `Pos :TSingle2D` | 座標。*(継承)* |
| `Face :TDelaFace2D` / `Corn :Byte` | アンカー: この頂点を含む面の一つと、その中での角番号。*(継承)* |
| `Inf :Boolean` | 無限遠頂点かどうか。 |
| `Lift( Pos_ ) :TSingle3D` | 基準点 `Pos_` から見たリフト座標 `( X, Y, X²+Y² )`。 |
| `InCircled( P1_,P2_,P3_ ) :Single` | 円 `( P1, P2, P3 )` に対する自分の内外の符号 — 正 = 内側。 |

### `TDelaPoin2DInf` — 無限遠頂点

`TDelaPoin2D` の派生。`Lift`（常に `( 0, 0, 1 )`）と `InCircled`（円の向きへの退化）を多態で差し替えます。図につき唯一のインスタンス（`TDelaunay2D.PoinInf`）で、点集合には属さず `Poins` にも現れません。

### `TDelaFace2D` — 三角形

| メンバ | 説明 |
|---|---|
| `Poin[1..3] :TDelaPoin2D` | 頂点（反時計回り）。*(継承)* |
| `Face[1..3] :TDelaFace2D` | 頂点 `K` の対辺で接する隣接面。*(継承)* |
| `Corn[1..3] :Byte` | 隣接面から見た、共有辺の対頂点の番号。*(継承)* |
| `InfCorn :Byte` | 無限遠頂点の角番号 — `0` は有限面。 |
| `Circum :TSingle3D` | 同次外心 `( X, Y, W )`。有限面 → 外心は `( X/W, Y/W )`。無限遠面 → `W = 0` で `( X, Y )` が双対ボロノイ辺の外向きの方向。 |
| `InCircle( P1_,P2_,P3_, Pos_ ) :Single` *(class)* | 統一リフト行列式 — 正 = `Pos_` が円 `( P1, P2, P3 )` の内側。 |
| `IsHitCircle( Pos_ ) :Boolean` | `Pos_` がこの面の外接円の内側にあるか。 |

### `TDelaPoinSet2D` / `TDelaFaceSet2D` — 集合

列挙可能なコンテナ（`for P in …`・`Count`・`[I]`）。`TDelaFaceSet2D.Poins` は **有限の** 頂点だけを見せます。

### `TDelaunay2D` — ドロネー図

| メンバ | 説明 |
|---|---|
| `Create` / `Destroy` | 空の図。点集合と無限遠頂点を所有します。 |
| `PoinInf :TDelaPoin2D` | 唯一の無限遠頂点。 |
| `Faces :TDelaFaceSet2D` | 無限遠面を含む全ての面（自分自身の別名）。 |
| `Poins :TDelaPoinSet2D` | 全ての有限頂点。 |
| `OnChange :TDelegates` | 構造が変化するたびに発火する多播通知。`Add` で購読、`Del` で解除。 |
| `HitCircleFace( Pos_ ) :TDelaFace2D` | `Pos_` を外接円に含む面 — ジャンプ＆ウォーク、期待 O(n^1/3)。 |
| `FindPoin( Pos_, Radius_ ) :TDelaPoin2D` | `Radius_` 以内の最近傍頂点。無ければ `nil`。 |
| `AddPoin( Pos_ ) :TDelaPoin2D` | 点の追加（Bowyer–Watson 法）。所属面が既知ならオーバーロード `AddPoin( Pos_, Face_ )` で検索を省けます。 |
| `DeletePoin( Poin_ ) :Boolean` | 頂点の削除（フリップ法）。不正な入力（`nil`・無限遠頂点・他の図の頂点）は `False`。 |
| `Clear` | 全ての点と面を消去します（`PoinInf` は残ります）。 |

---

## クラス — `LUX.Delaunay.D2.Viewer`

`TDelaunay2D` を [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) のシーングラフ（Skia4Delphi）で描画する `TFrame`。`OnChange` を購読し、シーンを自動的に（次の描画まで遅延して）再構築します。

### `TDelaunayViewer` — フレーム

| メンバ | 説明 |
|---|---|
| `Delaunay :TDelaunay2D` | 表示する図。代入で `OnChange` を購読します。`nil` の代入で解除（図を解放する前に行うこと）。 |
| `Camera :TCGCamera` | 視点。`SizeX` / `SizeY` がモデル座標での視野の広さです。 |
| `Poins` / `Trias` / `Circs` / `Volos` | シーンのレイヤ（下記）。 |
| `ScrToPos( S_ ) :TSingle2D` / `PosToScr( P_ ) :TPointF` | スクリーン座標とモデル座標の相互変換。 |

### レイヤ

各レイヤは `Style`（`FillColor` / `LineColor` / `LineThick`）を持つ `TCGLayer` です。スタイルの変更は自動的に再描画されます。

| レイヤ | 表示内容 |
|---|---|
| `TDelaunayTrias` | ドロネー三角形。 |
| `TDelaunayCircs` | 外接円。 |
| `TDelaunayVolos` | ボロノイ図（非有界の辺は外向きの半直線）。 |
| `TDelaunayPoins` | 頂点（`Radius` はモデル座標での半径）。 |

---

## 使い方

### 構築とクエリ

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2;

var
   D :TDelaunay2D;
   P :TDelaPoin2D;
   F :TDelaFace2D;
   N :Integer;
begin
     D := TDelaunay2D.Create;

     for N := 1 to 100 do D.AddPoin( 100 * TSingle2D.RandG );  // 追加

     for F in D.Faces do                                       // 三角形を列挙
     begin
          if F.InfCorn = 0 then { F.Poin[1..3] が有限の三角形 };
     end;

     P := D.FindPoin( TSingle2D.Create( 0, 0 ), 10 );          // 半径 10 以内の最近傍頂点

     if Assigned( P ) then D.DeletePoin( P );                  // 削除

     D.Free;
end;
```

### ボロノイ図の取り出し

ボロノイ頂点は有限面の外心です。各ボロノイ辺はドロネー辺の双対で、辺を共有する2面の外心を結びます。`Circum` は有界・非有界の辺を同じ式で扱います。

```pascal
for F in D.Faces do
begin
     if F.InfCorn > 0 then Continue;                     // ボロノイ頂点は有限面の上にある

     C0 := F.Circum;  P0 := TSingle2D.Create( C0.X, C0.Y ) / C0.W;

     for K := 1 to 3 do
     begin
          C1 := F.Face[ K ].Circum;

          if C1.W > 0
          then P1 := TSingle2D.Create( C1.X, C1.Y ) / C1.W                    // 隣の外心までの線分
          else P1 := P0 + RayLength * TSingle2D.Create( C1.X, C1.Y ).Unitor;  // 凸包辺の外向きの半直線

          // P0 – P1 を描く（内部の辺は両側から訪れるので、中点まで描くか
          // F < F.Face[K] の側だけ描いて重複を避ける）
     end;
end;
```

### ビューア

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

編集はすべてモデルに対して行います — ビューアは勝手に追従します。最小のマウス操作の例:

```pascal
procedure TForm1.Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   P :TSingle2D;
   V :TDelaPoin2D;
begin
     P := Viewer1.ScrToPos( TPointF.Create( X, Y ) );

     V := _Delaunay.FindPoin( P, 6 );

     if Assigned( V ) then _Delaunay.DeletePoin( V )   // 既存の頂点 → 削除
                      else _Delaunay.AddPoin   ( P );  // 空白　　　 → 追加
end;
```

完全な対話的アプリケーションは [Delaunay2D](https://github.com/LUXOPHIA/Delaunay2D) にあります。

## ライセンス

[MIT License](../../LICENSE) © LUXOPHIA
