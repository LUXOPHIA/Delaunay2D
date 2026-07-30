# LUX.Delaunay.D2
[English](README.md) | [日本語](ja/README.md)

Delaunay triangulation of the Euclidean plane for Delphi. Sites are inserted by the Bowyer–Watson cavity construction and deleted by star removal with a deterministic refill of the hole; the exterior of the convex hull is covered by faces incident to a single point at infinity. A Skia-based FireMonkey viewer frame is included.

## 1. Overview

`TDelaunay2D` maintains a triangulation of $\mathbb{E}^2$ as a set of triangles (*faces*) glued edge to edge. Because the exterior of the convex hull is covered by faces containing the point at infinity, **every edge has exactly two incident faces** and every algorithm runs without boundary cases. Vertex corners inside a face are numbered `1..3` counter-clockwise.

| Property | Value |
|---|---|
| Insertion | Bowyer–Watson, two-phase mark & carve, no recursion, no placeholder |
| Deletion | star removal + refill from a local Delaunay diagram of the link |
| Hull handling | single point at infinity (no super-triangle, no bounding box) |
| Predicate | one $3 \times 3$ lifted determinant, `Double`, translated to a base point |
| Circumcenter | homogeneous `( X, Y, W )`, degenerating to `W = 0` at infinity |
| Point location | jump & walk, expected $O(n^{1/3})$ |
| Persistence | `*.lxtf`, coordinates plus full connectivity |
| Failure | `AddPoin` → `nil`, `DeletePoin` → `False`, nothing modified |

## 2. Mathematical Background

### 2.1 Delaunay triangulation and the empty-circle property

For a finite $P \subset \mathbb{R}^2$, a triangle $\{p_1,p_2,p_3\} \subset P$ belongs to $\mathrm{Del}(P)$ iff its circumscribed open disk is empty of $P$ [3]:

```math
\{p_1,p_2,p_3\} \in \mathrm{Del}(P)
\iff
\mathrm{int}\, B(p_1,p_2,p_3) \cap P = \varnothing .
\qquad \text{(2.1)}
```

$\mathrm{Del}(P)$ is the straight-line dual of the Voronoi diagram $\mathrm{Vor}(P)$: circumcenters of triangles are Voronoi vertices, and the dual of a Delaunay edge is the Voronoi edge joining the circumcenters of its two incident triangles [10].

### 2.2 The lifting map and the unified in-circle predicate

Let $\ell(p) = (p, \lVert p \rVert^2)$ be the lift onto the paraboloid $z = x^2 + y^2$. A circle in the plane is the vertical projection of the intersection of that paraboloid with a plane, and $q$ is inside the circle iff $\ell(q)$ lies strictly below the plane; hence $\mathrm{Del}(P)$ is the projection of the lower convex hull of $\ell(P)$ [4]. The predicate is evaluated after translating every operand to the query point $q$,

```math
\mathrm{Lift}(p;q) =
\bigl(\, p_x - q_x,\; p_y - q_y,\; (p_x-q_x)^2 + (p_y-q_y)^2 \,\bigr),
\qquad \text{(2.2)}
```

```math
\mathrm{InCircle}(p_1,p_2,p_3;\,q) \;=\;
\det\begin{pmatrix}
\mathrm{Lift}(p_1;q) \\ \mathrm{Lift}(p_2;q) \\ \mathrm{Lift}(p_3;q)
\end{pmatrix}
\;=\;
\begin{vmatrix}
x_1-q_x & y_1-q_y & (x_1-q_x)^2+(y_1-q_y)^2 \\
x_2-q_x & y_2-q_y & (x_2-q_x)^2+(y_2-q_y)^2 \\
x_3-q_x & y_3-q_y & (x_3-q_x)^2+(y_3-q_y)^2
\end{vmatrix} .
\qquad \text{(2.3)}
```

For a counter-clockwise triangle, $\mathrm{InCircle} > 0$ means $q$ lies inside the circumcircle. This is `TDelaFace2D.InCircle`; the instance form `TDelaPoin2D.InCircled` is the same determinant with the roles exchanged (the receiving point is the one being tested). Translating to a nearby base point before accumulating in `Double` is what keeps the sign reliable when the coordinates are large [5]; no expression in the unit is evaluated in absolute coordinates.

