# LUX.Delaunay.D3

**3D Delaunay tetrahedralization for Delphi** — incremental insertion and deletion on a flip-based tetrahedral mesh, with an FMX 3D viewer frame that renders polygonized Delaunay and Voronoi edges.

[English](README.md) | [日本語](ja/README.md)

The diagram is a set of tetrahedra (*cells*) glued face-to-face. The outside of the convex hull is covered by cells that contain the single *point at infinity*, so every face always has exactly two cells and every algorithm works without boundary cases. Vertex corners inside a cell are numbered **0..3**; all cells are kept positively oriented.

---

## Classes — `LUX.Delaunay.D3`

Built on the TetraFlip mesh layers of [LUX](https://github.com/LUXOPHIA/LUX) (`LUX.Data.Model.TetraFlip.*`), which provide connectivity, face gluing (`Weld`), ownership, and iteration. `LUX.Delaunay.D3` adds only what is Delaunay-specific.

### `TDelaPoin3D` — vertex

| Member | Description |
|---|---|
| `Pos :TSingle3D` | Coordinates. *(inherited)* |
| `Cell :TDelaCell3D` / `Corn :Byte` | Anchor: one cell containing this vertex and the corner number in it. *(inherited)* |
| `Inf :Boolean` | Whether this is the point at infinity. |
| `Lift( Pos_ ) :TDouble4D` | Lifted coordinates `( X, Y, Z, X²+Y²+Z² )` relative to the base point `Pos_`, in double precision. |
| `InSphered( P0_,P1_,P2_,P3_ ) :Double` | Sign of this point against the sphere through `P0..P3` — positive = inside. |

### `TDelaPoin3DInf` — the point at infinity

Derived from `TDelaPoin3D`; overrides `Lift` (constant `( 0, 0, 0, 1 )`) and `InSphered` (degenerates to the orientation of the sphere). Exactly one instance exists per diagram (`TDelaunay3D.PoinInf`); it belongs to no point set and never appears in `Poins`.

### `TDelaCell3D` — tetrahedron

| Member | Description |
|---|---|
| `Poin[0..3] :TDelaPoin3D` | Vertices, positively oriented. *(inherited)* |
| `Cell[0..3] :TDelaCell3D` | Neighbor across the face opposite vertex `K`. *(inherited)* |
| `Corn[0..3] :Byte` | The neighbor's corner number opposite the shared face. *(inherited)* |
| `Bond[0..3] :Byte` | Rotation code of the shared-face gluing. *(inherited)* |
| `Join[K,I] :Byte` | Vertex correspondence across face `K`: frame position `I` on this side → corner number in the neighbor. *(inherited)* |
| `InfCorn :Shortint` | Corner number of the infinite vertex — `-1` means a finite cell. |
| `Circum :TSingle4D` | Homogeneous circumcenter `( X, Y, Z, W )`. Finite cell → center is `( X/W, Y/W, Z/W )`; infinite cell → `W = 0` and `( X, Y, Z )` is the outward direction of the dual Voronoi edge. |
| `InSphere( P0_..P3_, Pos_ ) :Double` *(class)* | Unified lift determinant — positive = `Pos_` inside the sphere through `P0..P3`. |
| `IsHitSphere( Pos_ ) :Boolean` | Whether `Pos_` lies inside this cell's circumsphere. |

### `TDelaPoinSet3D` / `TDelaCellSet3D` — sets

Iterable containers (`for C in …`, `Count`, `[I]`). `TDelaCellSet3D.Poins` exposes the **finite** vertices.

### `TDelaunay3D` — the diagram

| Member | Description |
|---|---|
| `Create` / `Destroy` | The empty diagram owns its point set and the point at infinity. |
| `PoinInf :TDelaPoin3D` | The unique point at infinity. |
| `Cells :TDelaCellSet3D` | All cells, infinite ones included (alias of the object itself). |
| `Poins :TDelaPoinSet3D` | All finite vertices. |
| `OnChange :TDelegates` | Multicast notification, fired after every structural change. Subscribe with `Add`, unsubscribe with `Del`. |
| `HitSphereCell( Pos_ ) :TDelaCell3D` | A cell whose circumsphere contains `Pos_` — jump & walk, expected O(n^1/4). |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | The nearest vertex and the distance to it (locate + greedy descent). `Poin_ = nil` and `Infinity` when the diagram is empty. |
| `AddPoin( Pos_ ) :TDelaPoin3D` | Insert a point (Bowyer–Watson), or `nil` when it cannot be inserted (duplicate, a 3rd point collinear with the first two, or a degenerate position). Overload `AddPoin( Pos_, Cell_ )` skips the search when a containing cell is already known. |
| `DeletePoin( Poin_ ) :Boolean` | Remove a vertex — its star is deleted and the hole is refilled deterministically from a small Delaunay diagram of the link (see below). `False`, with nothing modified, for invalid input or a degenerate configuration that cannot be refilled. |
| `Clear` | Remove all points and cells (`PoinInf` survives). |
| `SaveToFile( FileName_ )` | Save the diagram to a `*.lxtc` file — coordinates and the complete connectivity (vertices, neighbors, corner / rotation codes), so the structure round-trips exactly. |
| `LoadFromFile( FileName_ )` | Restore a diagram from a `*.lxtc` file. The current content is replaced entirely; the point at infinity is re-linked, and `OnChange` fires once. |

**File format `*.lxtc`** — Radiance-HDR-style: the file starts as UTF-8 text — first line is the magic `LUXOPHIA TetFlip 1.0`, followed by any number of `name=value` option lines (`PoinsN`, `CellsN`, `PosSize`; unknown lines are skipped) — then a single blank line, and everything after it is binary: the point coordinates, then per cell its 4 vertex indices, 4 neighbor-cell indices (`Int32`; `-1` = nil, `-2` = the point at infinity) and the `Corn` / `Bond` / `Flag` bytes.

---

## Classes — `LUX.Delaunay.D3.Viewer`

A `TFrame` that renders a `TDelaunay3D` in an internal `TViewport3D`. It subscribes to `OnChange` and rebuilds its scene automatically, deferred to the next paint. No curved geometry is used: Delaunay edges and Voronoi edges are assembled from flat faces cut back from the edges by a margin, so the flat shading shows the structure of the diagram as crisp polygonal solids.

### `TDelaunayViewer` — the frame

| Member | Description |
|---|---|
| `Delaunay :TDelaunay3D` | The diagram to display. Setting it subscribes to `OnChange`; set to `nil` to unsubscribe (do this before freeing the diagram). |
| `Camera :TCamera` | The camera at the tip of the built-in orbit rig (yaw → pitch → camera, with a headlight). |
| `Color :TAlphaColor` | Background color. |
| `Distance :Single` | Camera distance from the origin. |
| `Edges :TDelaunayEdges` | The Delaunay-edge layer (below). |
| `Voros :TDelaunayVoros` | The Voronoi-edge layer (below). |
| `Orbit( DYaw_, DPitch_ )` | Rotate the orbit rig, in degrees. |
| `Dolly( DDistance_ )` | Change the camera distance. |
| `FindPoin( Scr_, Radius_ ) :TDelaPoin3D` | The vertex nearest to a screen point (within `Radius_` pixels), or `nil` — for picking. |

### `TDelaunayEdges` — Delaunay edges

For every face of every finite cell, the triangle's corners are cut back by `MarginCorner` (a point on the angle bisector at distance `Margin` from both edges, clamped by the inradius), leaving a flat frame along the edges. Around each Delaunay edge the frames of the cells in its ring join into a closed polygonal tube; convex-hull faces get an outer frame that closes the tube from outside.

| Member | Description |
|---|---|
| `Color :TAlphaColor` | Material color. |
| `Margin :Single` | Width of the frame, measured from the edge. |

### `TDelaunayVoros` — Voronoi edges

Every finite cell's circumcenter is a Voronoi vertex. Around it, corner triangles form a small shell between the four edge directions; toward each finite neighbor half a triangular prism is spanned (the two halves meet to form one prism per Voronoi edge), and unbounded edges are closed by a cone of length `RayLength`. Edge directions come from the neighbors' homogeneous circumcenters — finite neighbor → toward its center, infinite neighbor → the outward `W = 0` direction — with no case analysis in the geometry itself.

| Member | Description |
|---|---|
| `Color :TAlphaColor` | Material color. |
| `Margin :Single` | Distance from the Voronoi edge to the prism faces. |
| `RayLength :Single` | Length of the cones on unbounded edges. |

---

## Usage

### Building and querying

```pascal
uses LUX, LUX.D3, LUX.D4, LUX.Delaunay.D3;

var
   D :TDelaunay3D;
   P :TDelaPoin3D;
   C :TDelaCell3D;
   N :Integer;
begin
     D := TDelaunay3D.Create;

     for N := 1 to 100 do D.AddPoin( 2 * TSingle3D.RandG );  // insert

     for C in D.Cells do                                     // enumerate tetrahedra
     begin
          if C.InfCorn < 0 then { C.Poin[0..3] span a finite tetrahedron };
     end;

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1  // nearest vertex and its distance
     then D.DeletePoin( P );                                  // delete

     D.Free;
end;
```

### Extracting the Voronoi diagram

Voronoi vertices are the circumcenters of finite cells; each Voronoi edge is dual to a Delaunay face and connects the circumcenters of the two incident cells. `Circum` handles bounded and unbounded edges with the same expression:

```pascal
for C in D.Cells do
begin
     if C.InfCorn >= 0 then Continue;                    // Voronoi vertices sit on finite cells

     V0 := C.Circum;  P0 := TSingle3D.Create( V0.X, V0.Y, V0.Z ) / V0.W;

     for K := 0 to 3 do
     begin
          V1 := C.Cell[ K ].Circum;

          if V1.W > 0
          then P1 := TSingle3D.Create( V1.X, V1.Y, V1.Z ) / V1.W                    // segment to the neighbor center
          else P1 := P0 + RayLength * TSingle3D.Create( V1.X, V1.Y, V1.Z ).Unitor;  // outward ray of a hull face

          // draw P0 – P1  (interior edges are visited from both sides;
          // draw to the midpoint, or keep only C < C.Cell[K], to avoid duplicates)
     end;
end;
```

### Viewer

Drop a `TDelaunayViewer` on a form (or create it at runtime with a `Parent`), then hand it the diagram:

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

All editing goes through the model — the viewer follows by itself. Mouse interaction stays in the application; the frame only offers `Orbit` / `Dolly` / `FindPoin`:

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

---

## Algorithm notes

- **Insertion** is Bowyer–Watson in two phases: ① *mark* — the cells whose circumspheres contain the new point (the cavity) are collected by a flag-marking flood; marking is idempotent, so even though the cavity's dual is not a tree in 3D, reaching a cell along several paths causes no double processing. ② *carve* — a new cell is spanned on every boundary face and welded to the outside and to its neighbors around the new point; only then are the marked cells freed, so re-entry into a removed cell cannot occur by construction. No placeholders, no recursion.
- **Deletion** removes the vertex star, which opens a star-shaped hole, and refills it deterministically: a small Delaunay diagram of just the link vertices is built by incremental insertion as an independent component inside the same cell set (no nested `TDelaunay3D`), the cells that fill the hole are cut out of it — the cells whose faces match the hole boundary in mirror orientation (`CanWeld`), plus everything reachable from them without crossing the boundary — and sewn onto the rim (`Weld`). Every step is a combinatorial check with no flip search; if any check fails on a degenerate configuration, the original diagram is left untouched and `DeletePoin` returns `False`.
- **Predicates**: a single lift determinant decides in-sphere, orientation, and the walk direction; operands are translated to a nearby base point and evaluated in double precision.

## License

[MIT License](../LICENSE) © LUXOPHIA
