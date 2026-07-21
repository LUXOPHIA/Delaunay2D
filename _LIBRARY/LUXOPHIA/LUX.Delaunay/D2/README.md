# LUX.Delaunay.D2

**2D Delaunay triangulation for Delphi** — incremental insertion and deletion on a winged triangle mesh, with a Skia-based FMX viewer frame.

[English](README.md) | [日本語](ja/README.md)

The diagram is a set of triangles (*faces*) glued edge-to-edge. The outside of the convex hull is covered by faces that contain the single *point at infinity*, so every edge always has exactly two faces and every algorithm works without boundary cases. Vertex corners inside a face are numbered **1..3**, counter-clockwise.

---

## Classes — `LUX.Delaunay.D2`

Built on the TriFlip mesh layers of [LUX](https://github.com/LUXOPHIA/LUX) (`LUX.Data.Model.TriFlip.*`), which provide connectivity, ownership, and iteration. `LUX.Delaunay.D2` adds only what is Delaunay-specific.

### `TDelaPoin2D` — vertex

| Member | Description |
|---|---|
| `Pos :TSingle2D` | Coordinates. *(inherited)* |
| `Face :TDelaFace2D` / `Corn :Byte` | Anchor: one face containing this vertex and the corner number in it. *(inherited)* |
| `Inf :Boolean` | Whether this is the point at infinity. |
| `Lift( Pos_ ) :TDouble3D` | Lifted coordinates `( X, Y, X²+Y² )` relative to the base point `Pos_`. |
| `InCircled( P1_,P2_,P3_ ) :Double` | Sign of this point against the circle through `P1..P3` — positive = inside. |

### `TDelaPoin2DInf` — the point at infinity

Derived from `TDelaPoin2D`; overrides `Lift` (constant `( 0, 0, 1 )`) and `InCircled` (degenerates to the orientation of the circle). Exactly one instance exists per diagram (`TDelaunay2D.PoinInf`); it belongs to no point set and never appears in `Poins`.

### `TDelaFace2D` — triangle

| Member | Description |
|---|---|
| `Poin[1..3] :TDelaPoin2D` | Vertices, counter-clockwise. *(inherited)* |
| `Face[1..3] :TDelaFace2D` | Neighbor across the edge opposite vertex `K`. *(inherited)* |
| `Corn[1..3] :Byte` | The neighbor's corner number opposite the shared edge. *(inherited)* |
| `InfCorn :Byte` | Corner number of the infinite vertex — `0` means a finite face. |
| `Circum :TSingle3D` | Homogeneous circumcenter `( X, Y, W )`. Finite face → center is `( X/W, Y/W )`; infinite face → `W = 0` and `( X, Y )` is the outward direction of the dual Voronoi edge. |
| `InCircle( P1_,P2_,P3_, Pos_ ) :Double` *(class)* | Unified lift determinant — positive = `Pos_` inside the circle through `P1..P3`. |
| `IsHitCircle( Pos_ ) :Boolean` | Whether `Pos_` lies inside this face's circumcircle. |

### `TDelaPoinSet2D` / `TDelaFaceSet2D` — sets

Iterable containers (`for P in …`, `Count`, `[I]`). `TDelaFaceSet2D.Poins` exposes the **finite** vertices.

### `TDelaunay2D` — the diagram

| Member | Description |
|---|---|
| `Create` / `Destroy` | The empty diagram owns its point set and the point at infinity. |
| `PoinInf :TDelaPoin2D` | The unique point at infinity. |
| `Faces :TDelaFaceSet2D` | All faces, infinite ones included (alias of the object itself). |
| `Poins :TDelaPoinSet2D` | All finite vertices. |
| `OnChange :TDelegates` | Multicast notification, fired after every structural change. Subscribe with `Add`, unsubscribe with `Del`. |
| `HitCircleFace( Pos_ ) :TDelaFace2D` | A face whose circumcircle contains `Pos_` — jump & walk, expected O(n^1/3). |
| `FindNearPoin( Pos_, out Poin_ ) :Single` | The nearest vertex and the distance to it (locate + greedy descent). `Poin_ = nil` and `Infinity` when the diagram is empty. |
| `AddPoin( Pos_ ) :TDelaPoin2D` | Insert a point (Bowyer–Watson), or `nil` when it cannot be inserted (duplicate / degenerate position). Overload `AddPoin( Pos_, Face_ )` skips the search when the containing face is already known. |
| `DeletePoin( Poin_ ) :Boolean` | Remove a vertex — its star is deleted and the hole is refilled deterministically from a small Delaunay diagram of the link. `False`, with nothing modified, for invalid input or a degenerate configuration that cannot be refilled. |
| `Clear` | Remove all points and faces (`PoinInf` survives). |

---

## Classes — `LUX.Delaunay.D2.Viewer`

A `TFrame` that renders a `TDelaunay2D` with the [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) scene graph (Skia4Delphi). It subscribes to `OnChange` and rebuilds its scene automatically, deferred to the next paint.

### `TDelaunayViewer` — the frame

| Member | Description |
|---|---|
| `Delaunay :TDelaunay2D` | The diagram to display. Setting it subscribes to `OnChange`; set to `nil` to unsubscribe (do this before freeing the diagram). |
| `Camera :TCGCamera` | The view: `SizeX` / `SizeY` set the visible extent in model units. |
| `Poins` / `Trias` / `Circs` / `Volos` | The scene layers (below). |
| `ScrToPos( S_ ) :TSingle2D` / `PosToScr( P_ ) :TPointF` | Convert between screen and model coordinates. |

### Layers

Each layer is a `TCGLayer` with a `Style` (`FillColor` / `LineColor` / `LineThick`); changing a style repaints automatically.

| Layer | Shows |
|---|---|
| `TDelaunayTrias` | The Delaunay triangles. |
| `TDelaunayCircs` | The circumcircles. |
| `TDelaunayVolos` | The Voronoi diagram (unbounded edges as outward rays). |
| `TDelaunayPoins` | The vertices (`Radius` in model units). |

---

## Usage

### Building and querying

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2;

var
   D :TDelaunay2D;
   P :TDelaPoin2D;
   F :TDelaFace2D;
   N :Integer;
begin
     D := TDelaunay2D.Create;

     for N := 1 to 100 do D.AddPoin( 100 * TSingle2D.RandG );  // insert

     for F in D.Faces do                                       // enumerate triangles
     begin
          if F.InfCorn = 0 then { F.Poin[1..3] span a finite triangle };
     end;

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), P ) < 10    // nearest vertex and its distance
     then D.DeletePoin( P );                                   // delete

     D.Free;
end;
```

### Extracting the Voronoi diagram

Voronoi vertices are the circumcenters of finite faces; each Voronoi edge is dual to a Delaunay edge and connects the circumcenters of the two incident faces. `Circum` handles bounded and unbounded edges with the same expression:

```pascal
for F in D.Faces do
begin
     if F.InfCorn > 0 then Continue;                     // Voronoi vertices sit on finite faces

     C0 := F.Circum;  P0 := TSingle2D.Create( C0.X, C0.Y ) / C0.W;

     for K := 1 to 3 do
     begin
          C1 := F.Face[ K ].Circum;

          if C1.W > 0
          then P1 := TSingle2D.Create( C1.X, C1.Y ) / C1.W                    // segment to the neighbor center
          else P1 := P0 + RayLength * TSingle2D.Create( C1.X, C1.Y ).Unitor;  // outward ray of a hull edge

          // draw P0 – P1  (interior edges are visited from both sides;
          // draw to the midpoint, or keep only F < F.Face[K], to avoid duplicates)
     end;
end;
```

### Viewer

Drop a `TDelaunayViewer` on a form (or create it at runtime with a `Parent`), then hand it the diagram:

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

## License

[MIT License](../LICENSE) © LUXOPHIA
