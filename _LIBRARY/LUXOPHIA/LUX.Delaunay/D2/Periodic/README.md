# LUX.Delaunay.D2.Periodic
[English](README.md) | [日本語](ja/README.md)

Delaunay triangulation of the flat torus $\mathbb{T}^2 = \mathbb{R}^2 / L\mathbb{Z}^2$ for Delphi. No ghost-point replication and no covering space: the triangulation is kept in the minimal representation at all times, as a $\Delta$-complex of $n$ vertices and $2n$ faces, valid down to $n = 1$. All predicates are exact integer predicates on a quantized grid, and both insertion and deletion are local operations.

## 1. Overview

`TPeriDelaunay2D` maintains the Delaunay triangulation of a lattice-periodic point set directly on the quotient space. Vertices are in bijection with sites — there are no copies — and each face stores per-corner lattice offsets that place its three corners in the face's own lift to the universal cover $\mathbb{R}^2$.

| Property | Value |
|---|---|
| Domain | square torus `Size` × `Size`, i.e. $L = \texttt{Size}$ |
| Representation | minimal: $n$ vertices, $3n$ edges, $2n$ faces, for every $n \ge 1$ |
| Complex type | $\Delta$-complex (a face may reference one vertex at two or three corners) |
| Arithmetic | coordinates quantized to a power-of-two grid; predicates exact in 64/128-bit integers |
| Degeneracy | symbolic perturbation by site rank (Simulation of Simplicity) |
| Insertion | Bowyer–Watson in the universal cover; direct star construction in the sparse regime |
| Deletion | local star removal + Delaunay-ear refill; $O(1)$ rebuild only for $n \le 3$ |
| Failure | `AddPoin` → `nil`, `DeletePoin` → `False`, nothing modified |

Two design consequences distinguish this model from the covering-space approach [2] and from the two-phase quotient-space approach [3]:

- The minimal representation is never left. There is no "simpliciality is now guaranteed, switch representation" transition, and no periodic re-wrapping pass, because lattice offsets are normalised at face creation (§2.3).
- Deletion is a genuinely local operation on the torus, not a rebuild. Measured over 200 uniform random sites deleted one by one, the local path is taken 197 times out of 200; the remaining 3 are the trailing $n \le 3$ cases.

## 2. Mathematical Background

### 2.1 Periodic Delaunay triangulation

Let $\Lambda = L\mathbb{Z}^2$ be the lattice, $\mathbb{T}^2 = \mathbb{R}^2/\Lambda$ the flat torus, and $S \subset [0,L)^2$ the set of $n$ sites. The input to the Delaunay construction is the infinite, $\Lambda$-periodic point set

```math
\widetilde{S} = S + \Lambda = \{\, s + \lambda \;:\; s \in S,\ \lambda \in \Lambda \,\} .
\qquad \text{(2.1)}
```

$\mathrm{Del}(\widetilde S)$ is a locally finite, $\Lambda$-invariant triangulation of $\mathbb{R}^2$, and the object of interest is the quotient $\mathrm{Del}(\widetilde S)/\Lambda$, a triangulation of $\mathbb{T}^2$ [2]. A simplex of $\mathrm{Del}(\widetilde S)$ and all of its $\Lambda$-translates project to one and the same simplex of the quotient.

### 2.2 Minimal representation and the $\Delta$-complex

Since $\chi(\mathbb{T}^2) = 0$, the quotient satisfies $V - E + F = 0$; each face has three edges and each edge two faces, so $2E = 3F$ and

```math
V = n, \qquad E = 3n, \qquad F = 2n
\qquad \text{(2.2)}
```

for **every** $n \ge 1$. In particular $n = 1$ gives a valid triangulation of one vertex and two faces — the square $[0,L)^2$ cut into two positively oriented triangles, whose corners all reference the same vertex instance under different lattice offsets (`SeedTwo`).

The quotient is a simplicial complex only when no simplex has two vertices that are translates of one another; that fails whenever the sites are sparse relative to $L$. The covering-space method [2] avoids the situation by triangulating a $3 \times 3$ (in 3D, $3^3$) copy of the domain; the two-phase method [3] inserts directly in the quotient only after simpliciality is guaranteed. This model instead hosts the $\Delta$-complex directly: the TriFlip connectivity (`Poin` / `Face` / `Corn`) navigates by corner indices and never by vertex identity, so a face may reference one vertex instance at two or three of its corners with no special case. TriFlip itself is used unmodified; only the lattice offsets and the lifted geometry are added by the derived classes.

