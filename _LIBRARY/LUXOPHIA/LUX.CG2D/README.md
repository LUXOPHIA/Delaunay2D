# LUX.CG2D

[English](README.md) | [日本語](ja/README.md)

A retained-mode 2D graphics library for Delphi, built on the Skia rendering engine. Drawing primitives are objects joined into a scene tree; every node carries a 3×3 homogeneous transform and an inheritable paint style, and the scene is rasterized through a camera node into a FireMonkey frame that repaints itself whenever anything changes.

## 利用ライブラリ

* [**LUX**](https://github.com/LUXOPHIA/LUX) ：Base library providing the vectors, matrices, delegates and the `LUX.Data.Tree` tree layer.

## 1. Overview

`LUX.CG2D` offers a *scene graph* rather than an immediate-mode drawing API: the application builds a persistent tree of shape objects and mutates it, and the library decides when and how to redraw.

| Unit | Contents |
|:---|:---|
| `LUX.CG2D.pas` | Core: `TCGStyle`, `TCGObject`, `TCGShaper`, `TCGCamera`, `TCGLayer`, `TCGLayers` |
| `LUX.CG2D.Shapers.pas` | Primitives: `TCGCirc`, `TCGTria`, `TCGLine`, `TCGPlots` |
| `LUX.CG2D.Viewer.pas` / `.fmx` | `TCGViewer`, a FireMonkey `TFrame` that renders one camera |

The following properties are established by the code:

1. **Tree semantics are delegated.** Node creation, re-parenting, subtree destruction, cycle prevention and child-type checking are all handled by `LUX.Data.Tree`: `TCGObject` descends from `TTreeKnot<TCGObject,TCGObject>` and `TCGLayers` from `TTreeRoot<TCGLayer>`. Violations raise `ETreeError`.
2. **The hierarchy is type-constrained.** `TCGLayers` accepts only `TCGLayer` children, `TCGObject.AcceptChildr` rejects `TCGLayer` (layers live only directly under the root), and `TCGLayers` can never become anyone's child.
3. **Styles are inherited.** `TCGObject.Style` walks up the parents until a node owns one. `TCGLayer` force-creates a default `TCGStyle` in its constructor, so the walk always terminates inside a scene. An assigned style is *owned* by its node and freed with it, so one style object must not be shared between nodes — share by assigning it to a common ancestor instead.
4. **Paints are cached.** `TCGStyle` builds its `ISkPaint` objects lazily and discards them only when an attribute changes. Because a single Skia paint cannot fill and stroke in different colors, a shape is drawn twice: once with `PaintFill`, once with `PaintLine`. A fully transparent color yields `nil` and the corresponding pass is skipped.
5. **Changes propagate to the root.** Insertion, removal, transform assignment and style attribute changes all bubble up as `Changed` to the root `TCGLayers`, which multicasts `OnChange` (`TDelegates`). `TCGCamera` subscribes to its scene's `OnChange` and re-broadcasts it as `OnScene`, so a viewer needs nothing but a camera reference. Bulk edits are wrapped in `BeginUpdate` / `EndUpdate`, which suppresses a subtree's notifications and fires exactly once at the outermost `EndUpdate`; nodes under destruction count as updating and never notify.

Rendering goes through the Skia canvas exposed by the RTL's `System.Skia` / `FMX.Skia` units, the in-box integration of Skia4Delphi [1][2]. `TCGViewer.Paint` requires `GlobalUseSkia = True` [3] and returns without drawing when the FireMonkey canvas is not a `TSkCanvasCustom`.

## 2. Mathematical background

### 2.1 Homogeneous transforms

A node's pose is a 2D affine map stored as a 3×3 homogeneous matrix (`TSingleM3`) acting on column vectors:

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

The first two columns are the images of the local basis vectors (`AxisX`, `AxisY`) and the third is the image of the local origin (`AxisP`), i.e. the translation. FireMonkey's `TMatrix` multiplies row vectors instead, so the `TSingleM3` ⇄ `TMatrix` casts transpose:

```math
M_{\mathrm{FMX}} = M^{\mathsf T}, \qquad p'^{\mathsf T} = p^{\mathsf T} M_{\mathrm{FMX}}
\tag{2}
```

Assigning the scalar `1` to a pose yields the identity, because `TSingleM3` has an implicit cast from `Single`.

### 2.2 Pose composition

`LocalPose` maps a node's own coordinates into its parent's; `GlobalPose` is the accumulated product along the path to the root:

```math
M^{\mathrm{g}}_{k} = M^{\mathrm{g}}_{\pi(k)}\, M^{\mathrm{l}}_{k}
= \prod_{j \in \mathrm{path}(k)} M^{\mathrm{l}}_{j}
\tag{3}
```

where $\pi(k)$ is the parent of node $k$. The recursion stops at a layer — `TCGLayer.GlobalPose` returns its `LocalPose`, since `TCGLayers` holds no matrix — so a layer is the top-level coordinate system of a scene. Assigning `GlobalPose` inverts (3):

```math
M^{\mathrm{l}}_{k} = \bigl( M^{\mathrm{g}}_{\pi(k)} \bigr)^{-1} M^{\mathrm{g}}_{k}
\tag{4}
```

Only `TCGShaper` stores a matrix. `TCGObject.GetLocalPose` returns the identity and its setter is a no-op, so nodes that need no transform — including `TCGCamera` — cost nothing and are positioned solely by their ancestors' poses.

### 2.3 Traversal and the canvas matrix stack

`TCGObject.Draw` pushes the local matrix onto Skia's matrix stack [4] and recurses:

```
//// Draw — the scene graph laid onto the Skia canvas, one chain per node

・TCGObject.Draw
  ┣・Save                ･･･ push the canvas matrix stack
  ┣・Concat( LocalPose ) ･･･ the node's own matrix, onto the stack
  ┣・DrawMain            ･･･ the node paints itself under C_k of (5)
  ┣・child.Draw          ･･･ × N  recursion: every child repeats this chain
  ┃  ┣・Save
  ┃  ┣・Concat( LocalPose )
  ┃  ┣・DrawMain
  ┃  ┣・child.Draw      ･･･ × N  nested to arbitrary depth
  ┃  ┗・Restore
  ┗・Restore             ･･･ pop the canvas matrix stack
```

so the current transform in force while node $k$ paints itself is

```math
C_k = D\,V\,M^{\mathrm{g}}_{k}
\tag{5}
```

with $V$ and $D$ the view and device transforms of §2.4. `GlobalPose` is therefore never evaluated during rendering; the stack accumulates it.

### 2.4 Camera and viewport fitting

`TCGCamera.Render` prepends the inverse of the camera's global pose, taking world coordinates to camera coordinates:

```math
V = \bigl( M^{\mathrm{g}}_{\mathrm{cam}} \bigr)^{-1}
\tag{6}
```

`TCGViewer.Paint` puts the camera origin at the centre of the control and applies the isotropic scale that makes the field of view $S_x \times S_y$ (`SizeX`, `SizeY`) just fit inside a $W \times H$ control:

```math
s = \min\!\left( \frac{W}{S_x}, \frac{H}{S_y} \right), \qquad
D = T\!\left( \frac{W}{2}, \frac{H}{2} \right) S(s,s)
\tag{7}
```

Because $s$ is a minimum, the visible region is never smaller than the field of view and grows along the control's longer axis:

```math
\left( W_{\mathrm{view}}, H_{\mathrm{view}} \right) = \left( \frac{W}{s}, \frac{H}{s} \right) \ \ge\ \left( S_x, S_y \right)
\tag{8}
```

A field of view of $2 \times 2$ shown in a 3:2 control therefore covers $-1.5 \ldots +1.5$ horizontally and $-1 \ldots +1$ vertically.

## 3. Architecture

### 3.1 Classes

```
・TCGStyle           ･･･ FillColor/LineColor/… → PaintFill/PaintLine

・TTreeRoot<TCGLayer>
  ┗・TCGLayers      ･･･ scene root: BackColor, OnChange, Render

・TTreeKnot<TCGObject,TCGObject>
  ┗・TCGObject      ･･･ LocalPose/GlobalPose :TSingleM3, Style :TCGStyle, Draw
     ┣・TCGLayer    ･･･ top-level coordinate system; owns a default TCGStyle
     ┣・TCGCamera   ･･･ SizeX / SizeY, OnScene :TDelegates, Render
     ┗・TCGShaper   ･･･ the only node that stores _LocalPose
        ┣・TCGCirc  ･･･ Pos, Radius
        ┣・TCGTria  ･･･ Vert1, Vert2, Vert3
        ┣・TCGLine  ･･･ Pos1, Pos2
        ┗・TCGPlots ･･･ Poins :TArray<TPointF>  (drawn as Skia points)

・TFrame  (FMX)
  ┗・TCGViewer      ･･･ Camera :TCGCamera; Paint → ISkCanvas
```

### 3.2 Scene tree

```
・TCGLayers           ･･･ root — not a TCGObject; has neither pose nor style
  ┗・TCGLayer        ･･･ × N  only layers are accepted here
     ┗・TCGObject    ･･･ × N  any TCGObject but a layer (TCGShaper, …)
        ┗・TCGObject ･･･ × N  nested to arbitrary depth
```

### 3.3 Files

```
・LUX.CG2D/
  ┣・LUX.CG2D.pas         ･･･ style, node, shaper, camera, layer, root
  ┣・LUX.CG2D.Shapers.pas ･･･ shape primitives, each overriding DrawMain
  ┣・LUX.CG2D.Viewer.pas  ･･･ TCGViewer, subscribing to TCGCamera.OnScene
  ┗・LUX.CG2D.Viewer.fmx  ･･･ frame resource (default 400 × 300)
```

The library depends on the LUX base library for `TSingle2D`, `TSingleM3`, `TDelegates` and the tree layer.

## 4. Usage

`GlobalUseSkia := True` must be set during program initialization [3].

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

     Layer := TCGLayer.Create( Layers );                 // only layers may sit under the root

     with Layer.Style do                                 // inherited by the whole subtree
     begin
          FillColor := TAlphaColors.Orange;
          LineColor := TAlphaColors.Black;
          LineThick := 0.02;
     end;

     Circ        := TCGCirc.Create( Layer );
     Circ.Pos    := TSingle2D.Create( 0.3, 0 );          // translation part of LocalPose
     Circ.Radius := 0.2;

     Line      := TCGLine.Create( Layer );
     Line.Pos1 := TSingle2D.Create( -1, 0 );
     Line.Pos2 := TSingle2D.Create( +1, 0 );

     Pivot           := TCGShaper.Create( Layer );       // a camera stores no matrix itself,
     Pivot.LocalPose := TSingleM3.Translate( 0.5, 0 );   // so place it through a parent node
     Camera          := TCGCamera.Create( Pivot );
     Camera.SizeX    := 2;                               // field of view, in world units
     Camera.SizeY    := 2;

     CGViewer1.Camera := Camera;                         // repaints on every scene change

     Layer.BeginUpdate;                                  // one notification instead of many
     try
          Circ.Radius := 0.25;
          Circ.Pos    := TSingle2D.Create( 0.4, 0.1 );
     finally
          Layer.EndUpdate;
     end;

     CGViewer1.Camera := nil;                            // unsubscribe before freeing
     Layers.Free;                                        // frees the whole scene
end;
```

## 5. References

1. Skia4Delphi, [*skia4delphi — Cross-platform 2D graphics API for Delphi based on Google's Skia*](https://github.com/skia4delphi/skia4delphi).
2. Google, [*Skia Graphics Library*](https://skia.org/).
3. Embarcadero, [*Skia4Delphi — RAD Studio*](https://docwiki.embarcadero.com/RADStudio/en/Skia4Delphi).
4. Google, [*SkCanvas Overview*](https://skia.org/docs/user/api/skcanvas_overview/).

## 💖 [Embarcadero](https://www.embarcadero.com/) [**Delphi**](https://www.embarcadero.com/products/delphi)
Integrated Development Environment (IDE) for Creating Native Cross-Platform Apps.
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/products/delphi/starter)