### 2.3 The point at infinity

One extra vertex $\infty$ closes the diagram: every convex-hull edge $(p_i,p_j)$ carries an *infinite face* $(\infty, p_i, p_j)$, and `Poin[]` is never `nil`. Combinatorially, adding $\infty$ is the one-point compactification $\mathbb{R}^2 \cup \{\infty\} \cong S^2$, so the diagram of $n \ge 3$ sites is a triangulation of the sphere with $n+1$ vertices and, by Euler's formula $V - E + F = 2$ with $2E = 3F$,

```math
V = n + 1, \qquad E = 3n - 3, \qquad F = 2n - 2 ,
\qquad \text{(2.4)}
```

infinite faces included. The diagram is seeded from the first two sites by a mirror pair of infinite faces $(\infty, p_1, p_2)$ and $(\infty, p_2, p_1)$, which doubly cover the whole plane; from the third site on, ordinary insertion applies unchanged (`SeedFace` / `InitFace`).

`TDelaPoin2DInf` overrides the lift by the constant

```math
\mathrm{Lift}(\infty;q) = (0, 0, 1) ,
\qquad \text{(2.5)}
```

the limit direction of $\ell$ along the paraboloid axis. Substituting (2.5) into (2.3) and expanding along that row collapses the determinant to a $2 \times 2$ orientation determinant, so

```math
\mathrm{InCircle}(p_1, p_2, \infty;\, q)
= (x_1 - q_x)(y_2 - q_y) - (y_1 - q_y)(x_2 - q_x)
= \mathrm{orient}(q, p_1, p_2) .
\qquad \text{(2.6)}
```

A circle through $\infty$ is a straight line — a circle of infinite radius — and the in-circle test degenerates automatically into a half-plane test. This is why the same predicate drives the walk of §2.6, and why the predicates contain no test of the infinity flag.

### 2.4 Homogeneous circumcenter and the Voronoi diagram

Let $B$ be a finite vertex of a face, $L_i = \mathrm{Lift}(p_i;B)$ and $w_i \in \{1, 0\}$ the homogeneous weight of $p_i$ (0 for $\infty$). Writing lifted homogeneous coordinates as $(X, Y, Z, W)$, the plane through the three lifted vertices is

```math
\begin{vmatrix}
X & Y & Z & W \\
L_{1x} & L_{1y} & L_{1z} & w_1 \\
L_{2x} & L_{2y} & L_{2z} & w_2 \\
L_{3x} & L_{3y} & L_{3z} & w_3
\end{vmatrix} = 0
\;\;\Longleftrightarrow\;\;
a X + b Y + c Z + e W = 0 ,
\qquad \text{(2.7)}
```

where $a, b, c, e$ are the $3 \times 3$ signed minors. Intersecting (2.7) with $Z = X^2 + Y^2$ gives the circle of centre $\bigl(-a/(2c),\, -b/(2c)\bigr)$, so `Circum` returns

```math
\mathrm{Circum} = (\,-a,\; -b,\; 2c\,) ,
\qquad \text{(2.8)}
```

with the base translation added back homogeneously. For a finite face the centre is $(X/W, Y/W)$; for an infinite face the plane (2.7) is vertical, $W = 2c = 0$, and $(X, Y)$ is the outward direction of the unbounded Voronoi edge dual to the hull edge. There is no branch and no division in the computation, and no centre-plus-radius representation is forced on the caller.

> **Field naming.** `Circum` has type `TSingle3D`, whose components are `X`, `Y`, `Z`. There is no `W` field: the **`Z` component carries the homogeneous weight $W$** of (2.8). Code must read `Circum.Z`, not `Circum.W`.

### 2.5 Insertion and deletion

**Insertion** (public `AddPoin`, implemented by the private `InsertPoin`) is Bowyer–Watson [1][2]. The cavity of a new site $p$,

```math
\mathcal{C}(p) = \{\, \sigma \in \mathrm{Del}(P) \;:\; p \in \mathrm{int}\, B_\sigma \,\} ,
\qquad \text{(2.9)}
```

is star-shaped with respect to $p$, and