### 2.3 Lattice offsets and canonicalisation

Vertex coordinates are always canonical, $\mathrm{Pos} \in [0,L)^2$. Each face stores a per-corner lattice offset $o_K \in \{0,1,2\}^2$ (two bits per axis in `_Offs`), and the geometric position of corner $K$ in that face's own lift is

```math
\mathrm{CornPos}(K) = \mathrm{Poin}[K].\mathrm{Pos} + L \cdot o_K .
\qquad \text{(2.3)}
```

Each face thus carries its own lift into the universal cover; the lifts of two adjacent faces differ by a lattice vector, obtained from `NeigShift` (which is resolved through corner indices, never through vertex identity). At face creation `NewFaceG` subtracts the per-axis minimum,

```math
o_K \;\longleftarrow\; o_K - \min_{J} o_J \quad \text{(componentwise)} ,
\qquad \text{(2.4)}
```

so every face lift is normalised to touch the fundamental domain. This is what makes an unbounded drift of the stored entities away from the fundamental domain impossible in principle, and it is why no periodic "re-wrapping pass" is ever needed.

**Offsets fit in two bits.** Any empty circle on $\mathbb{T}^2$ must avoid the lattice copies of at least one site, so its radius is bounded by the circumradius of half of the fundamental square:

```math
r \le \frac{L}{\sqrt{2}}, \qquad \text{hence} \qquad \mathrm{diam} \le \sqrt{2}\,L < 2L .
\qquad \text{(2.5)}
```

A face is inscribed in its circumcircle, so its axis-aligned extent is below $2L$, and after the normalisation (2.4) the offsets lie in $\{0,1,2\}$ — storable in two bits per axis.

### 2.4 Quantization and exact integer predicates

`Size` is snapped to a power-of-two grid: with $q = 2^{E-17}$ chosen so that

```math
K = L/q \in [\,2^{16},\, 2^{17}\,] ,
\qquad \text{(2.6)}
```

both $L$ and every site coordinate become integer multiples of $q$. The relative quantization error is at most $1/K \le 2^{-16}$, i.e. about $L \cdot 2^{-16}$ in absolute terms — invisible in practice.

All geometry therefore lives on an integer grid, and the predicates are evaluated **exactly**. With offsets in $\{0,1,2\}$ and $K \le 2^{17}$, grid coordinate differences within a lift satisfy $|\Delta| < 2^{21}$, so

```math
\mathrm{Orient}(Q,U,V) = (U_x - Q_x)(V_y - Q_y) - (U_y - Q_y)(V_x - Q_x),
\qquad |\mathrm{Orient}| < 2^{43},
\qquad \text{(2.7)}
```

fits in `Int64`, while the in-circle determinant

```math
\mathrm{InCircle}(A,B,C;Q) =
\begin{vmatrix}
X_1 & Y_1 & X_1^2 + Y_1^2 \\
X_2 & Y_2 & X_2^2 + Y_2^2 \\
X_3 & Y_3 & X_3^2 + Y_3^2
\end{vmatrix},
\qquad (X_i, Y_i) = \cdot_i - Q ,
\qquad \text{(2.8)}
```

is of degree 4 and needs about 85 bits; it is accumulated in a 128-bit integer (`TInt128` / `Acc128` / `Sign128`) and its sign read off exactly. Predicate misclassification by floating-point rounding — the root cause of structural corruption in degenerate configurations — therefore cannot occur.

### 2.5 Symbolic perturbation by site rank

Cocircular degeneracies, where (2.8) vanishes, are resolved by Simulation of Simplicity [4]: each site of rank $r$ is regarded as lifted by an infinitesimal $\delta^{r}$, which is equivalent to an infinitesimally weighted (regular) Delaunay triangulation. The sign is then that of the first non-vanishing cofactor in rank order,

```math
\mathrm{sign} \sum_{i \,:\, r_i = r} \frac{\partial \det}{\partial z_i}
\quad \text{for the smallest } r \text{ with a non-zero sum} ,
\qquad \text{(2.9)}
```

