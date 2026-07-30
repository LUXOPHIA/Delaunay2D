# LUX.Delaunay.D3
[English](README.md) | [日本語](ja/README.md)

Delaunay tetrahedralization of Euclidean 3-space for Delphi. Sites are inserted by the Bowyer–Watson cavity construction and deleted by star removal with a deterministic refill of the hole; the exterior of the convex hull is covered by cells incident to a single point at infinity. An FMX 3D viewer frame renders the Delaunay and Voronoi edges as polygonal solids.

## 1. Overview

`TDelaunay3D` maintains a tetrahedralization of $\mathbb{E}^3$ as a set of tetrahedra (*cells*) glued face to face. Because the exterior of the convex hull is covered by cells containing the point at infinity, **every face has exactly two incident cells** and every algorithm runs without boundary cases. Vertex corners inside a cell are numbered `0..3`, and all cells are kept positively oriented.

| Property | Value |
|---|---|
| Insertion | Bowyer–Watson, two-phase mark & carve, no recursion, no placeholder |
| Deletion | star removal + refill from a local Delaunay diagram of the link |
| Hull handling | single point at infinity (no super-tetrahedron, no bounding box) |
| Predicate | one $4 \times 4$ lifted determinant, `Double`, translated to a base point |
| Circumcenter | homogeneous `( X, Y, Z, W )`, degenerating to `W = 0` at infinity |
| Point location | jump & walk, expected $O(n^{1/4})$ |
| Persistence | `*.lxtc`, coordinates plus full connectivity |
| Failure | `AddPoin` → `nil`, `DeletePoin` → `False`, nothing modified |

## 2. Mathematical Background

### 2.1 Delaunay tetrahedralization and the empty-sphere property

For a finite $P \subset \mathbb{R}^3$, a tetrahedron $\{p_0,p_1,p_2,p_3\} \subset P$ belongs to $\mathrm{Del}(P)$ iff its circumscribed open ball is empty of $P$ [3]:

```math
\{p_0,p_1,p_2,p_3\} \in \mathrm{Del}(P)
\iff
\mathrm{int}\, B(p_0,p_1,p_2,p_3) \cap P = \varnothing .
\qquad \text{(2.1)}
```

$\mathrm{Del}(P)$ is the dual of the Voronoi diagram $\mathrm{Vor}(P)$: circumcenters of cells are Voronoi vertices, and the dual of a Delaunay *face* is the Voronoi edge joining the circumcenters of its two incident cells [10]. Unlike in the plane, the complex has no fixed size: it has $\Theta(n)$ cells for well-distributed sites but $\Theta(n^2)$ in the worst case.

### 2.2 The lifting map and the unified in-sphere predicate

Let $\ell(p) = (p, \lVert p \rVert^2)$ be the lift onto the paraboloid $w = x^2 + y^2 + z^2$ in $\mathbb{R}^4$. A sphere in space is the vertical projection of the intersection of that paraboloid with a hyperplane, and $q$ is inside the sphere iff $\ell(q)$ lies strictly below the hyperplane; hence $\mathrm{Del}(P)$ is the projection of the lower convex hull of $\ell(P)$ [4]. The predicate is evaluated after translating every operand to the query point $q$,

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

The $4 \times 4$ determinant is expanded as a signed combination of scalar triple products of the spatial parts, weighted by the lifted heights (`LiftDet` / `Det3`). For a positively oriented cell, $\mathrm{InSphere} > 0$ means $q$ lies inside the circumsphere. This is `TDelaCell3D.InSphere`; the instance form `TDelaPoin3D.InSphered` is the same determinant with the receiving point as the one being tested. Translating to a nearby base point before accumulating in `Double` keeps the sign reliable when the coordinates are large [5]; no expression in the unit — predicate, orientation test or circumcenter — is evaluated in absolute coordinates.

### 2.3 The point at infinity

One extra vertex $\infty$ closes the diagram: every convex-hull face $(p_i,p_j,p_k)$ carries an *infinite cell* $(\infty, p_i, p_j, p_k)$, and `Poin[]` is never `nil`. Combinatorially this is the one-point compactification $\mathbb{R}^3 \cup \{\infty\} \cong S^3$, so the diagram is a triangulation of $S^3$ and every face has exactly two incident cells. The diagram is seeded from the first three non-collinear sites by a mirror pair of infinite cells $(\infty, p_0, p_1, p_2)$ and $(\infty, p_0, p_2, p_1)$, which doubly cover the whole space; from the fourth site on, ordinary insertion applies unchanged (`SeedCells` / `InitCell`).

