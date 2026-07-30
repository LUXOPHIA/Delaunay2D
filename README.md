# LUX.Delaunay
[English](README.md) | [日本語](ja/README.md)

Delaunay complexes for Delphi: triangulations of the Euclidean plane, tetrahedralizations of Euclidean 3-space, and triangulations of the flat torus. Every diagram accepts insertion **and** deletion of sites at any time, and is a valid Delaunay complex after each operation. Released under the [MIT License](LICENSE).

## 1. Overview

The library is organised as three independent models, each paired with a drop-in FireMonkey viewer frame.

| Package | Domain | Model class | Cell |
|---|---|---|---|
| [`LUX.Delaunay.D2`](D2/README.md) | Euclidean plane $\mathbb{E}^2$ | `TDelaunay2D` | triangle (`TDelaFace2D`) |
| [`LUX.Delaunay.D2.Periodic`](D2/Periodic/README.md) | flat torus $\mathbb{T}^2 = \mathbb{R}^2 / L\mathbb{Z}^2$ | `TPeriDelaunay2D` | triangle (`TPeriFace2D`) |
| [`LUX.Delaunay.D3`](D3/README.md) | Euclidean 3-space $\mathbb{E}^3$ | `TDelaunay3D` | tetrahedron (`TDelaCell3D`) |

Properties common to all three models:

- **Fully dynamic.** `AddPoin` inserts a site by the Bowyer–Watson cavity construction [1][2]; `DeletePoin` removes one by star removal followed by a deterministic retriangulation of the hole from the link vertices [8]. Neither operation performs a flip search.
- **Total failure semantics.** A degenerate input never corrupts the structure: `AddPoin` returns `nil` and `DeletePoin` returns `False` with nothing modified.
- **One predicate.** In-circle, in-sphere, orientation and walk direction are all evaluated as a single lifted determinant (§2.2), so the code contains no case analysis over cell type.
- **Multicast change notification.** `OnChange :TDelegates` fires after every structural change; the viewers subscribe to it and rebuild their scene automatically.

The two Euclidean models additionally use the **infinite-vertex** compactification (§2.3) instead of a super-simplex, and expose the circumcenter in **homogeneous coordinates** (§2.4) so that the entire Voronoi diagram, unbounded rays included, follows from one branch-free formula. The periodic model instead keeps the triangulation in the **minimal representation** on the quotient space (§2.5) and evaluates its predicates in **exact integer arithmetic**.

## 2. Mathematical Background

### 2.1 The Delaunay complex

Let $P \subset \mathbb{R}^d$ be finite. A $d$-simplex $\sigma$ with vertices in $P$ belongs to the Delaunay complex $\mathrm{Del}(P)$ iff its circumscribed open ball contains no point of $P$:

```math
\sigma = \{p_0,\dots,p_d\} \in \mathrm{Del}(P)
\iff
\exists\, B \text{ open ball}: \partial B \supset \sigma \;\wedge\; B \cap P = \varnothing
\qquad \text{(2.1)}
```

$\mathrm{Del}(P)$ is the geometric dual of the Voronoi diagram $\mathrm{Vor}(P)$: a $k$-face of $\mathrm{Del}(P)$ corresponds to a $(d-k)$-face of $\mathrm{Vor}(P)$, and the circumcenter of a $d$-simplex is a Voronoi vertex [10].

### 2.2 The lifting map and the unified predicate

Let $\ell : \mathbb{R}^d \to \mathbb{R}^{d+1}$ be the lifting map onto the standard paraboloid,

```math
\ell(p) = \bigl(p,\; \lVert p \rVert^2 \bigr) .
\qquad \text{(2.2)}
```

A sphere in $\mathbb{R}^d$ is the vertical projection of the intersection of the paraboloid with an affine hyperplane, and $q$ lies inside that sphere iff $\ell(q)$ lies strictly below the hyperplane. Consequently $\mathrm{Del}(P)$ is the vertical projection of the lower convex hull of $\ell(P)$ [4][6].

The library evaluates (2.1) directly in lifted coordinates, translated to the query point $q$ so that no expression is ever evaluated in absolute coordinates:

```math
\mathrm{Lift}(p; q) = \bigl(\, p - q,\; \lVert p - q \rVert^2 \,\bigr) \in \mathbb{R}^{d+1},
\qquad
\mathrm{InBall}(p_0,\dots,p_d;\, q) = \det \begin{pmatrix} \mathrm{Lift}(p_0;q) \\ \vdots \\ \mathrm{Lift}(p_d;q) \end{pmatrix}
\qquad \text{(2.3)}
```