```math
\mathrm{Del}(P \cup \{p\}) = \bigl(\mathrm{Del}(P) \setminus \mathcal{C}(p)\bigr) \;\cup\; \{\, p * f \;:\; f \in \partial\mathcal{C}(p) \,\} .
\qquad \text{(2.10)}
```

The implementation is two-phase. ① *Mark*: $\mathcal{C}(p)$ is collected by a flag-marking flood from the located face. Marking is idempotent, so reaching a face along several paths — which cocircular degeneracies allow — causes no double processing. ② *Carve*: a new face is spanned on each boundary edge and welded to the outside and to its neighbours around $p$; only then are the marked faces freed, so re-entry into a removed face cannot occur by construction.

**Deletion** (public `DeletePoin`, implemented by the private `RemovePoin`) removes the star of $v$, which opens a star-shaped hole whose boundary is $\mathrm{link}(v)$, and refills it from

```math
\mathrm{Del}(P \setminus \{v\}) \;=\; \bigl(\mathrm{Del}(P) \setminus \mathrm{star}(v)\bigr) \;\cup\; \mathcal{F},
\qquad
\mathcal{F} \subset \mathrm{Del}\bigl(\mathrm{link}(v)\bigr)
\qquad \text{(2.11)}
```

— the classical fact that the retriangulation of the hole uses only link vertices [8]. A small Delaunay diagram of the link is therefore built by incremental insertion as an *independent component inside the same face set* (no nested `TDelaunay2D`), the faces filling the hole are cut out of it and sewn onto the rim. The cut-out is a topological flood from the faces that match the hole boundary in mirror orientation, **not** the predicate "faces whose circumcircle contains $v$": the two sets agree in general position, but under a cocircular degeneracy a face with $v$ exactly on its circumcircle appears inside the hole and the predicate breaks. No flip search is involved at any step; if a combinatorial check fails on a degenerate configuration, the original diagram is left untouched and `False` is returned.

### 2.6 Queries

`HitCircleFace` locates a face whose circumcircle contains the query point by *jump & walk* [6]: $n^{1/3}$ sites are drawn at random, the walk starts at the anchor face of the nearest one, and crosses the edge across which the query point lies outside. The edge test is the degenerate form (2.6) of the unified predicate, so for a point outside the convex hull the walk enters an infinite face and stops there naturally. The expected cost is $O(n^{1/3})$; since the sample is redrawn on every call, performance is uniform over the domain and independent of query history.

`FindNearPoin` starts from the located face — whose vertices are necessarily near the query point — and descends greedily along Delaunay edges to ever nearer neighbours. The distance strictly decreases at every step, so the descent terminates at the site whose Voronoi region contains the query point, in $O(n^{1/3})$ expected plus $O(1)$ descent steps.

`FindMaxCircle` returns the finite face with the largest empty circumcircle; infinite faces, whose empty circles have infinite radius, are excluded.

## 3. Architecture

### 3.1 Class diagram

```
Inheritance

・TTriPoin2D<TDelaFace2D>                      ：(LUX)
  ┗・TDelaPoin2D
     ┗・TDelaPoin2DInf

・TTriPoinSet2D<TDelaPoin2D>                   ：(LUX)
  ┗・TDelaPoinSet2D

・TTriFace2D<TDelaPoin2D,TDelaFace2D>          ：(LUX)
  ┗・TDelaFace2D

・TTriFaceSet2D<TDelaFace2D,TDelaPoinSet2D>    ：(LUX)
  ┗・TDelaFaceSet2D
     ┗・TDelaunay2D

・TFrame                                       ：(FMX)
  ┗・TDelaunayViewer

・TCGLayer                                     ：(LUX.CG2D)
  ┣・TDelaunayTrias
  ┣・TDelaunayCircs
  ┣・TDelaunayVolos
  ┗・TDelaunayPoins

Ownership and references

・TDelaunay2D                                  ：( = TDelaFaceSet2D = the face set )
  ┣・Poins    :TDelaPoinSet2D
  ┃  ┗・1..* TDelaPoin2D
  ┃     ┣・Pos
  ┃     ┗・Face, Corn                        ：anchor
  ┣・Faces    :TDelaFaceSet2D                 ：( = Self )
  ┃  ┗・1..* TDelaFace2D
  ┃     ┣・Poin[1..3]                        ：CCW; an infinite face holds PoinInf here
  ┃     ┣・Face[1..3]                        ：neighbours
  ┃     ┗・Corn[1..3]
  ┣・PoinInf  :TDelaPoin2DInf                 ：shared by every infinite face
  ┗・OnChange :TDelegates                     ：notifies the viewer

・TDelaunayViewer
  ┗・Layers :TCGLayers                        ：creation order = drawing order (bottom to top)
     ┣・TDelaunayTrias                        ：bottom
     ┣・TDelaunayCircs
     ┣・TDelaunayVolos
     ┣・TDelaunayPoins                        ：top
     ┗・TCGCamera layer
```