the cofactors $\partial\det/\partial z_i$ being the orientation determinants of the remaining three points (`InCirclePert`).

The perturbation is a function of the **site**, hence shared by all lattice images of that site, hence $\Lambda$-equivariant. This is what makes it usable on the quotient: it also resolves the *structural* cocircularities that arise from translate pairs $(w,\, w + L e)$ of one and the same vertex, which no per-instance perturbation could handle consistently. Cofactors of equal rank are summed before the sign is taken, exactly because the periodic images of one site share a rank. Only super-degeneracies that remain unresolved — four collinear grid points, or exactly symmetric grid configurations in the sparse regime — return 0 and are rejected.

### 2.6 Insertion in the universal cover

Fix one lift $\hat p$ of the new site $p$. The cavity is collected by breadth-first search in the universal cover, its elements being pairs (face instance × lattice translation); the *same* face instance may legitimately enter twice under different translations, when its circumdisk contains several periodic images of $p$. Visited-state is therefore keyed on (face, translation), not on the face alone.

- **Normal case.** If $p$ is not Delaunay-adjacent to its own periodic images — verified exactly — the ordinary Bowyer–Watson cone is correct: one face $(A, p, B)$ per cavity boundary edge. Validity is confirmed by checking exactly that no cone face's circumcircle contains a periodic image of $p$. The new faces are sewn to each other by scanning `CanWeld`, exactly as in the planar library — except that in the universal cover two lifts share the same vertex instance, so `TPeriFace2D.CanWeld` additionally requires the **lattice displacement of the edge** to match in mirror.
- **Sparse case.** Otherwise $p$ is adjacent to its own images and faces with a self-edge $p$–$p$ are required, so a cone is not correct. The **star of $\hat p$ is then built directly by gift wrapping** over a candidate set — the hole-boundary vertices, their translates, and the lattice images of $p$. Projecting the fan to the torus can make one face appear twice, so faces are identified by a rotation- and translation-normalised key, and every adjacency is resolved geometrically (the third vertex on the other side of an edge). The counter `StarInsN` records how often this path was taken.

In both cases the mesh is touched only after the full plan validates; a detected cocircular tie destroys nothing and `AddPoin` returns `nil`.

### 2.7 Deletion by local star removal

The star around one lift $\hat v$ of the vertex is collected by corner rotation, the hole boundary polygon is extracted in lift coordinates, and the hole is filled with **Delaunay ears** — ears whose circumcircle contains no other link vertex *and no translate of one*. Sewing proceeds in two stages: first by exact coordinate coincidence in the lift, then, for boundary edges whose outside also disappears, by determining the neighbouring hole's lattice translation $\mu$ geometrically so that fill faces can be sewn to each other. This is the case where the hole wraps around the torus and meets its own translate.

The fill is planned and validated in full before the mesh is touched; on a degenerate failure **nothing is modified and `False` is returned**, the same convention as the planar library. Only $n \le 3$ is handled by an $O(1)$ rebuild from the site list, the analogue of the planar version's small-count special cases. The counters `LocalDelN` and `RebuildDelN` record the two paths.

### 2.8 Queries

Point location is jump & walk with cumulative lattice translations and exact predicates, with a full-scan fallback for degenerate cases. `FindNearPoin` returns the nearest site under the **torus metric**

```math
d_{\mathbb{T}}(a,b)^2 = \min_{\lambda \in \Lambda} \lVert a - b + \lambda \rVert^2
\qquad \text{(2.10)}
```

(`TorusDist2`). Since there is no point at infinity on a compact quotient, every face has a finite circumcircle and `FindMaxCircle` ranges over all faces.

## 3. Architecture

### 3.1 Class diagram