For a positively oriented simplex, $\mathrm{InBall} > 0$ means "$q$ is inside the circumscribed ball". All determinants are accumulated in `Double` after the translation, which is what makes the predicates usable far from the origin [5].

### 2.3 The point at infinity

The Euclidean models add one distinguished vertex $\infty$ and cover the exterior of the convex hull with cells containing it, so that every facet has exactly two incident cells and no boundary case exists. Combinatorially this is the one-point compactification: the diagram of $n$ sites is a triangulation of $S^d$ with $n+1$ vertices. In the plane, Euler's formula therefore fixes the size exactly,

```math
V = n+1, \quad E = 3n-3, \quad F = 2n-2 \qquad (n \ge 3),
\qquad \text{(2.4)}
```

infinite faces included.

The point at infinity is realised by substituting its own lift,

```math
\mathrm{Lift}(\infty; q) = (0,\dots,0,1),
\qquad \text{(2.5)}
```

which is the limit direction of $\ell$ along the paraboloid axis. Substituting (2.5) into (2.3) collapses the determinant, by expansion along that row, to the orientation determinant of the remaining $d$ vertices relative to $q$. A sphere through $\infty$ is thus a hyperplane — a sphere of infinite radius — and the in-ball test degenerates automatically into a half-space test. `TDelaPoin2DInf` / `TDelaPoin3DInf` perform this substitution by overriding `Lift`, so the predicates contain no flag test.

### 2.4 Homogeneous circumcenter

Fix a base vertex $B$ of a cell and let $L_i = \mathrm{Lift}(p_i;B)$, with homogeneous weight $w_i = 1$ for a finite vertex and $w_i = 0$ for $\infty$. Writing lifted homogeneous coordinates as $(X_1,\dots,X_d, Z, W)$, the hyperplane through the $d+1$ lifted vertices is

```math
a_1 X_1 + \cdots + a_d X_d + c\,Z + e\,W = 0 ,
\qquad \text{(2.6)}
```

whose coefficients are the signed minors of the $(d+1) \times (d+2)$ matrix $[\,L_i \mid w_i\,]$. Intersecting (2.6) with $Z = \lVert X \rVert^2$ gives a sphere of centre $-a/(2c)$, so the models return the circumcenter in homogeneous form

```math
\mathrm{Circum} = (\,-a_1,\; \dots,\; -a_d,\; 2c\,) .
\qquad \text{(2.7)}
```

The weight vanishes, $2c = 0$, exactly when the hyperplane is vertical, i.e. when the cell contains $\infty$; then $(-a_1,\dots,-a_d)$ is the outward direction of the unbounded Voronoi edge dual to the hull facet. Bounded and unbounded Voronoi edges therefore come out of the same expression, with no branch and no division.

### 2.5 The periodic case

For the flat torus $\mathbb{T}^2 = \mathbb{R}^2/L\mathbb{Z}^2$ the input is the infinite, lattice-periodic point set $P + L\mathbb{Z}^2$, and the Delaunay triangulation is taken in the universal cover and then projected. Since $\chi(\mathbb{T}^2) = 0$, the quotient complex of $n$ sites has

```math
V = n, \quad E = 3n, \quad F = 2n
\qquad \text{(2.8)}
```

for **every** $n \ge 1$. `TPeriDelaunay2D` stores exactly this minimal representation: it never replicates ghost points and never enlarges the domain to a $3 \times 3$ covering space [7]. The projection is in general only a $\Delta$-complex, not a simplicial complex — a face may reference the same vertex instance at two or three of its corners, under different lattice offsets — and the model is built to host that case directly rather than to avoid it [9]. See [`D2/Periodic/README.md`](D2/Periodic/README.md) for the offset bookkeeping, the exact integer predicates and the symbolic perturbation.

### 2.6 Queries

Point location is *jump & walk* [6]: draw $m = n^{1/(d+1)}$ random sites, start from the anchor cell of the nearest one, and cross facets towards the query point. The expected cost is $O(n^{1/(d+1)})$, i.e. $O(n^{1/3})$ in the plane and $O(n^{1/4})$ in space, uniform over the domain because the sample is redrawn on every query. `FindNearPoin` starts from the located cell and then descends greedily along Delaunay edges; since the distance strictly decreases at each step, it terminates at the site whose Voronoi region contains the query point.