`TDelaPoin3DInf` overrides the lift by the constant

```math
\mathrm{Lift}(\infty;q) = (0, 0, 0, 1) ,
\qquad \text{(2.4)}
```

the limit direction of $\ell$ along the paraboloid axis. Substituting (2.4) into (2.3) and expanding along that row collapses the determinant to a $3 \times 3$ orientation determinant, so

```math
\mathrm{InSphere}(p_0, p_1, p_2, \infty;\, q)
= \bigl\langle\, p_0 - q,\; (p_1 - q) \times (p_2 - q) \,\bigr\rangle
= \mathrm{orient}(q, p_0, p_1, p_2) .
\qquad \text{(2.5)}
```

A sphere through $\infty$ is a plane — a sphere of infinite radius — and the in-sphere test degenerates automatically into a half-space test. The same predicate therefore drives the walk of §2.6, and even the orientation check of a cell is expressible as "$\infty$ lies outside its circumsphere". The predicates contain no test of the infinity flag.

### 2.4 Homogeneous circumcenter and the Voronoi diagram

Let $B$ be a finite vertex of a cell, $L_i = \mathrm{Lift}(p_i;B)$ and $w_i \in \{1, 0\}$ the homogeneous weight of $p_i$ (0 for $\infty$). Writing lifted homogeneous coordinates as $(X, Y, Z, U, W)$ with $U$ the paraboloid height, the hyperplane through the four lifted vertices is

```math
\begin{vmatrix}
X & Y & Z & U & W \\
L_{0x} & L_{0y} & L_{0z} & L_{0u} & w_0 \\
L_{1x} & L_{1y} & L_{1z} & L_{1u} & w_1 \\
L_{2x} & L_{2y} & L_{2z} & L_{2u} & w_2 \\
L_{3x} & L_{3y} & L_{3z} & L_{3u} & w_3
\end{vmatrix} = 0
\;\;\Longleftrightarrow\;\;
a X + b Y + c Z + d U + e W = 0 ,
\qquad \text{(2.6)}
```

where $a, b, c, d, e$ are the $4 \times 4$ signed minors. Intersecting (2.6) with $U = X^2 + Y^2 + Z^2$ gives the sphere of centre $\bigl(-a/(2d),\, -b/(2d),\, -c/(2d)\bigr)$, so `Circum` returns

```math
\mathrm{Circum} = (\,-a,\; -b,\; -c,\; 2d\,) ,
\qquad \text{(2.7)}
```

with the base translation added back homogeneously. For a finite cell the centre is $(X/W, Y/W, Z/W)$; for an infinite cell the hyperplane (2.6) is vertical, $W = 2d = 0$, and $(X, Y, Z)$ is the outward direction of the unbounded Voronoi edge dual to the hull face. There is no branch and no division in the computation, and no centre-plus-radius representation is forced on the caller. `Circum` has type `TSingle4D`, whose fourth component is the homogeneous weight `W`.

### 2.5 Insertion and deletion

**Insertion** (public `AddPoin`, implemented by the private `InsertPoin`) is Bowyer–Watson [1][2]. The cavity of a new site $p$,

```math
\mathcal{C}(p) = \{\, \sigma \in \mathrm{Del}(P) \;:\; p \in \mathrm{int}\, B_\sigma \,\} ,
\qquad \text{(2.8)}
```

is star-shaped with respect to $p$, and

```math
\mathrm{Del}(P \cup \{p\}) = \bigl(\mathrm{Del}(P) \setminus \mathcal{C}(p)\bigr) \;\cup\; \{\, p * f \;:\; f \in \partial\mathcal{C}(p) \,\} .
\qquad \text{(2.9)}
```

The implementation is two-phase. ① *Mark*: $\mathcal{C}(p)$ is collected by a flag-marking flood from the located cell. In three dimensions the dual of the cavity is not a tree, so a cell may be reached along several paths; marking is idempotent, so this causes no double processing. ② *Carve*: a new cell is spanned on each boundary face and welded to the outside and to its neighbours around $p$; only then are the marked cells freed, so re-entry into a removed cell cannot occur by construction. There are no placeholders and no recursion.

**Deletion** (public `DeletePoin`, implemented by the private `RemovePoin`) removes the star of $v$ (`CollectStar`), which opens a star-shaped hole whose boundary is $\mathrm{link}(v)$, and refills it from

