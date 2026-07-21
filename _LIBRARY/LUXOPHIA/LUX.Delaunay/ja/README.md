# LUX.Delaunay

**Delphi 用ドロネー図ライブラリ** — 2D 三角形分割と 3D 四面体分割。点の *追加* と *削除* の両方に対応し、貼るだけで使える FireMonkey ビューアフレームを同梱します。

[English](../README.md) | [日本語](README.md)

## 特徴

- **2D と 3D** — `D2/` は三角形メッシュ（TriFlip）の上に 2D ドロネー三角形分割を、`D3/` はフリップ型四面体メッシュ（TetraFlip）の上に 3D ドロネー四面体分割を構築します。
- **完全に動的** — 点はいつでも追加（Bowyer–Watson 法）・削除できます。削除は頂点の星を取り除き、リンク頂点だけの小さなドロネー図を同じ集合の中に作って穴に縫い付ける決定論的な埋め戻しで、フリップの探索を含みません。どの操作の後も構造は常に正しいドロネー図で、退化した入力には `AddPoin` が `nil` を、`DeletePoin` が `False` を返し、何も壊しません。
- **無限遠頂点方式（スーパーシンプレックス不使用）** — 凸包の外側は、ただ一つの無限遠頂点を共有する胞で覆われます。バウンディングボックスの大きさ調整も座標の制限も不要で、凸包上の点も内部の点と同じコードパスで追加・削除されます。
- **統一述語** — 内接円・内接球の判定は単一のリフト行列式です。無限遠頂点が自分のリフトを多態で差し替えるため、有限点と無限遠点、球と平面（半径無限大の球）が場合分けなしに同じ式を流れます。行列式は必ず近傍の基準点へ平行移動してから倍精度で評価するので、原点から遠いデータでも述語は安定します。
- **同次外心** — `Circum` は外心を同次座標で返します。無限遠胞では自然に `W = 0` へ退化し、`(X, Y[, Z])` が非有界ボロノイ辺の外向きの方向になります。半直線を含むボロノイ図全体が、分岐も除算もない一つの式から得られます。
- **高速なクエリ** — 点の位置検索と最近傍検索はジャンプ＆ウォークで、期待計算量は 2D で O(n^1/3)、3D で O(n^1/4)。性能は領域全体で一様です。
- **ビューア** — 図を購読して自動的にシーンを再構築する FMX `TFrame`。2D は Skia シーングラフ、3D は Viewport3D 上でドロネー辺とボロノイ辺をポリゴンの立体として描画します。

## 構成

| パス | 内容 |
|---|---|
| `D2/LUX.Delaunay.D2.pas` | 2D ドロネー図（`TDelaunay2D`） |
| `D2/LUX.Delaunay.D2.Viewer.pas/.fmx` | 2D ビューアフレーム（`TDelaunayViewer`） |
| `D3/LUX.Delaunay.D3.pas` | 3D ドロネー図（`TDelaunay3D`） |
| `D3/LUX.Delaunay.D3.Viewer.pas/.fmx` | 3D ビューアフレーム（`TDelaunayViewer`） |

クラスの一覧と詳しい使い方は **[D2/ja/README.md](../D2/ja/README.md)** と **[D3/ja/README.md](../D3/ja/README.md)** を参照してください。

## 依存関係

- [LUX](https://github.com/LUXOPHIA/LUX) — 基盤ライブラリ: ベクトル（`LUX.D2` … `LUX.D4`）、リスト、TriFlip / TetraFlip メッシュモデル（`LUX.Data.Model.*`）。
- [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) — Skia4Delphi ベースの 2D シーングラフ。**2D ビューアのみ**が必要とします。
- FireMonkey を含む Delphi。コアユニットは純粋な Object Pascal です。2D ビューアは Skia 対応の FMX キャンバス、3D ビューアは標準の `TViewport3D` を使います。

サンプルアプリケーションは、これらのリポジトリを `git subtree` で `_LIBRARY\LUXOPHIA\` 以下にベンダリングしています。

- [Delaunay2D](https://github.com/LUXOPHIA/Delaunay2D) — 対話的な 2D デモ
- [Delaunay3D](https://github.com/LUXOPHIA/Delaunay3D) — 対話的な 3D デモ

## クイックスタート

### 2D

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2;

var
   D :TDelaunay2D;
   P :TDelaPoin2D;
   F :TDelaFace2D;
   N :Integer;
begin
     D := TDelaunay2D.Create;

     for N := 1 to 100 do D.AddPoin( 100 * TSingle2D.RandG );  // 点を追加

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), P ) < 10     // 最近傍点と、そこまでの距離
     then D.DeletePoin( P );                                   // 削除

     for F in D.Faces do                                       // 三角形を列挙
     begin
          if F.InfCorn = 0 then { F.Poin[1] … F.Poin[3] が有限の三角形 };
     end;

     D.Free;
end;
```

### 3D

```pascal
uses LUX, LUX.D3, LUX.Delaunay.D3;

var
   D :TDelaunay3D;
   P :TDelaPoin3D;
   C :TDelaCell3D;
   N :Integer;
begin
     D := TDelaunay3D.Create;

     for N := 1 to 100 do D.AddPoin( TSingle3D.RandG );  // 点を追加

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1  // 最近傍点と、そこまでの距離
     then D.DeletePoin( P );                                  // 削除

     for C in D.Cells do                                 // 四面体を列挙
     begin
          if C.InfCorn < 0 then { C.Poin[0] … C.Poin[3] が有限の四面体 };
     end;

     D.Free;
end;
```

## ライセンス

[MIT License](../LICENSE) © LUXOPHIA