```
Inheritance

・TTriPoin2D<TPeriFace2D>                      ：(LUX)
  ┗・TPeriPoin2D
     ┗・Site

・TTriPoinSet2D<TPeriPoin2D>                   ：(LUX)
  ┗・TPeriPoinSet2D

・TTriFace2D<TPeriPoin2D,TPeriFace2D>          ：(LUX)
  ┗・TPeriFace2D
     ┣・Off[1..3]                             ：lattice offsets
     ┣・CornGrid / CornPos
     ┣・CircumD / CircumPos / CircumRadius
     ┗・NeigShift

・TTriFaceSet2D<TPeriFace2D,TPeriPoinSet2D>    ：(LUX)
  ┗・TPeriFaceSet2D
     ┗・TPeriDelaunay2D

・TFrame                                       ：(FMX)
  ┗・TPeriDelaunayViewer

・TCGLayer                                     ：(LUX.CG2D)
  ┣・TPeriDelaunayTrias
  ┣・TPeriDelaunayCircs
  ┣・TPeriDelaunayVolos
  ┣・TPeriDelaunayGrids
  ┗・TPeriDelaunayPoins

Ownership and references

・TPeriDelaunay2D                              ：( = TPeriFaceSet2D = the faces )
  ┣・Poins     :TPeriPoinSet2D
  ┃  ┗・1..1 TPeriPoin2D                     ：1:1 with sites
  ┃     ┣・Pos                               ：canonical, on grid
  ┃     ┗・Site                              ：index
  ┣・Faces     :TPeriFaceSet2D                ：( = Self )
  ┃  ┗・2n TPeriFace2D
  ┃     ┣・Poin[1..3]                        ：may repeat
  ┃     ┣・Off [1..3]                        ：∈ {0,1,2}²
  ┃     ┗・Face[1..3], Corn[1..3]
  ┣・Size      :Single                        ：L, snapped to the grid
  ┣・Site[]    :TSingle2D                     ：canonical site coords
  ┣・SitePoin[]:TPeriPoin2D
  ┣・LocalDelN / RebuildDelN / StarInsN       ：statistics
  ┗・OnChange  :TDelegates                    ：notifies the viewer

・TPeriDelaunayViewer
  ┗・Layers :TCGLayers                        ：creation order = drawing order (bottom to top)
     ┣・Trias (copies)                        ：bottom
     ┣・Trias (core)
     ┣・Circs
     ┣・Grids
     ┣・Volos
     ┣・Poins (copies)
     ┣・Poins (core)                          ：top
     ┗・TCGCamera layer
```

### 3.2 File layout

```
・D2/Periodic/
  ┣・LUX.Delaunay.D2.Periodic.pas                              ：unit LUX.Delaunay.D2.Periodic
  ┃  ┣・TInt128 / Acc128 / Sign128                            ：128-bit accumulation for the exact in-circle test
  ┃  ┣・OrientG / InCircleSign / InCirclePert                 ：exact integer predicates + site-rank SoS
  ┃  ┣・TPeriPoin2D                                           ：vertex, 1:1 with sites (Site)
  ┃  ┣・TPeriPoinSet2D                                        ：vertex set
  ┃  ┣・TPeriFace2D                                           ：triangle: per-corner offsets, lifted geometry
  ┃  ┣・TPeriFaceSet2D                                        ：face set
  ┃  ┗・TPeriDelaunay2D                                       ：the model: AddPoin / DeletePoin / queries
  ┣・LUX.Delaunay.D2.Periodic.Viewer.pas / .fmx                ：unit LUX.Delaunay.D2.Periodic.Viewer
  ┃  ┣・TPeriDelaunayTrias / Circs / Volos / Grids / Poins    ：scene layers on the LUX.CG2D scene graph
  ┃  ┗・TPeriDelaunayViewer                                   ：the TFrame
  ┣・README.md                                                 ：this document
  ┗・ja/README.md                                              ：Japanese translation
```

