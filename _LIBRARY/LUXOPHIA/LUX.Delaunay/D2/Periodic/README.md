# LUX.Delaunay.D2.Periodic

[日本語](ja/README.md)

2D Delaunay triangulation with **periodic boundary conditions** — a Delaunay triangulation of the flat torus `T = [0,L)²`. No ghost-point replication and no covering space (3×3 sheets): the triangulation is kept in the **minimal representation at all times** (n vertices, 2n faces). Even n = 1 is valid, as a Δ-complex of 1 vertex and 2 faces whose corners reference the same vertex instance under different lattice offsets. This is a refinement of the 2009 `VoronoiTools2P` prototype (a periodic Bowyer–Watson carrying cumulative lattice offsets), completed with exact predicates and full handling of the general cases.

## Classes

| Class | Base | Role |
|---|---|---|
| `TPeriPoin2D` | `TTriPoin2D<TPeriFace2D>` | vertex (1:1 with sites; carries `Site`) |
| `TPeriPoinSet2D` | `TTriPoinSet2D<TPeriPoin2D>` | vertex set |
| `TPeriFace2D` | `TTriFace2D<TPeriPoin2D,TPeriFace2D>` | triangle (per-corner lattice offsets, lift geometry) |
| `TPeriFaceSet2D` | `TTriFaceSet2D<TPeriFace2D,TPeriPoinSet2D>` | face set |
| `TPeriDelaunay2D` | `TPeriFaceSet2D` | the model: site insertion / deletion |

TriFlip's connectivity (Poin / Face / Corn) navigates by corner indices, not by vertex identity, so it hosts Δ-complexes as-is; the periodic layer only adds offsets and geometry.

## Algorithm highlights

- **Lattice offsets, canonical by construction** — vertex positions are always canonical (∈ [0,L)²); each face stores per-corner offsets o ∈ {0,1,2} and its own lift into the universal cover (`NeigShift` converts between neighboring lifts). Offsets are normalized at face creation, so entities never drift away from the fundamental domain — no periodic "re-wrapping pass" is ever needed.
- **Quantization + exact integer predicates** — `L` is snapped to a power-of-two grid `q = 2^(E−17)` and all coordinates to multiples of `q` (error ~`L·2⁻¹⁶`, invisible). All geometry lives on an integer grid: orientation tests are exact in 64-bit, in-circle tests are exact via 128-bit integer accumulation. Predicate misclassification — the root cause of structural corruption — cannot occur.
- **Symbolic perturbation (site-rank SoS)** — cocircular degeneracies are resolved deterministically by an infinitesimal per-site lift perturbation (equivalent to infinitesimal weighted Delaunay). Being per-site, the perturbation is lattice-equivariant, which also resolves the *structural* cocircularities caused by translate pairs (w, w+L·e). Only unresolvable super-degeneracies (e.g. exactly symmetric grid configurations in the sparse regime) are rejected (`AddPoin` returns nil; deletion falls back to rebuild) — the triangulation always stays valid.
- **Insertion (Bowyer–Watson in the universal cover)** — fix one lift p̂ of the new point and collect the cavity as pairs (face instance × lattice translation) by BFS; the same face may legitimately enter twice under different translations when its circumdisk contains several periodic images of p.
  - Normal case (p not Delaunay-adjacent to its own images; verified exactly): plain **cone** over the cavity boundary.
  - Sparse case: a cone is incorrect (faces with a self-edge p–p are required), so the **star of p̂ is built directly by gift-wrapping** over a candidate set (hole-boundary vertices and their translates + the lattice images of p); projected duplicates are identified by a rotation/translation-normalized key, and every adjacency is resolved geometrically. The mesh is only touched after the full plan validates.
- **Deletion (local star removal + Delaunay-ear refill)** — walk the ring around one lift of the vertex, extract the hole polygon in lift coordinates, and fill it with Delaunay ears (empty of link vertices *and their translates*). When the hole wraps around the torus, the neighboring hole's translation μ is determined geometrically to sew fill faces to each other. Plan-validate first; on a degenerate failure **nothing is touched and False is returned** (same convention as the planar library). Only n ≤ 3 is handled by an O(1) rebuild (the analogue of the planar version's small-count special cases). Measured: deleting all of 200 uniform random sites uses the local path 197/200 times (the other 3 are the trailing n ≤ 3).
- Point location is jump-and-walk with cumulative translations, exact predicates, and a full-scan fallback.

## API sketch

```pascal
var D :TPeriDelaunay2D;

D := TPeriDelaunay2D.Create;
D.Size := 300;                                  // fundamental domain [0,300)²

V := D.AddPoin( TSingle2D.Create( X, Y ) );     // wrapped into the domain; nil on duplicates / super-degeneracies
D.FindNearPoin( P, V );                          // nearest site (torus metric)
D.DeletePoin( V );                               // local deletion (False on degeneracies, nothing changed; n ≤ 3 rebuilds in O(1))

for F in D.Faces do                              // faces = the torus faces themselves (always 2n)
   ... F.CornPos( K ) ... F.CircumPos ... F.NeigShift( K ) ...

D.LocalDelN;  D.RebuildDelN;  D.StarInsN;        // statistics
D.OnChange.Add( Handler );                       // change notification
```

## Notes / limitations

- The domain is a **square** torus (`Size × Size`).
- Exactly-cocircular degenerate configurations may be rejected while the point set is sparse (when star construction is needed); once dense (cone regime) no rejections occur.
- `SaveToFile` / `LoadFromFile` of the TriFlip container are disabled (the format cannot store lattice offsets).
- Vertex references returned by `AddPoin` / `FindNearPoin` are invalidated when that vertex is deleted — use them immediately.

## Viewer

`LUX.Delaunay.D2.Periodic.Viewer` (`TPeriDelaunayViewer`) renders the model with the LUX.CG2D scene graph: triangles, circumcircles, Voronoi diagram, domain grid and sites, tiled periodically over the visible area with exact per-shape shift ranges.

## References

- LUXOPHIA `VoronoiTools2P` (2009) — the original offset-carrying periodic Bowyer–Watson this library refines.
- M. Caroli, M. Teillaud, *Computing 3D Periodic Triangulations*, ESA 2009 — the covering-space approach (which this library deliberately avoids).
- G. Osang, M. Rouxel-Labbé, M. Teillaud, *Generalizing CGAL Periodic Delaunay Triangulations*, ESA 2020 — direct quotient-space insertion only after simpliciality is guaranteed (no deletion).
- H. Edelsbrunner, E. P. Mücke, *Simulation of Simplicity* (symbolic perturbation).