### 3.2 File layout

```
・D2/
  ┣・LUX.Delaunay.D2.pas                           ：unit LUX.Delaunay.D2
  ┃  ┣・TDelaPoin2D                               ：vertex: Inf, Lift, InCircled
  ┃  ┣・TDelaPoin2DInf                            ：the point at infinity: Lift ≡ ( 0, 0, 1 )
  ┃  ┣・TDelaPoinSet2D                            ：vertex set (finite vertices only)
  ┃  ┣・TDelaFace2D                               ：triangle: InfCorn, Circum, InCircle, IsHitCircle
  ┃  ┣・TDelaFaceSet2D                            ：face set
  ┃  ┗・TDelaunay2D                               ：the model: AddPoin / DeletePoin / queries / I-O
  ┣・LUX.Delaunay.D2.Viewer.pas / .fmx             ：unit LUX.Delaunay.D2.Viewer
  ┃  ┣・TDelaunayTrias / Circs / Volos / Poins    ：scene layers on the LUX.CG2D scene graph
  ┃  ┗・TDelaunayViewer                           ：the TFrame
  ┣・README.md                                     ：this document
  ┣・ja/README.md                                  ：Japanese translation
  ┗・Periodic/                                     ：LUX.Delaunay.D2.Periodic — the flat-torus variant
```