Built on the same TriFlip mesh layers of [LUX](https://github.com/LUXOPHIA/LUX) as the planar model (`LUX.Data.Model.TriFlip.core`, `LUX.Data.Model.TriFlip.D2`), which own the points and faces and provide the connectivity, the corner tables (`VertTableInc` / `VertTableDec`) and the iteration.

### 3.3 Class reference — `LUX.Delaunay.D2.Periodic`

#### `TPeriPoin2D` — vertex

| Member | Description |
|---|---|
| `Pos :TSingle2D` | Canonical coordinates, $\in [0,L)^2$ and on the grid. *(inherited)* |
| `Face :TPeriFace2D` / `Corn :Byte` | Anchor: one face containing this vertex, and its corner number in it. *(inherited)* |
| `Site :Integer` | Site index — the subscript into `TPeriDelaunay2D.Site[]`. |

#### `TPeriFace2D` — triangle

| Member | Description |
|---|---|
| `Poin[1..3] :TPeriPoin2D` | Vertices, counter-clockwise. The same instance may appear at two or three corners. *(inherited)* |
| `Face[1..3] :TPeriFace2D` / `Corn[1..3] :Byte` | Neighbour across the edge opposite corner `K`, and its corner number. *(inherited)* |
| `Model :TPeriDelaunay2D` | The owning model (alias of `Parent`). |
| `Off[ I ] :TPoint` | Lattice offset of corner `I`, $\in \{0,1,2\}^2$, normalised by (2.4). |
| `CornGrid( I ) :TPoint` | Grid coordinates of corner `I` in this face's own lift, in units of $q$ — exact. |
| `CornPos( I ) :TSingle2D` | Geometric position (2.3) of corner `I` in this face's own lift; exact, since it lies on the grid. |
| `CircumD( out Center_, out Radius2_ )` | Circumcenter, in this face's lift, and the squared radius, in `Double`. |
| `CircumPos :TSingle2D` / `CircumRadius :Single` | The same as single-precision scalars. |
| `NeigShift( I ) :TSingle2D` | The translation carrying the lift of `Face[I]` into this face's lift. Resolved by corner indices, never by vertex identity. |

#### `TPeriPoinSet2D` / `TPeriFaceSet2D` — sets

Iterable containers (`for F in …`, `Count`, `[I]`). `TPeriFaceSet2D.Poins` is the vertex set; on the torus every vertex is finite and in bijection with a site.

#### `TPeriDelaunay2D` — the diagram

| Member | Description |
|---|---|
| `Create` / `Destroy` | The empty diagram; owns its point set. |
| `Faces :TPeriFaceSet2D` | All faces — the faces of the torus themselves, always exactly $2n$ (alias of the object itself). |
| `Size :Single` | The side $L$ of the fundamental domain. Assigning snaps $L$ to the power-of-two grid (2.6), re-wraps the sites and rebuilds. |
| `SitesN :Integer` | The number of sites. |
| `Site[ I ] :TSingle2D` | Canonical coordinates of site `I`, $\in [0,L)^2$. |
| `SitePoin[ I ] :TPeriPoin2D` | The vertex of site `I`. |
| `OnChange :TDelegates` | Multicast notification fired after every structural change. Subscribe with `Add`, unsubscribe with `Del`. |
| `LocalDelN` / `RebuildDelN` / `StarInsN` | Statistics: local deletions, deletions that fell back to a rebuild, insertions that needed direct star construction. |
| `WrapPos( Pos_ ) :TSingle2D` | Map any coordinate to the canonical, on-grid representative in $[0,L)^2$. |
| `TorusDist2( A_, B_ ) :Single` | Squared torus distance (2.10) between two canonical coordinates. |
| `HitCircleFace( Pos_ ) :TPeriFace2D` | A face whose circumcircle contains `Pos_` — jump & walk with cumulative translations. |
| `FindMaxCircle :TPeriFace2D` | The face with the largest empty circle; `nil` if there is no face. All faces are eligible, since none has an infinite radius. |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | The vertex of the nearest site and its torus distance. |
| `AddPoin( Pos_ ) :TPeriPoin2D` | Insert a site (§2.6). The position is wrapped into the domain. `nil` for a non-finite coordinate, a duplicate, or an unresolvable super-degeneracy — with nothing modified. |
| `DeletePoin( Poin_ ) :Boolean` | Delete a site (§2.7). `False`, with nothing modified, on a degenerate configuration; $n \le 3$ is rebuilt in $O(1)$. |
| `TorusFaces :TArray<TPeriFace2D>` | All faces of the torus as an array (= the contents of `Faces`); for the viewer. |
| `Clear` | Remove all sites and faces. |
| `SaveToFile` / `LoadFromFile` | **Not supported** — sealed off with an exception, because the TriFlip format cannot store lattice offsets. |

### 3.4 Class reference — `LUX.Delaunay.D2.Periodic.Viewer`

A `TFrame` that renders a `TPeriDelaunay2D` through the [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) scene graph (Skia4Delphi), in the same style as the planar viewer and with no drawing code of its own. It subscribes to `OnChange` and rebuilds its scene automatically, deferred to just before the next paint.

The fundamental domain is placed centred on the origin, at $[-L/2, +L/2)^2$, and the faces of the torus are tiled over a fixed $3 \times 3$ block. A face instance is placed by the simple rule of wrapping its anchor (corner 1) back into the fundamental domain: making the central representatives form an edge-connected patch is in general impossible with any per-face local criterion (circumcenter, centroid, …), since choosing a connected fundamental domain is equivalent to choosing a spanning tree of the dual graph, so it is not attempted. The application sets `Camera.SizeX` / `SizeY` — $2L \times 2L$ shows the domain with a margin; the frame itself defaults to 400 × 400, and content outside the $3 \times 3$ block may become visible at extreme window aspect ratios.

#### `TPeriDelaunayViewer` — the frame

| Member | Description |
|---|---|
| `Delaunay :TPeriDelaunay2D` | The diagram to display. Assigning subscribes to `OnChange`; assign `nil` to unsubscribe (do this before freeing the diagram). |
| `Layers :TCGLayers` | The constructed scene. |
| `Camera :TCGCamera` | The view; `SizeX` / `SizeY` are the visible extent in model units. |
| `Poins` / `Trias` / `Circs` / `Volos` / `Grids` | The scene layers (below). Styles are set on these, the core layers. |
| `ScrToPos( S_ ) :TSingle2D` / `PosToScr( P_ ) :TPointF` | Convert between screen and world coordinates (the domain centre is the origin). |
| `ScrToTorus( S_ ) :TSingle2D` | Screen coordinates → canonical torus coordinates, $\in [0,L)^2$. |

#### Layers

Each layer is a `TCGLayer` with a `Style` (`FillColor` / `LineColor` / `LineThick`). Creation order is drawing order, from the bottom up.

| Layer | Shows |
|---|---|
| `TPeriDelaunayTrias` | The Delaunay triangles. Two instances: the central representatives, and the 8 surrounding copies. |
| `TPeriDelaunayCircs` | The empty circles — only those of the central representatives; the copies in the surrounding 8 tiles are not drawn. |
| `TPeriDelaunayGrids` | The periodic boundary lines: the $3 \times 3$ grid, 4 vertical and 4 horizontal. |
| `TPeriDelaunayVolos` | The Voronoi edges. |
| `TPeriDelaunayPoins` | The vertices (`Radius` in model units). Two instances: the central representatives, and the 8 surrounding copies. |

Styles are set on the core layers (`Viewer1.Poins.Style.FillColor`, …). The pale colour of the copy layers is derived from the core layer's current style — alpha halved — and copied into the dedicated copy layer's style on every rebuild. Style inheritance through an intermediate node is not used, because this scene graph does not propagate style to children.

## 4. Usage

### 4.1 Building and querying

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2.Periodic;

var
   D :TPeriDelaunay2D;
   V :TPeriPoin2D;
   F :TPeriFace2D;
   N :Integer;
begin
     D := TPeriDelaunay2D.Create;

     D.Size := 300;                                              // fundamental domain [0,300)²

     for N := 1 to 200 do                                        // insert (wrapped into the domain)
     begin
          D.AddPoin( TSingle2D.Create( 300 * Random, 300 * Random ) );
     end;

     for F in D.Faces do                                         // always exactly 2n faces
     begin
          { F.CornPos( 1 ) … F.CornPos( 3 ) span a triangle in F's own lift;
            F.CircumPos and F.CircumRadius are in the same lift;
            F.NeigShift( K ) carries the lift of F.Face[K] into F's lift }
     end;

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), V ) < 10       // nearest site, torus metric
     then D.DeletePoin( V );                                     // local deletion

     D.Free;