```math
\mathrm{Del}(P \setminus \{v\}) \;=\; \bigl(\mathrm{Del}(P) \setminus \mathrm{star}(v)\bigr) \;\cup\; \mathcal{F},
\qquad
\mathcal{F} \subset \mathrm{Del}\bigl(\mathrm{link}(v)\bigr)
\qquad \text{(2.10)}
```

— the classical fact that the retriangulation of the hole uses only link vertices [8][11]. A small Delaunay diagram of the link is therefore built by incremental insertion as an *independent component inside the same cell set* (no nested `TDelaunay3D`), the cells filling the hole are cut out of it and sewn onto the rim with `Weld`. The cut-out starts from the cells that can be glued to the hole boundary in mirror orientation (`CanWeld`) and floods everything reachable from them without crossing the boundary; it is **not** the predicate "cells whose circumsphere contains $v$": the two sets agree in general position, but under a cosphericity degeneracy a cell with $v$ exactly on its circumsphere appears inside the hole and the predicate breaks. Every step is a combinatorial check with no flip search; if any check fails on a degenerate configuration, the original diagram is left untouched and `False` is returned.

### 2.6 Queries

`HitSphereCell` locates a cell whose circumsphere contains the query point by *jump & walk* [6]: $n^{1/4}$ sites are drawn at random, the walk starts at the anchor cell of the nearest one, and crosses the face across which the query point lies outside. The face test is the degenerate form (2.5) of the unified predicate, so for a point outside the convex hull the walk enters an infinite cell and stops there naturally. The expected cost is $O(n^{1/4})$; since the sample is redrawn on every call, performance is uniform over the domain and independent of query history.

`FindNearPoin` starts from the located cell — whose vertices are necessarily near the query point — and descends greedily along Delaunay edges to ever nearer neighbours. The distance strictly decreases at every step, so the descent terminates at the site whose Voronoi region contains the query point, in $O(n^{1/4})$ expected plus $O(1)$ descent steps.

`FindMaxCircle` returns the finite cell with the largest empty circumsphere; infinite cells, whose empty spheres have infinite radius, are excluded.

## 3. Architecture

### 3.1 Class diagram

```
Inheritance

・TTetraPoin3D<TDelaCell3D>                   ･･･ (LUX)
  ┗・TDelaPoin3D
     ┗・TDelaPoin3DInf

・TTetraPoinSet3D<TDelaPoin3D>                ･･･ (LUX)
  ┗・TDelaPoinSet3D

・TTetraCell3D<TDelaPoin3D,TDelaCell3D>       ･･･ (LUX)
  ┗・TDelaCell3D

・TTetraCellSet3D<TDelaCell3D,TDelaPoinSet3D> ･･･ (LUX)
  ┗・TDelaCellSet3D
     ┗・TDelaunay3D

・TControl3D                                  ･･･ (FMX)
  ┗・TDelaunayLayer
     ┣・TDelaunayEdges
     ┗・TDelaunayVoros

・TViewport3D                                 ･･･ (FMX)
  ┗・TDelaunayViewport

・TFrame                                      ･･･ (FMX)
  ┗・TDelaunayViewer

Ownership and references

・TDelaunay3D                                 ･･･ ( = TDelaCellSet3D = cells )
  ┣・Poins :TDelaPoinSet3D
  ┃  ┗・1..* TDelaPoin3D
  ┃     ┣・Pos
  ┃     ┗・Cell, Corn                       ･･･ anchor
  ┣・Cells :TDelaCellSet3D                   ･･･ ( = Self )
  ┃  ┗・1..* TDelaCell3D
  ┃     ┣・Poin[0..3]                       ･･･ positive; PoinInf in ∞ cells
  ┃     ┣・Cell[0..3]                       ･･･ neighbours
  ┃     ┗・Corn / Bond / Join
  ┣・PoinInf :TDelaPoin3DInf                 ･･･ shared by every infinite cell
  ┗・OnChange :TDelegates                    ･･･ notifies the viewer

・TDelaunayViewer
  ┗・Viewport :TDelaunayViewport
     ┣・TDummy                               ･･･ yaw
     ┃  ┗・TDummy                           ･･･ pitch
     ┃     ┣・TCamera
     ┃     ┗・TLight                        ･･･ headlight
     ┣・TDelaunayEdges
     ┗・TDelaunayVoros
```

### 3.2 File layout

