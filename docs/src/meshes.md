# Finite elements (Gmsh)

A finite-element mesher needs the model as disjoint regions that share their edges, so that the mesh is conforming
across them. [`write_geo`](@ref) writes them as a Gmsh script; [`partition`](@ref) gives the same as data.

```julia
using EasyDraw
l = load_layout("model_layout.toml")
write_geo("model.geo", l; h=1.0)          # mesh size h, by default the layout's cell size
```

Then mesh it with Gmsh, `gmsh model.geo -2`, or from Julia with Gmsh.jl.

## The regions

- Each zone where it applies: where zones overlap, the later one wins. A zone reaching outside the domain is clipped
  to it.
- The rest of the domain as the background, zone 0 (`background=false` leaves it out).
- Neighbouring regions share their edges and vertices exactly.
- A circle is an inscribed polygon of `ngon` sides (32 by default), for itself and for the zones it meets.

`Region` zones cannot be partitioned: they have no outline.

## The script

For a 4 × 2 m domain whose lower half is a zone called `"base"`:

```julia
write_geo("model.geo", Layout(; L=[4, 2], nel=[4, 2], zones=[Zone("base", Block([0, 0], [4, 1]))]))
```

```
// EasyDraw: a layout's partition, x–z as x–y. Mesh it with: gmsh model.geo -2
h = 1.0;
Point(1) = {0.0, 0.0, 0, h};
Point(2) = {4.0, 0.0, 0, h};
Point(3) = {4.0, 2.0, 0, h};
Point(4) = {0.0, 2.0, 0, h};
Point(5) = {4.0, 1.0, 0, h};
Point(6) = {0.0, 1.0, 0, h};
Line(1) = {1, 2};
Line(2) = {1, 6};
Line(3) = {2, 5};
Line(4) = {3, 4};
Line(5) = {3, 5};
Line(6) = {4, 6};
Line(7) = {5, 6};
Curve Loop(1) = {4, 6, -7, -5};
Plane Surface(1) = {1};
Curve Loop(2) = {1, 3, 7, -2};
Plane Surface(2) = {2};
Physical Surface("background") = {1};
Physical Surface("base") = {2};
Physical Curve("left") = {2, 6};
Physical Curve("right") = {3, 5};
Physical Curve("bottom") = {1};
Physical Curve("top") = {4};
```

The x–z plane is Gmsh's x–y plane. Line 7 is the interface between the two regions: both surfaces use it. Each zone
name is a `Physical Surface` (all its parts, if it has several), and each side of the domain a `Physical Curve`, to
set material properties and boundary conditions on in your code.

## As data

[`partition`](@ref) returns a [`Partition`](@ref): the vertices, each edge once with the region on its left and on its
right (a zone's index, 0 for the background, -1 outside the domain) and the domain side it lies on, and each region's
outer outline (counterclockwise) and holes (clockwise), as loops of vertex indices.

```jldoctest
julia> using EasyDraw

julia> p = partition(Layout(; L=[4, 2], nel=[4, 2], zones=[Zone("base", Block([0, 0], [4, 1]))]));

julia> [(r.zone, r.outer) for r in p.regions]
2-element Vector{Tuple{Int64, Vector{Int64}}}:
 (0, [3, 4, 6, 5])
 (1, [1, 2, 5, 6])
```
