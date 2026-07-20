# Delaunay2D

**Interactive 2D Delaunay / Voronoi diagram demo for Delphi (FireMonkey).**

[English](README.md) | [日本語](ja/README.md)

Click to add and remove points; the Delaunay triangulation, the circumcircles, and the Voronoi diagram update live. Built on the [LUX.Delaunay](https://github.com/LUXOPHIA/LUX.Delaunay) library:

- Incremental **insertion** (Bowyer–Watson) and **deletion** (flip-based) — the diagram stays Delaunay after every operation.
- **Infinite-vertex method** — no super-triangle, no bounding box; hull points behave like interior points.
- Rendering by the library's `TDelaunayViewer` frame (Skia scene graph); the application itself contains no drawing code.

## Controls

| Input | Action |
|---|---|
| Click on empty space | Add a point |
| Click on a point | Delete it |
| `Add x10` | Add 10 random points |
| `Del x10` | Delete 10 random points |
| `Clear` | Remove all points |

## Structure

```
Delaunay2D.dpr / Main.pas / Main.fmx    … the application (a thin form; no scene code)
_LIBRARY\LUXOPHIA\
  LUX.Delaunay\                         … Delaunay library         (git subtree)
    D2\LUX.Delaunay.D2.pas              …   2D diagram (TDelaunay2D)
    D2\LUX.Delaunay.D2.Viewer.pas/.fmx  …   2D viewer frame (TDelaunayViewer)
  LUX.CG2D\                             … 2D scene graph on Skia   (git subtree)
  LUX\                                  … base library             (git subtree)
```

## Building

Open `Delaunay2D.dproj` in RAD Studio and run (Win32 / Win64). The viewer draws through [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D), which requires a Skia-enabled FMX canvas.

## Library documentation

The class reference and API usage are documented in the library:
[LUX.Delaunay/D2](https://github.com/LUXOPHIA/LUX.Delaunay/tree/main/D2)