```
・D3/
  ┣・LUX.Delaunay.D3.pas               ･･･ unit LUX.Delaunay.D3
  ┃  ┣・TDelaPoin3D                   ･･･ vertex: Inf, Lift, InSphered
  ┃  ┣・TDelaPoin3DInf                ･･･ point at ∞: Lift ≡ ( 0, 0, 0, 1 )
  ┃  ┣・TDelaPoinSet3D                ･･･ vertex set (finite vertices only)
  ┃  ┣・TDelaCell3D                   ･･･ tetrahedron: InfCorn, Circum
  ┃  ┣・TDelaCellSet3D                ･･･ cell set
  ┃  ┗・TDelaunay3D                   ･･･ the model: AddPoin / DeletePoin
  ┣・LUX.Delaunay.D3.Viewer.pas / .fmx ･･･ unit LUX.Delaunay.D3.Viewer
  ┃  ┣・TDelaunayLayer                ･･･ layer base: mesh, material, Render
  ┃  ┣・TDelaunayEdges                ･･･ Delaunay edges as polygonal tubes
  ┃  ┣・TDelaunayVoros                ･･･ Voronoi edges as prisms and cones
  ┃  ┣・TDelaunayViewport             ･･･ the internal TViewport3D
  ┃  ┗・TDelaunayViewer               ･･･ the TFrame (orbit rig, picking)
  ┣・README.md                         ･･･ this document
  ┗・ja/README.md                      ･･･ Japanese translation
```