Built on the TriFlip mesh layers of [LUX](https://github.com/LUXOPHIA/LUX) (`LUX.Data.Model.TriFlip.core`, `LUX.Data.Model.TriFlip.D2`), which own the points and faces and provide the connectivity, the corner tables (`VertTableInc` / `VertTableDec`), edge welding, the adjacency check (`CheckEdges`) and the iteration. `LUX.Delaunay.D2` adds only what is Delaunay-specific; the typing layer of TriFlip is parameterised with the derived classes themselves.

### 3.3 Class reference — `LUX.Delaunay.D2`

#### `TDelaPoin2D` — vertex

| Member | Description |
|---|---|
| `Pos :TSingle2D` | Coordinates. *(inherited)* |
| `Face :TDelaFace2D` / `Corn :Byte` | Anchor: one face containing this vertex, and its corner number in it. *(inherited)* |
| `Inf :Boolean` | Whether this is the point at infinity. |
| `Lift( Pos_ ) :TDouble3D` | Lift (2.2) relative to the base point `Pos_`. |
| `InCircled( P1_,P2_,P3_ ) :Double` | Sign of this point against the circle through `P1..P3` — positive = inside. |

#### `TDelaPoin2DInf` — the point at infinity

Derived from `TDelaPoin2D`; overrides `Lift` (constant `( 0, 0, 1 )`, eq. 2.5) and `InCircled` (degenerating to the orientation of the circle). Exactly one instance exists per diagram, `TDelaunay2D.PoinInf`; it belongs to no point set and never appears in `Poins`.

#### `TDelaFace2D` — triangle

| Member | Description |
|---|---|
| `Poin[1..3] :TDelaPoin2D` | Vertices, counter-clockwise. *(inherited)* |
| `Face[1..3] :TDelaFace2D` | Neighbour across the edge opposite vertex `K`. *(inherited)* |
| `Corn[1..3] :Byte` | The neighbour's corner number opposite the shared edge. *(inherited)* |
| `InfCorn :Byte` | Corner number of the infinite vertex — `0` means a finite face. |
| `Circum :TSingle3D` | Homogeneous circumcenter (2.8). **`Z` is the homogeneous weight $W$.** Finite face → centre `( X/Z, Y/Z )`; infinite face → `Z = 0` and `( X, Y )` is the outward direction of the dual Voronoi edge. |
| `InCircle( P1_,P2_,P3_, Pos_ ) :Double` *(class)* | Unified lifted determinant (2.3) — positive = `Pos_` inside the circle through `P1..P3`. |
| `IsHitCircle( Pos_ ) :Boolean` | Whether `Pos_` lies inside this face's circumcircle. |

#### `TDelaPoinSet2D` / `TDelaFaceSet2D` — sets

Iterable containers (`for P in …`, `Count`, `[I]`). `TDelaFaceSet2D.Poins` exposes the **finite** vertices only.

#### `TDelaunay2D` — the diagram

| Member | Description |
|---|---|
| `Create` / `Destroy` | The empty diagram; owns its point set and the point at infinity. |
| `PoinInf :TDelaPoin2D` | The unique point at infinity. |
| `Faces :TDelaFaceSet2D` | All faces, infinite ones included (alias of the object itself). |
| `Poins :TDelaPoinSet2D` | All finite vertices. |
| `OnChange :TDelegates` | Multicast notification fired after every structural change. Subscribe with `Add`, unsubscribe with `Del`. |
| `HitCircleFace( Pos_ ) :TDelaFace2D` | A face whose circumcircle contains `Pos_` — jump & walk, expected $O(n^{1/3})$. |
| `FindMaxCircle :TDelaFace2D` | The finite face with the largest empty circumcircle; `nil` if there is none. |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | The nearest vertex and the distance to it (locate + greedy descent). `Poin_ = nil` and `Infinity` when the diagram is empty. |
| `AddPoin( Pos_ ) :TDelaPoin2D` | Insert a site (§2.5), or `nil` when it cannot be inserted (non-finite coordinate, duplicate, or a degenerate position such as a point on the extension of an existing edge). |
| `AddPoin( Pos_, Face_ ) :TDelaPoin2D` | Insertion with the containing face already known; skips the search and performs no validation, so `Face_` must be a face whose circumcircle contains `Pos_`. |
| `DeletePoin( Poin_ ) :Boolean` | Remove a vertex (§2.5). `False`, with nothing modified, for invalid input or a degenerate configuration that cannot be refilled. |
| `Clear` | Remove all points and faces (`PoinInf` survives). |
| `SaveToFile( FileName_ )` | Save the diagram to a `*.lxtf` file — coordinates and the complete connectivity, so the structure round-trips exactly. |
| `LoadFromFile( FileName_ )` | Restore a diagram from a `*.lxtf` file. The current content is replaced entirely, the point at infinity is re-linked, and `OnChange` fires once. |

#### File format `*.lxtf`

Radiance-HDR-style layout. The file begins as UTF-8 text: the first line is the magic `LUXOPHIA TriFlip 1.0`, followed by any number of `name=value` option lines (`PoinsN`, `FacesN`, `PosSize`; unknown lines are skipped). A single blank line ends the header, and everything after it is binary — the point coordinates, then per face its 3 vertex indices and 3 neighbour-face indices (`Int32`; `-1` = nil, `-2` = the point at infinity) followed by the packed corner/flag byte.

### 3.4 Class reference — `LUX.Delaunay.D2.Viewer`

A `TFrame` that renders a `TDelaunay2D` through the [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) scene graph (Skia4Delphi). It subscribes to `OnChange` and rebuilds its scene automatically, deferred to just before the next paint so that at most one rebuild happens per frame. It carries no drawing code of its own.

#### `TDelaunayViewer` — the frame

| Member | Description |
|---|---|
| `Delaunay :TDelaunay2D` | The diagram to display. Assigning subscribes to `OnChange`; assign `nil` to unsubscribe (do this before freeing the diagram). |
| `Layers :TCGLayers` | The constructed scene. |
| `Camera :TCGCamera` | The view; `SizeX` / `SizeY` are the visible extent in model units (400 × 400 by default). |
| `Poins` / `Trias` / `Circs` / `Volos` | The scene layers (below). |
| `ScrToPos( S_ ) :TSingle2D` / `PosToScr( P_ ) :TPointF` | Convert between screen and model coordinates. |

#### Layers

Each layer is a `TCGLayer` with a `Style` (`FillColor` / `LineColor` / `LineThick`); changing a style repaints automatically. Creation order is drawing order, from the bottom up.

| Layer | Shows |
|---|---|
| `TDelaunayTrias` | The Delaunay triangles. |
| `TDelaunayCircs` | The circumcircles of the finite faces. |
| `TDelaunayVolos` | The Voronoi diagram; unbounded edges are drawn as outward rays. |
| `TDelaunayPoins` | The vertices (`Radius` in model units). |

## 4. Usage

### 4.1 Building and querying

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2;

var
   D :TDelaunay2D;
   P :TDelaPoin2D;
   F :TDelaFace2D;
   N :Integer;
begin
     D := TDelaunay2D.Create;

     for N := 1 to 100 do D.AddPoin( 100 * TSingle2D.RandG );   // insert

     for F in D.Faces do                                        // enumerate triangles
     begin
          if F.InfCorn = 0 then { F.Poin[1..3] span a finite triangle };
     end;

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), P ) < 10      // nearest vertex and its distance
     then D.DeletePoin( P );                                    // delete

     D.Free;
