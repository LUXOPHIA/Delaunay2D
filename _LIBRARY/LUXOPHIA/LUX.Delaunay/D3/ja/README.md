# LUX.Delaunay.D3

**Delphi 用 3D ドロネー四面体分割** — フリップ型四面体メッシュ上での逐次的な点の追加と削除、およびドロネー辺・ボロノイ辺をポリゴン化して描く FMX 3D ビューアフレーム。

[English](../README.md) | [日本語](README.md)

ドロネー図は、面で貼り合わされた四面体（*胞*）の集合です。凸包の外側は、ただ一つの *無限遠頂点* を含む胞で覆われるため、どの面にも常にちょうど2つの胞が接し、すべてのアルゴリズムが境界の場合分けなしに動きます。胞の中の頂点番号は **0..3** で、すべての胞は正の向きに保たれます。

---

## クラス — `LUX.Delaunay.D3`

[LUX](https://github.com/LUXOPHIA/LUX) の TetraFlip メッシュ層（`LUX.Data.Model.TetraFlip.*`）が接続・面の縫合（`Weld`）・所有・列挙を担い、`LUX.Delaunay.D3` はドロネー固有の機能だけを加えます。

### `TDelaPoin3D` — 頂点

| メンバ | 説明 |
|---|---|
| `Pos :TSingle3D` | 座標。*(継承)* |
| `Cell :TDelaCell3D` / `Corn :Byte` | アンカー: この頂点を含む胞の一つと、その中での頂点番号。*(継承)* |
| `Inf :Boolean` | 無限遠頂点かどうか。 |
| `Lift( Pos_ ) :TDouble4D` | 基準点 `Pos_` から見たリフト座標 `( X, Y, Z, X²+Y²+Z² )`（倍精度）。 |
| `InSphered( P0_,P1_,P2_,P3_ ) :Double` | 球 `( P0, P1, P2, P3 )` に対する自分の内外の符号 — 正 = 内側。 |

### `TDelaPoin3DInf` — 無限遠頂点

`TDelaPoin3D` の派生。`Lift`（常に `( 0, 0, 0, 1 )`）と `InSphered`（球の向きへの退化）を多態で差し替えます。図につき唯一のインスタンス（`TDelaunay3D.PoinInf`）で、点集合には属さず `Poins` にも現れません。

### `TDelaCell3D` — 四面体

| メンバ | 説明 |
|---|---|
| `Poin[0..3] :TDelaPoin3D` | 頂点（正の向き）。*(継承)* |
| `Cell[0..3] :TDelaCell3D` | 頂点 `K` の対面で接する隣接胞。*(継承)* |
| `Corn[0..3] :Byte` | 隣接胞から見た、共有面の対頂点の番号。*(継承)* |
| `Bond[0..3] :Byte` | 共有面の貼り合わせの回転コード。*(継承)* |
| `Join[K,I] :Byte` | 面 `K` を挟む頂点対応: こちら側の枠番号 `I` → 隣接胞での頂点番号。*(継承)* |
| `InfCorn :Shortint` | 無限遠頂点の番号 — `-1` は有限胞。 |
| `Circum :TSingle4D` | 同次外心 `( X, Y, Z, W )`。有限胞 → 外心は `( X/W, Y/W, Z/W )`。無限遠胞 → `W = 0` で `( X, Y, Z )` が双対ボロノイ辺の外向きの方向。 |
| `InSphere( P0_..P3_, Pos_ ) :Double` *(class)* | 統一リフト行列式 — 正 = `Pos_` が球 `( P0 … P3 )` の内側。 |
| `IsHitSphere( Pos_ ) :Boolean` | `Pos_` がこの胞の外接球の内側にあるか。 |

### `TDelaPoinSet3D` / `TDelaCellSet3D` — 集合

列挙可能なコンテナ（`for C in …`・`Count`・`[I]`）。`TDelaCellSet3D.Poins` は **有限の** 頂点だけを見せます。

### `TDelaunay3D` — ドロネー図

| メンバ | 説明 |
|---|---|
| `Create` / `Destroy` | 空の図。点集合と無限遠頂点を所有します。 |
| `PoinInf :TDelaPoin3D` | 唯一の無限遠頂点。 |
| `Cells :TDelaCellSet3D` | 無限遠胞を含む全ての胞（自分自身の別名）。 |
| `Poins :TDelaPoinSet3D` | 全ての有限頂点。 |
| `OnChange :TDelegates` | 構造が変化するたびに発火する多播通知。`Add` で購読、`Del` で解除。 |
| `HitSphereCell( Pos_ ) :TDelaCell3D` | `Pos_` を外接球に含む胞 — ジャンプ＆ウォーク、期待 O(n^1/4)。 |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | 最近傍頂点と、そこまでの距離（位置検索＋貪欲降下）。図が空なら `Poin_ = nil` と `Infinity`。 |
| `AddPoin( Pos_ ) :TDelaPoin3D` | 点の追加（Bowyer–Watson 法）。追加できない退化配置（重複・最初の2点と共線の3点目など）は `nil`。所属胞が既知ならオーバーロード `AddPoin( Pos_, Cell_ )` で検索を省けます。 |
| `DeletePoin( Poin_ ) :Boolean` | 頂点の削除 — 星を取り除き、リンクの小さなドロネー図から決定論的に穴を埋め戻します（下記）。不正な入力や埋め戻せない退化配置では、何も変えずに `False`。 |
| `Clear` | 全ての点と胞を消去します（`PoinInf` は残ります）。 |
| `SaveToFile( FileName_ )` | 図を `*.lxtc` ファイルへ保存します。座標だけでなく接続構造（頂点・隣接胞・角と回転のコード）を全て含むため、構造がそのまま往復します。 |
| `LoadFromFile( FileName_ )` | `*.lxtc` ファイルから図を復元します。現在の内容は全て置き換わり、無限遠頂点も接続ごと再現され、`OnChange` が一度発火します。 |

**ファイル形式 `*.lxtc`** — Radiance HDR 形式と同じ構成です。冒頭は UTF-8 テキストで、1行目が固有のヘッダ `LUXOPHIA TetFlip 1.0`、以降は `名前=値` のオプション行（`PoinsN` / `CellsN` / `PosSize`。未知の行は読み飛ばされます）。1行の空行を挟んで、それ以降はバイナリです：点の座標列、続いて胞ごとに頂点番号 ×4・隣接胞番号 ×4（`Int32`。`-1` = nil、`-2` = 無限遠頂点）と `Corn` / `Bond` / `Flag` の3バイト。

---

## クラス — `LUX.Delaunay.D3.Viewer`

`TDelaunay3D` を内部の `TViewport3D` で描画する `TFrame`。`OnChange` を購読し、シーンを自動的に（次の描画まで遅延して）再構築します。曲面は使いません: ドロネー辺もボロノイ辺も、辺からマージンだけ切り下げた平面の面の組み合わせで作られるため、フラットシェーディングの稜線が図の構造をそのまま見せます。

### `TDelaunayViewer` — フレーム

| メンバ | 説明 |
|---|---|
| `Delaunay :TDelaunay3D` | 表示する図。代入で `OnChange` を購読します。`nil` の代入で解除（図を解放する前に行うこと）。 |
| `Camera :TCamera` | 内蔵の軌道リグ（ヨー → ピッチ → カメラ、ヘッドライト付き）の先端のカメラ。 |
| `Color :TAlphaColor` | 背景色。 |
| `Distance :Single` | 原点からのカメラ距離。 |
| `Edges :TDelaunayEdges` | ドロネー辺レイヤ（下記）。 |
| `Voros :TDelaunayVoros` | ボロノイ辺レイヤ（下記）。 |
| `Orbit( DYaw_, DPitch_ )` | 軌道リグを回します（度）。 |
| `Dolly( DDistance_ )` | カメラ距離を変えます。 |
| `FindPoin( Scr_, Radius_ ) :TDelaPoin3D` | スクリーン座標に最も近い頂点（`Radius_` ピクセル以内）。ピッキング用。 |

### `TDelaunayEdges` — ドロネー辺

各有限胞の各面について、三角形の隅を `MarginCorner`（角の二等分線上・両辺から距離 `Margin`・内接円半径でクランプ）で切り落とし、辺に沿った平面の枠を残します。各ドロネー辺のまわりでは、辺の環をなす胞の枠が繋がって閉じた多角形の管になります。凸包の面には外側の枠を張り、管を外から閉じます。

| メンバ | 説明 |
|---|---|
| `Color :TAlphaColor` | 材質の色。 |
| `Margin :Single` | 辺から測った枠の幅。 |

### `TDelaunayVoros` — ボロノイ辺

各有限胞の外心はボロノイ頂点です。そのまわりに4本の辺方向の対ごとのコーナー三角形が小さな殻を作り、有限の隣接胞へは三角柱の半分を渡します（両側の半分が合わさってボロノイ辺1本につき1本の柱になります）。非有界の辺は長さ `RayLength` の錐で閉じます。辺の方向は隣接胞の同次外心から得られます — 有限の隣 → その外心へ、無限遠の隣 → `W = 0` の外向きの方向 — 幾何の側に場合分けはありません。

| メンバ | 説明 |
|---|---|
| `Color :TAlphaColor` | 材質の色。 |
| `Margin :Single` | ボロノイ辺から柱の面までの距離。 |
| `RayLength :Single` | 非有界の辺の錐の長さ。 |

---

## 使い方

### 構築とクエリ

```pascal
uses LUX, LUX.D3, LUX.D4, LUX.Delaunay.D3;

var
   D :TDelaunay3D;
   P :TDelaPoin3D;
   C :TDelaCell3D;
   N :Integer;
begin
     D := TDelaunay3D.Create;

     for N := 1 to 100 do D.AddPoin( 2 * TSingle3D.RandG );  // 追加

     for C in D.Cells do                                     // 四面体を列挙
     begin
          if C.InfCorn < 0 then { C.Poin[0..3] が有限の四面体 };
     end;

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1  // 最近傍頂点と、そこまでの距離
     then D.DeletePoin( P );                                  // 削除

     D.Free;
end;
```

### ボロノイ図の取り出し

ボロノイ頂点は有限胞の外心です。各ボロノイ辺はドロネー面の双対で、面を共有する2胞の外心を結びます。`Circum` は有界・非有界の辺を同じ式で扱います。

```pascal
for C in D.Cells do
begin
     if C.InfCorn >= 0 then Continue;                    // ボロノイ頂点は有限胞の上にある

     V0 := C.Circum;  P0 := TSingle3D.Create( V0.X, V0.Y, V0.Z ) / V0.W;

     for K := 0 to 3 do
     begin
          V1 := C.Cell[ K ].Circum;

          if V1.W > 0
          then P1 := TSingle3D.Create( V1.X, V1.Y, V1.Z ) / V1.W                    // 隣の外心までの線分
          else P1 := P0 + RayLength * TSingle3D.Create( V1.X, V1.Y, V1.Z ).Unitor;  // 凸包面の外向きの半直線

          // P0 – P1 を描く（内部の辺は両側から訪れるので、中点まで描くか
          // C < C.Cell[K] の側だけ描いて重複を避ける）
     end;
end;
```

### ビューア

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

編集はすべてモデルに対して行います — ビューアは勝手に追従します。マウス操作はアプリケーション側に置き、フレームは `Orbit` / `Dolly` / `FindPoin` だけを提供します。

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

---

## アルゴリズムの補足

- **追加** は Bowyer–Watson 法の2相方式です。①**マーク** — 追加点を外接球に含む胞群（キャビティ）をフラグの塗り広げで集めます。塗りは冪等なので、3D でキャビティの双対が木にならなくても（同じ胞に複数の経路で到達しても）二重処理は起こりません。②**カーブ** — 境界面ごとに新しい胞を張って外側および追加点の周りの隣どうしと縫い、最後に塗った胞をまとめて解放します。解放は縫合の後なので、削除済みの胞への再突入は構造的に起こりません。プレースホルダも再帰もありません。
- **削除** は頂点の星を取り除いて開いた星型の穴を、決定論的に埋め戻します。リンク頂点だけの小さなドロネー図を、同じ胞集合の中の独立した成分として逐次添加法で作り（入れ子の `TDelaunay3D` は作りません）、穴を埋める胞 ―― 境界面に鏡像の向きで貼り合う胞（`CanWeld`）と、そこから境界を越えずに届く胞 ―― を切り出して縁に縫い付けます（`Weld`）。全ての工程はフリップの探索を含まない組合せ的な検査で確定し、退化配置で検査に通らなければ、元の図を一切変えずに `False` を返します。
- **述語**: 内外・向き・歩行の判定はすべて単一のリフト行列式で行い、オペランドを近傍の基準点へ平行移動してから倍精度で評価します。

## ライセンス

[MIT License](../../LICENSE) © LUXOPHIA