## 3. Architecture

### 3.1 Package structure

```
Base library

・LUX
  ┣・LUX.D2 / LUX.D3 / LUX.D4   ･･･ vectors
  ┣・LUX.Data.Model.TriFlip.*   ･･･ 2D mesh model
  ┗・LUX.Data.Model.TetraFlip.* ･･･ 3D mesh model

Packages built on LUX   (each model package, then its viewer)

・LUX.Delaunay.D2                ･･･ ∞-vertex, E²
  ┣・TDelaunay2D
  ┣・TDelaPoin2D
  ┣・TDelaPoin2DInf
  ┣・TDelaFace2D
  ┗・LUX.Delaunay.D2.Viewer
     ┗・TDelaunayViewer         ･･･ (LUX.CG2D / Skia)

・LUX.Delaunay.D2.Periodic       ･･･ torus, minimal representation, T²
  ┣・TPeriDelaunay2D
  ┣・TPeriPoin2D
  ┣・TPeriFace2D
  ┗・LUX.Delaunay.D2.Periodic.Viewer
     ┗・TPeriDelaunayViewer     ･･･ (LUX.CG2D / Skia)

・LUX.Delaunay.D3                ･･･ ∞-vertex, E³
  ┣・TDelaunay3D
  ┣・TDelaPoin3D
  ┣・TDelaPoin3DInf
  ┣・TDelaCell3D
  ┗・LUX.Delaunay.D3.Viewer
     ┗・TDelaunayViewer         ･･･ (FMX TViewport3D)
```