end;
```

Note that a vertex reference returned by `AddPoin` or `FindNearPoin` becomes invalid once that vertex is deleted — use it immediately.

### 4.2 Statistics

```pascal
Caption := Format( 'sites %d / faces %d — local %d, rebuild %d, star %d',
                   [ D.SitesN, D.Faces.Count, D.LocalDelN, D.RebuildDelN, D.StarInsN ] );
```

### 4.3 Viewer

Drop a `TPeriDelaunayViewer` on a form (or create it at run time with a `Parent`), then hand it the diagram.

```pascal
procedure TForm1.FormCreate(Sender: TObject);
begin
     _Delaunay := TPeriDelaunay2D.Create;

     _Delaunay.Size := 300;

     with Viewer1 do
     begin
          Delaunay := _Delaunay;

          with Camera do begin  SizeX := 600;  SizeY := 600;  end;   // 2L × 2L

          Poins.Style.FillColor := TAlphaColors.Red;
          Trias.Style.FillColor := TAlphaColors.Cornflowerblue;
          Circs.Style.LineColor := TAlphaColors.Lime;
          Volos.Style.LineColor := TAlphaColors.Black;
          Grids.Style.LineColor := TAlphaColors.Pink;
     end;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
     Viewer1.Delaunay := nil;  // unsubscribe before freeing the model

     _Delaunay.Free;
