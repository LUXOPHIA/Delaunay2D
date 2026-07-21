# LUX.Delaunay

**Delaunay diagram library for Delphi** — 2D triangulations and 3D tetrahedralizations with both point *insertion* and *deletion*, plus drop-in FireMonkey viewer frames.

[English](README.md) | [日本語](ja/README.md)

## Features

- **2D and 3D** — `D2/` builds Delaunay triangulations on a winged triangle mesh (TriFlip), `D3/` builds Delaunay tetrahedralizations on a flip-based tetrahedral mesh (TetraFlip).
- **Fully dynamic** — points can be added (Bowyer–Watson) and removed at any time. Removal deletes the vertex star and refills the hole deterministically: a small Delaunay diagram of the link vertices is built inside the same set and sewn into the boundary — no flip search. The structure is a valid Delaunay diagram after every operation; on degenerate input, `AddPoin` returns `nil` and `DeletePoin` returns `False` without touching anything.
- **Infinite vertex, no super-simplex** — the outside of the convex hull is covered by cells that share a single point at infinity. There is no bounding box to size and no coordinate limit to respect, and hull points are inserted and deleted by the same code path as interior points.
- **Unified predicates** — the in-circle / in-sphere test is a single lift determinant. The point at infinity substitutes its own lift by polymorphism, so finite points and the infinite point, spheres and planes (spheres of infinite radius) all flow through one expression with no case analysis. Every determinant is evaluated in double precision after translating the operands to a nearby base point, so the predicates stay reliable far from the origin.
- **Homogeneous circumcenters** — `Circum` returns the circumcenter in homogeneous coordinates. For cells at infinity it degenerates naturally to `W = 0`, where `(X, Y[, Z])` is the outward direction of the unbounded Voronoi edge. The entire Voronoi diagram, rays included, falls out of one formula with no branches and no divisions.
- **Fast queries** — point location and nearest-point search by jump & walk: expected O(n^1/3) in 2D and O(n^1/4) in 3D, uniform over the domain.
- **Viewers** — FMX `TFrame`s that subscribe to the diagram and rebuild their scene automatically: a Skia scene-graph viewer in 2D, and a Viewport3D viewer in 3D that renders the Delaunay and Voronoi edges as polygonal solids.

## Directory

| Path | Contents |
|---|---|
| `D2/LUX.Delaunay.D2.pas` | 2D Delaunay diagram (`TDelaunay2D`) |
| `D2/LUX.Delaunay.D2.Viewer.pas/.fmx` | 2D viewer frame (`TDelaunayViewer`) |
| `D3/LUX.Delaunay.D3.pas` | 3D Delaunay diagram (`TDelaunay3D`) |
| `D3/LUX.Delaunay.D3.Viewer.pas/.fmx` | 3D viewer frame (`TDelaunayViewer`) |

See **[D2/README.md](D2/README.md)** and **[D3/README.md](D3/README.md)** for the class reference and detailed usage.

## Dependencies

- [LUX](https://github.com/LUXOPHIA/LUX) — base library: vectors (`LUX.D2` … `LUX.D4`), lists, and the TriFlip / TetraFlip mesh models (`LUX.Data.Model.*`).
- [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) — 2D scene graph on Skia4Delphi. Required by the **2D viewer** only.
- Delphi with FireMonkey. The core units are plain Object Pascal; the 2D viewer needs a Skia-enabled FMX canvas, the 3D viewer uses the standard `TViewport3D`.

The sample applications vendor everything by `git subtree` under `_LIBRARY\LUXOPHIA\`:

- [Delaunay2D](https://github.com/LUXOPHIA/Delaunay2D) — interactive 2D demo
- [Delaunay3D](https://github.com/LUXOPHIA/Delaunay3D) — interactive 3D demo

## Quick start

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

     for N := 1 to 100 do D.AddPoin( 100 * TSingle2D.RandG );  // insert points

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), P ) < 10     // nearest point and its distance
     then D.DeletePoin( P );                                   // delete it

     for F in D.Faces do                                       // enumerate triangles
     begin
          if F.InfCorn = 0 then { F.Poin[1] … F.Poin[3] span a finite triangle };
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

     for N := 1 to 100 do D.AddPoin( TSingle3D.RandG );  // insert points

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1  // nearest point and its distance
     then D.DeletePoin( P );                                  // delete it

     for C in D.Cells do                                 // enumerate tetrahedra
     begin
          if C.InfCorn < 0 then { C.Poin[0] … C.Poin[3] span a finite tetrahedron };
     end;

     D.Free;
end;
```

## License

[MIT License](LICENSE) © LUXOPHIA