end;
```

### 4.2 Extracting the Voronoi diagram

Voronoi vertices are the circumcenters of the finite faces; each Voronoi edge is dual to a Delaunay edge and joins the circumcenters of the two incident faces. Equation (2.8) handles bounded and unbounded edges with the same expression — recall that the homogeneous weight is the `Z` component of `TSingle3D`.

```pascal
var
   F      :TDelaFace2D;
   K      :Byte;
   C0, C1 :TSingle3D;
   P0, P1 :TSingle2D;
begin
     for F in D.Faces do
     begin
          if F.InfCorn > 0 then Continue;                  // Voronoi vertices sit on finite faces

          C0 := F.Circum;  P0 := TSingle2D.Create( C0.X, C0.Y ) / C0.Z;

          for K := 1 to 3 do
          begin
               C1 := F.Face[ K ].Circum;

               if C1.Z > 0
               then P1 := TSingle2D.Create( C1.X, C1.Y ) / C1.Z                    // segment to the neighbour centre
               else P1 := P0 + RayLength * TSingle2D.Create( C1.X, C1.Y ).Unitor;  // outward ray of a hull edge

               // draw P0 – P1  (interior edges are visited from both sides;
               //                draw to the midpoint, or keep only F < F.Face[K], to avoid duplicates)
          end;
     end;
end;
```

### 4.3 Viewer

Drop a `TDelaunayViewer` on a form (or create it at run time with a `Parent`), then hand it the diagram.

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
     _Delaunay := TDelaunay2D.Create;

     with Viewer1 do
     begin
          Delaunay := _Delaunay;

          with Camera do begin  SizeX := 600;  SizeY := 600;  end;   // visible extent

          Poins.Style.FillColor := TAlphaColors.Red;
          Trias.Style.FillColor := TAlphaColors.Cornflowerblue;
          Circs.Style.LineColor := TAlphaColors.Lime;
          Volos.Style.LineColor := TAlphaColors.Black;
     end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
     Viewer1.Delaunay := nil;  // unsubscribe before freeing the model

     _Delaunay.Free;
end;
```

All editing goes through the model — the viewer follows by itself. A minimal mouse interaction:

```pascal
procedure TForm1.Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   P :TSingle2D;
   V :TDelaPoin2D;
begin
     P := Viewer1.ScrToPos( TPointF.Create( X, Y ) );

     if _Delaunay.FindNearPoin( P, V ) < 6
     then _Delaunay.DeletePoin( V )   // near an existing vertex → delete
     else _Delaunay.AddPoin   ( P );  // empty space             → insert
end;
```

A complete interactive application is available at [Delaunay2D](https://github.com/LUXOPHIA/Delaunay2D).

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

## 💖 [Embarcadero](https://www.embarcadero.com/) [**Delphi**](https://www.embarcadero.com/products/delphi)
Integrated Development Environment (IDE) for Creating Native Cross-Platform Apps.
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/products/delphi/starter)
