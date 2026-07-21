# Delaunay2D

**Delphi（FireMonkey）による対話的な 2D ドロネー図 / ボロノイ図のデモ。**

[English](../README.md) | [日本語](README.md)

クリックで点を追加・削除すると、ドロネー三角形分割・外接円・ボロノイ図がリアルタイムに更新されます。[LUX.Delaunay](https://github.com/LUXOPHIA/LUX.Delaunay) ライブラリの上に作られています。

- 逐次的な **追加**（Bowyer–Watson 法）と **削除**（星の除去と、リンクの小さなドロネー図による決定論的な埋め戻し）— どの操作の後も図は常にドロネーで、退化した入力には `AddPoin` が `nil` を、`DeletePoin` が `False` を返します。
- **無限遠頂点方式** — スーパートライアングルもバウンディングボックスも不要で、凸包上の点も内部の点と同じように扱えます。
- 描画はライブラリの `TDelaunayViewer` フレーム（Skia シーングラフ）が担い、アプリケーション自体は描画コードを持ちません。

## 操作

| 入力 | 動作 |
|---|---|
| 空白をクリック | 点を追加 |
| 点をクリック | その点を削除 |
| `Add x10` | ランダムな点を10個追加 |
| `Del x10` | ランダムに10個削除 |
| `Clear` | 全消去 |

## 構成

```
Delaunay2D.dpr / Main.pas / Main.fmx    … アプリケーション（薄いフォーム。シーン生成コードは持たない）
_LIBRARY\LUXOPHIA\
  LUX.Delaunay\                         … ドロネー図ライブラリ（git subtree）
    D2\LUX.Delaunay.D2.pas              …   2D ドロネー図（TDelaunay2D）
    D2\LUX.Delaunay.D2.Viewer.pas/.fmx  …   2D ビューアフレーム（TDelaunayViewer）
    D3\…                                …   3D 版ユニット（サブツリーに同居。このサンプルでは未使用）
  LUX.CG2D\                             … Skia ベースの 2D シーングラフ（git subtree）
  LUX\                                  … 基盤ライブラリ（git subtree）
```

## ビルド

RAD Studio で `Delaunay2D.dproj` を開いて実行します（Win32 / Win64）。ビューアは [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) 経由で描画するため、Skia 対応の FMX キャンバスが必要です。

## ライブラリのドキュメント

クラスの一覧と API の使い方はライブラリ側にあります:
[LUX.Delaunay/D2](https://github.com/LUXOPHIA/LUX.Delaunay/tree/main/D2)