end;
```

All editing goes through the model — the viewer follows by itself. A minimal mouse interaction, using the torus-aware conversion:

```pascal
procedure TForm1.Viewer1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
   P :TSingle2D;
   V :TPeriPoin2D;
begin
     P := Viewer1.ScrToTorus( TPointF.Create( X, Y ) );   // → canonical coordinates

     if _Delaunay.FindNearPoin( P, V ) < 6
     then _Delaunay.DeletePoin( V )   // near an existing site → delete
     else _Delaunay.AddPoin   ( P );  // empty space          → insert
end;
```

## 5. Limitations

- The domain is a **square** torus (`Size` × `Size`); general lattices are not supported.
- Exactly cocircular configurations — symmetric arrangements on a grid, for instance — may cause an insertion to be rejected while the point set is sparse, i.e. while direct star construction (§2.6) is needed. Once the set is dense enough that the cone path applies, no rejection occurs.
- `SaveToFile` / `LoadFromFile` of the TriFlip container are sealed off, because the format cannot store lattice offsets.
- Vertex references returned by `AddPoin` / `FindNearPoin` are invalidated when that vertex is deleted.

## 6. References

1. Bowyer, A., [*Computing Dirichlet tessellations*](https://doi.org/10.1093/comjnl/24.2.162), The Computer Journal, 24(2), 162–166, 1981.
2. Caroli, M., Teillaud, M., [*Computing 3D periodic triangulations*](https://doi.org/10.1007/978-3-642-04128-0_6), ESA 2009, LNCS 5757, 59–70, 2009.
3. Osang, G., Rouxel-Labbé, M., Teillaud, M., [*Generalizing CGAL periodic Delaunay triangulations*](https://doi.org/10.4230/LIPIcs.ESA.2020.75), ESA 2020, LIPIcs 173, 75:1–75:17, 2020.
4. Edelsbrunner, H., Mücke, E. P., [*Simulation of simplicity: a technique to cope with degenerate cases in geometric algorithms*](https://doi.org/10.1145/77635.77639), ACM Transactions on Graphics, 9(1), 66–104, 1990.
5. Shewchuk, J. R., [*Adaptive precision floating-point arithmetic and fast robust geometric predicates*](https://doi.org/10.1007/PL00009321), Discrete & Computational Geometry, 18(3), 305–363, 1997.
6. Devillers, O., [*On deletion in Delaunay triangulations*](https://doi.org/10.1142/S0218195902000815), International Journal of Computational Geometry & Applications, 12(3), 193–205, 2002.
7. Mücke, E. P., Saias, I., Zhu, B., [*Fast randomized point location without preprocessing in two- and three-dimensional Delaunay triangulations*](https://doi.org/10.1016/S0925-7721(98)00035-2), Computational Geometry, 12(1–2), 63–83, 1999.
8. Caroli, M., Teillaud, M., [*Delaunay triangulations of closed Euclidean d-orbifolds*](https://doi.org/10.1007/s00454-016-9782-6), Discrete & Computational Geometry, 2016.
9. Delaunay, B., [*Sur la sphère vide*](https://www.mathnet.ru/eng/im4937), Bulletin de l'Académie des Sciences de l'URSS, 6, 793–800, 1934.

## 💖 [Embarcadero](https://www.embarcadero.com/) [**Delphi**](https://www.embarcadero.com/products/delphi)
Integrated Development Environment (IDE) for Creating Native Cross-Platform Apps.
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/products/delphi/starter)