`TDelaunay2D` and `TPeriDelaunay2D` are both derived from the TriFlip triangle-mesh layers of [LUX](https://github.com/LUXOPHIA/LUX); `TDelaunay3D` is derived from the TetraFlip tetrahedral-mesh layers. Those layers own the points and cells and provide the connectivity (`Poin` / `Face` or `Cell` / `Corn` / `Bond`), the corner-rotation tables, the facet gluing and the iteration; each `LUX.Delaunay.*` unit adds only what is Delaunay-specific.

### 3.2 File layout

```
・LUX.Delaunay/
  ┣・README.md                                       ･･･ this document
  ┣・ja/README.md                                    ･･･ Japanese translation
  ┣・LICENSE                                         ･･･ MIT
  ┣・D2/                                             ･･･ 2D Euclidean plane
  ┃  ┣・LUX.Delaunay.D2.pas                         ･･･ TDelaunay2D — E²
  ┃  ┣・LUX.Delaunay.D2.Viewer.pas / .fmx           ･･･ TDelaunayViewer (Skia)
  ┃  ┣・README.md , ja/README.md                    ･･･ package documentation
  ┃  ┗・Periodic/                                   ･･･ 2D flat torus
  ┃     ┣・LUX.Delaunay.D2.Periodic.pas             ･･･ TPeriDelaunay2D — T²
  ┃     ┣・LUX.Delaunay.D2.Periodic.Viewer.pas/.fmx ･･･ TPeriDelaunayViewer
  ┃     ┗・README.md , ja/README.md                 ･･･ package documentation
  ┗・D3/                                             ･･･ 3D Euclidean space
     ┣・LUX.Delaunay.D3.pas                          ･･･ TDelaunay3D — E³
     ┣・LUX.Delaunay.D3.Viewer.pas / .fmx            ･･･ TDelaunayViewer (FMX)
     ┗・README.md , ja/README.md                     ･･･ package documentation
```

### 3.3 Dependencies

- [LUX](https://github.com/LUXOPHIA/LUX) — base library: vector types (`LUX.D2` … `LUX.D4`), delegates, lists, and the TriFlip / TetraFlip mesh models (`LUX.Data.Model.*`).
- [LUX.CG2D](https://github.com/LUXOPHIA/LUX.CG2D) — 2D scene graph on Skia4Delphi. Required by the **2D viewers** only.
- Delphi with FireMonkey. The model units are plain Object Pascal; the 2D viewers need a Skia-enabled FMX canvas, the 3D viewer uses the standard `TViewport3D`.

Complete interactive applications, which vendor the libraries by `git subtree` under `_LIBRARY\LUXOPHIA\`, are available at [Delaunay2D](https://github.com/LUXOPHIA/Delaunay2D) and [Delaunay3D](https://github.com/LUXOPHIA/Delaunay3D).

## 4. Usage

### 4.1 Plane

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

     if D.FindNearPoin( TSingle2D.Create( 0, 0 ), P ) < 10       // nearest site and its distance
     then D.DeletePoin( P );                                     // delete

     for F in D.Faces do                                         // enumerate triangles
     begin
          if F.InfCorn = 0 then { F.Poin[1] … F.Poin[3] span a finite triangle };
     end;

     D.Free;
end;
```

### 4.2 Torus

```pascal
uses LUX, LUX.D2, LUX.Delaunay.D2.Periodic;

var
   D :TPeriDelaunay2D;
   F :TPeriFace2D;
   N :Integer;
begin
     D := TPeriDelaunay2D.Create;

     D.Size := 300;                                              // fundamental domain [0,300)²

     for N := 1 to 100 do                                        // insert (wrapped into the domain)
     begin
          D.AddPoin( TSingle2D.Create( 300 * Random, 300 * Random ) );
     end;

     for F in D.Faces do                                         // always exactly 2n faces
     begin
          { F.CornPos( 1 ) … F.CornPos( 3 ) span a triangle in F's own lift };
     end;

     D.Free;
end;
```

### 4.3 Space

```pascal
uses LUX, LUX.D3, LUX.D4, LUX.Delaunay.D3;

var
   D :TDelaunay3D;
   P :TDelaPoin3D;
   C :TDelaCell3D;
   N :Integer;
begin
     D := TDelaunay3D.Create;

     for N := 1 to 100 do D.AddPoin( TSingle3D.RandG );          // insert

     if D.FindNearPoin( TSingle3D.Create( 0, 0, 0 ), P ) < 1     // nearest site and its distance
     then D.DeletePoin( P );                                      // delete

     for C in D.Cells do                                          // enumerate tetrahedra
     begin
          if C.InfCorn < 0 then { C.Poin[0] … C.Poin[3] span a finite tetrahedron };
     end;

     D.Free;
end;
```

## 5. References

1. Bowyer, A., [*Computing Dirichlet tessellations*](https://doi.org/10.1093/comjnl/24.2.162), The Computer Journal, 24(2), 162–166, 1981.
2. Watson, D. F., [*Computing the n-dimensional Delaunay tessellation with application to Voronoi polytopes*](https://doi.org/10.1093/comjnl/24.2.167), The Computer Journal, 24(2), 167–172, 1981.
3. Delaunay, B., [*Sur la sphère vide*](https://www.mathnet.ru/eng/im4937), Bulletin de l'Académie des Sciences de l'URSS, 6, 793–800, 1934.
4. Brown, K. Q., [*Voronoi diagrams from convex hulls*](https://doi.org/10.1016/0020-0190(79)90074-7), Information Processing Letters, 9(5), 223–228, 1979.
5. Shewchuk, J. R., [*Adaptive precision floating-point arithmetic and fast robust geometric predicates*](https://doi.org/10.1007/PL00009321), Discrete & Computational Geometry, 18(3), 305–363, 1997.
6. Mücke, E. P., Saias, I., Zhu, B., [*Fast randomized point location without preprocessing in two- and three-dimensional Delaunay triangulations*](https://doi.org/10.1016/S0925-7721(98)00035-2), Computational Geometry, 12(1–2), 63–83, 1999.
7. Caroli, M., Teillaud, M., [*Computing 3D periodic triangulations*](https://doi.org/10.1007/978-3-642-04128-0_6), ESA 2009, LNCS 5757, 59–70, 2009.
8. Devillers, O., [*On deletion in Delaunay triangulations*](https://doi.org/10.1142/S0218195902000815), International Journal of Computational Geometry & Applications, 12(3), 193–205, 2002.
9. Osang, G., Rouxel-Labbé, M., Teillaud, M., [*Generalizing CGAL periodic Delaunay triangulations*](https://doi.org/10.4230/LIPIcs.ESA.2020.75), ESA 2020, LIPIcs 173, 75:1–75:17, 2020.
10. Edelsbrunner, H., Seidel, R., [*Voronoi diagrams and arrangements*](https://doi.org/10.1007/BF02187681), Discrete & Computational Geometry, 1(1), 25–44, 1986.

## 💖 [Embarcadero](https://www.embarcadero.com/) [**Delphi**](https://www.embarcadero.com/products/delphi)
Integrated Development Environment (IDE) for Creating Native Cross-Platform Apps.
### Free Download: [**Delphi** Community Edition](https://www.embarcadero.com/products/delphi/starter)
