# Delaunay2D

[English](README.md) | [日本語](ja/README.md)

An interactive 2D Delaunay / Voronoi diagram demo for Delphi (FireMonkey). Clicking adds and removes points, and the Delaunay triangulation, the circumcircles, and the Voronoi diagram update live. The application is a thin form over the [LUX.Delaunay](https://github.com/LUXOPHIA/LUX.Delaunay) library, which provides both the incremental algorithm (`TDelaunay2D`) and the Skia-based viewer (`TDelaunayViewer`).

![Delaunay2D](--------/_SCREENSHOT/Delaunay2D.png)

## 利用ライブラリ

* [**LUX**](https://github.com/LUXOPHIA/LUX) ：Base library of vectors, matrices, colors, curves and other core mathematics.
* [**LUX.CG2D**](https://github.com/LUXOPHIA/LUX.CG2D) ：2D scene-graph rendering library on Skia4Delphi.
* [**LUX.Delaunay**](https://github.com/LUXOPHIA/LUX.Delaunay) ：Delaunay complexes with dynamic insertion and deletion (plane, space, torus).

## 1. Overview

- **Incremental insertion** by the Bowyer–Watson method [1][2] and **deletion** by star removal with a deterministic refill from a small Delaunay diagram of the link [4]. The diagram is Delaunay after every operation; on degenerate input `AddPoin` returns `nil` and `DeletePoin` returns `False`, leaving the diagram untouched.
- **Infinite-vertex method** — no super-triangle and no bounding box. A single vertex at infinity closes the convex hull, so hull points behave exactly like interior points, and the in-circle predicate needs no case analysis.
- **Homogeneous circumcenters** — each face yields its circumcenter as homogeneous coordinates $(C_X, C_Y, C_W)$ without branches or divisions; infinite faces degenerate naturally to $C_W = 0$ and give the directions of the unbounded Voronoi edges.
- **Jump-and-walk point location** [5] with expected cost $O(n^{1/3})$, reused for nearest-neighbor search.
- Rendering is done entirely by the library's `TDelaunayViewer` frame (a Skia scene graph built on [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D)); the application itself contains no drawing code.

## 2. Mathematical Background

### 2.1 Delaunay triangulation and the empty-circumcircle property

For a finite point set $S \subset \mathbb{R}^2$ in general position, the Delaunay triangulation $\mathrm{DT}(S)$ is the unique triangulation in which the open circumdisk of every triangle contains no point of $S$ [6]. It is the geometric dual of the Voronoi diagram of $S$: Voronoi vertices are the circumcenters of Delaunay triangles, and each Voronoi edge is perpendicular to (and dual to) a Delaunay edge between adjacent triangles.

### 2.2 The in-circle predicate via lifting

The empty-circumcircle test is evaluated with the classical lifting map onto the paraboloid $z = x^2 + y^2$: a point lies inside the circle through $P_1, P_2, P_3$ (counterclockwise) exactly when its lifted image lies below the plane through the lifted images of $P_1, P_2, P_3$. Translating the query point $Q$ to the origin turns this into a single $3 \times 3$ determinant:

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

This is exactly `TDelaFace2D.InCircle`: each vertex supplies its row via `TDelaPoin2D.Lift( Q )`, and the determinant is the scalar triple product of the three rows. The translation to a nearby point before evaluation is essential for numerical robustness — differences of `Single` coordinates are formed in `Double`, so they are exact, and the cancellation that would occur in absolute coordinates never happens. The same translated evaluation is used for the circumcenter (Section 2.4).

### 2.3 The infinite-vertex method

Instead of enclosing the input in a super-triangle, the model keeps a single **vertex at infinity** $P_\infty$ (class `TDelaPoin2DInf`), and every convex-hull edge $(P_i, P_j)$ is closed by an *infinite face* $(P_\infty, P_i, P_j)$. Thus every edge has exactly two adjacent faces and `Poin[]` never contains `nil`.

The predicate extends by homogenizing the lift: a point contributes the row $(x - w b_x,\; y - w b_y,\; \dots,\; w)$ with homogeneous component $w = 1$ for finite points and $w = 0$ for $P_\infty$, whose lifted row becomes $(0, 0, 1)$ (`TDelaPoin2DInf.Lift`). Substituting that row into (2.1) collapses the determinant to the $2 \times 2$ orientation test:

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

So for a face containing $P_\infty$ the "circumcircle" is a circle of infinite radius — a half-plane bounded by the hull edge — and the very same formula performs the half-plane test. In the lifted space a circle and a line are both just planes, so no case analysis is needed: the substitution is done polymorphically (`TDelaPoin2DInf` overrides `Lift` and `InCircled`), and the predicate itself contains no flag branches. Conversely, testing whether $P_\infty$ lies inside a circle (`TDelaPoin2DInf.InCircled`) reduces to the sign of the circle's orientation: the point at infinity is inside exactly the negatively oriented circles.

### 2.4 Homogeneous circumcenter and Voronoi duality

The circumcenter of a face is extracted as homogeneous coordinates $\mathrm{Circum} = (C_X, C_Y, C_W)$ — the coefficients (minors) of the plane through the three lifted vertices. With the homogeneous lifted rows $(x_i, y_i, z_i, w_i)$, translated to a finite base vertex $B$ as in Section 2.2:

```math
C_X = -\begin{vmatrix} y_1 & z_1 & w_1 \\ y_2 & z_2 & w_2 \\ y_3 & z_3 & w_3 \end{vmatrix},
\qquad
C_Y = +\begin{vmatrix} x_1 & z_1 & w_1 \\ x_2 & z_2 & w_2 \\ x_3 & z_3 & w_3 \end{vmatrix},
\qquad
C_W = 2\begin{vmatrix} x_1 & y_1 & w_1 \\ x_2 & y_2 & w_2 \\ x_3 & y_3 & w_3 \end{vmatrix}.
\qquad \text{(2.3)}
```

- For a **finite face** ($w_1 = w_2 = w_3 = 1$) the circumcenter is $(C_X / C_W,\; C_Y / C_W)$, and the circumradius follows as the distance to any vertex.
- For an **infinite face** the $P_\infty$ row is zero in the $x, y, w$ columns, so (2.3) degenerates naturally to $C_W = 0$, and $(C_X, C_Y)$ is the outward direction of the unbounded Voronoi edge dual to the hull edge.

There is no branch and no division in the computation, and no "center + radius" representation is forced on faces that have none. The viewer draws the Voronoi diagram directly from this duality: for every finite face it emits half-edges from its circumcenter toward the circumcenters of its three neighbors, with infinite neighbors contributing a far point along their direction vector.

### 2.5 Insertion: the Bowyer–Watson method

A new point $P$ is inserted by the two-phase Bowyer–Watson scheme [1][2] (public `AddPoin`, implemented by the private `TDelaunay2D.InsertPoin`):

1. **Mark.** Starting from one face whose circumcircle contains $P$, flood outward over adjacent faces, flagging every face whose circumcircle contains $P$. This set — the *cavity* — is connected and star-shaped with respect to $P$. Flagging is idempotent, so even when cocircular degeneracies let the flood reach a face along several paths, no face is processed twice.
2. **Carve.** For each boundary edge $(A, B)$ of the cavity, create the new face $(A, P, B)$, sew it to the outside face across the edge, then sew the new faces to each other around $P$; finally free the marked faces in one sweep (freeing after sewing, so a re-entry into a deleted face is structurally impossible).

Since the hull is closed by infinite faces, insertion outside the current hull is not a special case: the cavity simply includes infinite faces. If no containing face is found (duplicate point, or a point on the extension of a degenerate collinear edge), `AddPoin` returns `nil` and nothing is modified.

### 2.6 Deletion: star removal and refill

Removing a vertex $V$ deletes its *star* (the faces containing $V$) and leaves a star-shaped hole whose boundary is the *link* of $V$ (public `DeletePoin`, implemented by the private `TDelaunay2D.RemovePoin`):

1. **Collect** the star, the boundary edges (each stored with its outside face as a "hook") and the distinct finite link vertices, by walking around $V$ using the vertex anchor — a read-only pass that modifies nothing.
2. **Build** a small Delaunay diagram of the link vertices *alone*, as an independent component inside the same face set (no nested `TDelaunay2D` is created), by the same incremental insertion. Vertices skipped because they fall in no circumcircle yet (seed-line degeneracies) are retried until no progress; if any remain, the refill is impossible.
3. **Match seams**: for each hole boundary edge $P_A \to P_B$, find the face of the small diagram containing that edge *with the same orientation* (the face on the hole side). Missing edges, or two boundary edges mapping to the same seam (a collapsed hole), abort the refill.
4. **Flood the fill**: starting from the seam faces, flood without crossing seams and verify combinatorially that the closure's boundary coincides exactly with the hole boundary (infinite faces may appear in the fill only when the hole touches the hull).
5. **Sew** the fill faces to the hooks, free the star and the unused faces of the small diagram, and rebind the vertex anchors.

All selection and stitching is decided by combinatorial checks only — there is no flip search. If any check fails (degenerate configurations), the original triangulation has not been touched and `DeletePoin` returns `False`. A degree-2 vertex (e.g. the endpoint of a collinear cover) is handled directly by gluing the two outside faces together. This mirrors the low-degree/local-retriangulation approach to Delaunay vertex deletion [4].

### 2.7 Point location and nearest-neighbor search

The face whose circumcircle contains a query $Q$ is found by **jump-and-walk** [5] (`HitCircleFace`): draw $\lceil n^{1/3} \rceil$ random vertices, take the anchor face of the nearest sample, then walk — repeatedly crossing the edge for which $Q$ lies on the outside, decided by the degenerate predicate $\mathrm{InCircle}(A, B, P_\infty; Q) = \mathrm{orient2d}(A, B, Q)$ of (2.2). The sample count balances the expected walk length, giving expected total cost $O(n^{1/3})$; because samples are redrawn on every query, performance is uniform over the domain and independent of query history. For $Q$ outside the hull the walk naturally enters and stops at an infinite face. Cocircular or non-converging degeneracies fall back to a full scan.

Nearest-neighbor search (`FindNearPoin`) starts from the nearest vertex of the located face and then descends along Delaunay edges: as long as some Delaunay neighbor is strictly closer to $Q$, move to it. Since the distance strictly decreases, the walk terminates — necessarily at the vertex whose Voronoi cell contains $Q$, i.e. the true nearest neighbor, because in a Delaunay triangulation every vertex that is not the nearest neighbor has a Delaunay neighbor closer to the query. Expected cost is the location cost plus $O(1)$ descent steps.

## 3. Architecture

```
[Composition]
・TForm1 (Main.pas / Main.fmx)              ：Application
  ┣・_Delaunay : TDelaunay2D               ：model, owned by the form  (Model: LUX.Delaunay.D2)
  ┃                                          = TDelaFaceSet2D + algorithms
  ┃                                          PoinInf : TDelaPoin2DInf
  ┗・Viewer1 : TDelaunayViewer (TFrame)    ：view, on the form  (View: LUX.Delaunay.D2.Viewer)
                                              Paint via Skia (ISkCanvas)
     ┗・_Layers : TCGLayers                ：LUX.CG2D scene
        ┣・TDelaunayTrias                  ：triangles
        ┣・TDelaunayCircs                  ：circumcircles
        ┣・TDelaunayVolos                  ：Voronoi
        ┣・TDelaunayPoins                  ：vertices
        ┗・TCGLayer
           ┗・TCGCamera                    ：viewpoint

[Call and notification flow]
・TForm1
  ┗・AddPoin / DeletePoin / Clear          ：form → model
     ┗・TDelaunay2D
        ┗・OnChange (multicast)            ：model → view
           ┗・TDelaunayViewer              ：holds the model; rebuilds its scene

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

The model publishes structural changes through the multicast delegate `TDelaunay2D.OnChange`; the viewer subscribes and rebuilds its scene lazily — the rebuild is deferred to just before `Paint` and runs at most once per frame, bracketed by `BeginUpdate` / `EndUpdate`. Vertex/face connectivity (`Poin` / `Face` / `Corn`), the cyclic tables (`VertTableInc` / `VertTableDec`) and ownership are provided by the generic TriFlip mesh layer; the Delaunay classes add only the lift, the predicate, the homogeneous circumcenter and the algorithms.

```
・Delaunay2D.dpr / .dproj                      ：application project (FMX, Win32 / Win64)
・Main.pas / Main.fmx                          ：TForm1: thin form; no drawing code
・_LIBRARY\LUXOPHIA\                           ：git-subtree copies of separate library repos
  ┣・LUX\                                     ：base library: vectors (TSingle2D, TDouble3D, ...),
  ┃                                             lists/trees, and the TriFlip triangle-mesh model
  ┣・LUX.CG2D\                                ：2D scene graph on Skia (TCGLayer, TCGCamera, shapes)
  ┗・LUX.Delaunay\
     ┣・D2\LUX.Delaunay.D2.pas                ：TDelaunay2D and companion classes (model)
     ┣・D2\LUX.Delaunay.D2.Viewer.pas/.fmx    ：TDelaunayViewer frame (view)
     ┗・D2\Periodic\, D3\                     ：bundled with the subtree; unused by this demo
```

## 4. Usage / Controls

| Input | Action |
|---|---|
| Click on empty space | Add a point at the cursor |
| Click on (near) a point | Delete that point (nearest point within distance 6, in world units) |
| `Add x10` button | Add 10 Gaussian-distributed random points ($100 \cdot \mathcal{N}(0,1)$ per axis) |
| `Del x10` button | Delete up to 10 randomly chosen points |
| `Clear` button | Remove all points |

The form configures the view in `FormCreate`: camera field of view (`Camera.SizeX/Y = 600`) and per-layer styles (`Poins` / `Trias` / `Circs` / `Volos` → `Style.FillColor` / `LineColor` / `LineThick`). Mouse coordinates are converted to model space with `Viewer1.ScrToPos`.

## 5. Building

1. Open `Delaunay2D.dproj` in RAD Studio (Skia-enabled FMX required; RAD Studio 12 or later ships Skia integration).
2. Select Win32 or Win64 (the project targets both) and Run.

The project sets `GlobalUseSkia := True` at startup; the viewer requires the FMX canvas to be a Skia canvas (`TSkCanvasCustom`) and paints nothing otherwise. No other external dependencies are needed — all library code is included under `_LIBRARY\` as git subtrees.

## 6. References

1. A. Bowyer, *Computing Dirichlet tessellations*, The Computer Journal, 24(2), pp. 162–166, 1981.
2. D. F. Watson, *Computing the n-dimensional Delaunay tessellation with application to Voronoi polytopes*, The Computer Journal, 24(2), pp. 167–172, 1981.
3. L. J. Guibas, J. Stolfi, *Primitives for the Manipulation of General Subdivisions and the Computation of Voronoi Diagrams*, ACM Transactions on Graphics, 4(2), pp. 74–123, 1985.
4. O. Devillers, *On Deletion in Delaunay Triangulations*, International Journal of Computational Geometry & Applications, 12(3), pp. 193–205, 2002.
5. E. P. Mücke, I. Saias, B. Zhu, *Fast randomized point location without preprocessing in two- and three-dimensional Delaunay triangulations*, Computational Geometry, 12(1–2), pp. 63–83, 1999.
6. Wikipedia, [*Delaunay triangulation*](https://en.wikipedia.org/wiki/Delaunay_triangulation).

## 💖 [Embarcadero](https://www.embarcadero.com/) [**Delphi**](https://www.embarcadero.com/products/delphi)
Integrated Development Environment (IDE) for Creating Native Cross-Platform Apps.
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/products/delphi/starter)