Built on the TetraFlip mesh layers of [LUX](https://github.com/LUXOPHIA/LUX) (`LUX.Data.Model.TetraFlip.core`, `LUX.Data.Model.TetraFlip.D3`), which own the points and cells and provide the connectivity, the corner and rotation tables (`VertTable` / `BondTable`), face gluing (`Weld` / `CanWeld`), the adjacency check (`CheckCells`) and the iteration. `LUX.Delaunay.D3` adds only what is Delaunay-specific; the typing layer of TetraFlip is parameterised with the derived classes themselves.

### 3.3 Class reference — `LUX.Delaunay.D3`

#### `TDelaPoin3D` — vertex

| Member | Description |
|---|---|
| `Pos :TSingle3D` | Coordinates. *(inherited)* |
| `Cell :TDelaCell3D` / `Corn :Byte` | Anchor: one cell containing this vertex, and its corner number in it. *(inherited)* |
| `Inf :Boolean` | Whether this is the point at infinity. |
| `Lift( Pos_ ) :TDouble4D` | Lift (2.2) relative to the base point `Pos_`, in double precision. |
| `InSphered( P0_,P1_,P2_,P3_ ) :Double` | Sign of this point against the sphere through `P0..P3` — positive = inside. |

#### `TDelaPoin3DInf` — the point at infinity

Derived from `TDelaPoin3D`; overrides `Lift` (constant `( 0, 0, 0, 1 )`, eq. 2.4) and `InSphered` (degenerating to the orientation of the sphere). Exactly one instance exists per diagram, `TDelaunay3D.PoinInf`; it belongs to no point set and never appears in `Poins`.

#### `TDelaCell3D` — tetrahedron

| Member | Description |
|---|---|
| `Poin[0..3] :TDelaPoin3D` | Vertices, positively oriented. *(inherited)* |
| `Cell[0..3] :TDelaCell3D` | Neighbour across the face opposite vertex `K`. *(inherited)* |
| `Corn[0..3] :Byte` | The neighbour's corner number opposite the shared face. *(inherited)* |
| `Bond[0..3] :Byte` | Rotation code of the shared-face gluing. *(inherited)* |
| `Join[K,I] :Byte` | Vertex correspondence across face `K`: frame position `I` on this side → corner number in the neighbour. *(inherited)* |
| `InfCorn :Shortint` | Corner number of the infinite vertex — `-1` means a finite cell. |
| `Circum :TSingle4D` | Homogeneous circumcenter (2.7). Finite cell → centre `( X/W, Y/W, Z/W )`; infinite cell → `W = 0` and `( X, Y, Z )` is the outward direction of the dual Voronoi edge. |
| `InSphere( P0_..P3_, Pos_ ) :Double` *(class)* | Unified lifted determinant (2.3) — positive = `Pos_` inside the sphere through `P0..P3`. |
| `IsHitSphere( Pos_ ) :Boolean` | Whether `Pos_` lies inside this cell's circumsphere. |

#### `TDelaPoinSet3D` / `TDelaCellSet3D` — sets

Iterable containers (`for C in …`, `Count`, `[I]`). `TDelaCellSet3D.Poins` exposes the **finite** vertices only.

#### `TDelaunay3D` — the diagram

| Member | Description |
|---|---|
| `Create` / `Destroy` | The empty diagram; owns its point set and the point at infinity. |
| `PoinInf :TDelaPoin3D` | The unique point at infinity. |
| `Cells :TDelaCellSet3D` | All cells, infinite ones included (alias of the object itself). |
| `Poins :TDelaPoinSet3D` | All finite vertices. |
| `OnChange :TDelegates` | Multicast notification fired after every structural change. Subscribe with `Add`, unsubscribe with `Del`. |
| `HitSphereCell( Pos_ ) :TDelaCell3D` | A cell whose circumsphere contains `Pos_` — jump & walk, expected $O(n^{1/4})$. |
| `FindMaxCircle :TDelaCell3D` | The finite cell with the largest empty circumsphere; `nil` if there is none. |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | The nearest vertex and the distance to it (locate + greedy descent). `Poin_ = nil` and `Infinity` when the diagram is empty. |
| `AddPoin( Pos_ ) :TDelaPoin3D` | Insert a site (§2.5), or `nil` when it cannot be inserted (non-finite coordinate, duplicate, a 3rd point collinear with the first two, or a degenerate position such as a point on the extension of an existing edge). The first two sites are accepted unconditionally; from the third on a cell always exists. |
| `AddPoin( Pos_, Cell_ ) :TDelaPoin3D` | Insertion with the containing cell already known; skips the search and performs no validation, so `Cell_` must be a cell whose circumsphere contains `Pos_`. |
| `DeletePoin( Poin_ ) :Boolean` | Remove a vertex (§2.5). `False`, with nothing modified, for invalid input or a degenerate configuration that cannot be refilled. |
| `Clear` | Remove all points and cells (`PoinInf` survives). |
| `SaveToFile( FileName_ )` | Save the diagram to a `*.lxtc` file — coordinates and the complete connectivity, so the structure round-trips exactly. |
| `LoadFromFile( FileName_ )` | Restore a diagram from a `*.lxtc` file. The current content is replaced entirely, the point at infinity is re-linked, and `OnChange` fires once. |

#### File format `*.lxtc`

Radiance-HDR-style layout. The file begins as UTF-8 text: the first line is the magic `LUXOPHIA TetFlip 1.0`, followed by any number of `name=value` option lines (`PoinsN`, `CellsN`, `PosSize`; unknown lines are skipped). A single blank line ends the header, and everything after it is binary — the point coordinates, then per cell its 4 vertex indices and 4 neighbour-cell indices (`Int32`; `-1` = nil, `-2` = the point at infinity) followed by the `Corn` / `Bond` / `Flag` bytes.

### 3.4 Class reference — `LUX.Delaunay.D3.Viewer`

A `TFrame` that renders a `TDelaunay3D` in an internal `TViewport3D`; all FMX scene-construction code is confined to the frame. It subscribes to `OnChange` and rebuilds its scene (discard-all, build-all) automatically, deferred to just before the next paint so that at most one rebuild happens per frame. No curved geometry is used: both layers are assembled purely from flat bands, prisms and cones cut back from the edges by a margin, so the flat face normals show the ridges of the diagram directly.

#### `TDelaunayViewer` — the frame

| Member | Description |
|---|---|
| `Delaunay :TDelaunay3D` | The diagram to display. Assigning subscribes to `OnChange`; assign `nil` to unsubscribe (do this before freeing the diagram). |
| `Camera :TCamera` | The camera at the tip of the built-in orbit rig (yaw → pitch → camera, with a headlight). |
| `Color :TAlphaColor` | Background colour. |
| `Distance :Single` | Camera distance from the origin. |
| `Edges :TDelaunayEdges` | The Delaunay-edge layer (below). |
| `Voros :TDelaunayVoros` | The Voronoi-edge layer (below). |
| `Orbit( DYaw_, DPitch_ )` | Rotate the orbit rig, in degrees. |
| `Dolly( DDistance_ )` | Change the camera distance. |
| `FindPoin( Scr_, Radius_ ) :TDelaPoin3D` | The vertex whose projection is nearest to a screen point (within `Radius_` logical pixels), or `nil` — for picking. |

#### `TDelaunayEdges` — Delaunay edges

For every vertex `K` of every finite cell, the corner points of the three incident faces are joined by four triangles (one central plus three along the edges). The corner point is `MarginCorner`: the point on the angle bisector at distance `Margin` from both edges, with `Margin` clamped to the inradius $2A/\ell$ of the triangle. Around each Delaunay edge the bands of the cells in its ring join into a closed polygonal tube; the convex-hull faces — those incident to an infinite cell — get an outer band that closes the tube from outside.

| Member | Description |
|---|---|
| `Color :TAlphaColor` | Material colour. |
| `Margin :Single` | Width of the band, measured from the edge. |

#### `TDelaunayVoros` — Voronoi edges

Every finite cell's circumcenter is a Voronoi vertex. Around it, one corner triangle per pair of the four outgoing edge directions forms a small shell; toward each finite neighbour half a triangular prism is spanned, the two halves meeting to form one prism per Voronoi edge, and unbounded edges are closed by a cone of length `RayLength`. Edge directions come from the neighbours' homogeneous circumcenters — finite neighbour → toward its centre, infinite neighbour → the outward `W = 0` direction (2.7) — with no case analysis in the geometry itself.

| Member | Description |
|---|---|
| `Color :TAlphaColor` | Material colour. |
| `Margin :Single` | Distance from the Voronoi edge to the prism faces. |
| `RayLength :Single` | Length of the cones on unbounded edges. |

## 4. Usage

### 4.1 Building and querying

```pascal
uses LUX, LUX.D3, LUX.D4, LUX.Delaunay.D3;

var
   D :TDelaunay3D;
   P :TDelaPoin3D;
   C :TDelaCell3D;
   N :Integer;
begin
     D := TDelaunay3D.Create;

     for N := 1 to 100 do D.AddPoin( 2 * TSingle3D.RandG );     // insert

     for C in D.Cells do                                        // enumerate tetrahedra
     begin
          if C.InfCorn < 0 then { C.Poin[0..3] span a finite tetrahedron };
     end;

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1     // nearest vertex and its distance
     then D.DeletePoin( P );                                     // delete

     D.Free;
end;
```

### 4.2 Extracting the Voronoi diagram

Voronoi vertices are the circumcenters of the finite cells; each Voronoi edge is dual to a Delaunay face and joins the circumcenters of the two incident cells. Equation (2.7) handles bounded and unbounded edges with the same expression.

```pascal
var
   C      :TDelaCell3D;
   K      :Byte;
   V0, V1 :TSingle4D;
   P0, P1 :TSingle3D;
begin
     for C in D.Cells do
     begin
          if C.InfCorn >= 0 then Continue;                 // Voronoi vertices sit on finite cells

          V0 := C.Circum;  P0 := TSingle3D.Create( V0.X, V0.Y, V0.Z ) / V0.W;

          for K := 0 to 3 do
          begin
               V1 := C.Cell[ K ].Circum;

               if V1.W > 0
               then P1 := TSingle3D.Create( V1.X, V1.Y, V1.Z ) / V1.W                    // segment to the neighbour centre
               else P1 := P0 + RayLength * TSingle3D.Create( V1.X, V1.Y, V1.Z ).Unitor;  // outward ray of a hull face

               // draw P0 – P1  (interior edges are visited from both sides;
               //                draw to the midpoint, or keep only C < C.Cell[K], to avoid duplicates)
          end;
     end;
end;
```

### 4.3 Viewer

Drop a `TDelaunayViewer` on a form (or create it at run time with a `Parent`), then hand it the diagram.

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
     Viewer1.Delaunay := nil;  // unsubscribe before freeing the model

     _Delaunay.Free;
end;
```

All editing goes through the model — the viewer follows by itself. Mouse interaction stays in the application; the frame only offers `Orbit` / `Dolly` / `FindPoin`.

```pascal
procedure TForm1.Viewer1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
     if _Dragging then Viewer1.Orbit( X - _MouseP.X, -( Y - _MouseP.Y ) );  // drag = rotate
end;

procedure TForm1.Viewer1MouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
     Viewer1.Dolly( - WheelDelta / 120 );  Handled := True;                 // wheel = zoom
end;

procedure TForm1.Viewer1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   V :TDelaPoin3D;
begin
     V := Viewer1.FindPoin( TPointF.Create( X, Y ), 16 );                   // click = pick & delete

     if Assigned( V ) then _Delaunay.DeletePoin( V );
end;
```

A complete interactive application is available at [Delaunay3D](https://github.com/LUXOPHIA/Delaunay3D).

## 5. References

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

## 💖 [Embarcadero](https://www.embarcadero.com/) [**Delphi**](https://www.embarcadero.com/products/delphi)
Integrated Development Environment (IDE) for Creating Native Cross-Platform Apps.
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/products/delphi/starter)
