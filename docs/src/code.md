# Layouts in code

A [`Layout`](@ref) is the whole model: a domain, its zones, a boundary kind per side, and the values your program asks
for in the window. What the window draws, code can write, and the other way round:

```jldoctest code
julia> using EasyDraw

julia> l = Layout(; L=[20, 10], nel=[20, 10],                  # [0, 20] × [0, 10] m, 20 × 10 cells
                    zones=[Zone("base",  Block([0, 0], [20, 4]); rho=2700),
                           Zone("wedge", Polygon([[0, 4], [20, 4], [0, 8]]); rho=1900),
                           Zone("lens",  Ball([14, 3], 1.5); rho=2100)],
                    sides=Dict("bottom" => "no slip"), defaults=Dict("rho" => 2000.0));

julia> [z.name for z in l.zones]
3-element Vector{String}:
 "base"
 "wedge"
 "lens"
```

## Shapes

| Shape                              | The points it holds                                                        |
|:-----------------------------------|:---------------------------------------------------------------------------|
| [`Polygon`](@ref)`(vertices)`      | inside the outline, `[x, z]` vertices (even–odd rule, so concave works)    |
| [`Polygon`](@ref)`(rings)`         | inside an odd number of the outlines: several parts, or holes             |
| [`Block`](@ref)`(lo, hi)`          | the axis-aligned box, its bounds included                                 |
| [`Ball`](@ref)`(centre, radius)`   | the disk, its circle included                                             |
| [`Region`](@ref)`(x -> …)`         | where the function is true: any shape, in code only                       |

[`inside`](@ref)`(shape, x)` tells whether a point lies in a shape. A `Region` cannot be written to a file, drawn in
the window or partitioned; the others can. In the window, a block becomes its rectangle, a polygon with the same
points.

## Zones

A [`Zone`](@ref) is a name, a shape and properties of any name: `Zone("lens", Ball([14, 3], 1.5); rho=2100)`. A number
is stored as a `Float64`, a list of numbers as a `Vector{Float64}`, anything else as given.

**Where zones overlap, the later one wins:** a point belongs to the last zone that contains it. Above, the lens lies
partly in the base and wins there:

```jldoctest code
julia> zone_at(l, (14.0, 3.0))                                 # in the lens, and in the base below it
3
```

So a model can be written from the bottom up, each zone over the ones before it. In the window, a new zone is cut out
of the earlier ones instead, so drawn zones do not overlap.

## The rest of a layout

- `ni`: points per cell and axis, 2 by default; see [`points`](@ref).
- `width` and `nely`: a width and a number of cells along y, to extrude the model in 3D.
- `sides`: a boundary kind per side, `"left"`, `"right"`, `"bottom"` or `"top"`; the kinds are your program's (see
  [Catalogs](catalog.md)).
- `defaults`: each zone property's default, for the zones that do not set it.
- `options` and `run`: your program's options and run settings, as the window sets them (see [Catalogs](catalog.md)).

Values are kept as given: SI in, SI out.

## Files

[`save_layout`](@ref) writes a layout as TOML, [`load_layout`](@ref) reads it, and [`draw`](@ref) opens one:

```julia
save_layout("model_layout.toml", l)
l = load_layout("model_layout.toml")
l = draw("model_layout.toml")
```

The file is meant to be read and edited by hand too. The layout above, with an option and a run setting:

```toml
[defaults]
rho = 2000.0

[domain]
L = [20.0, 10.0]
nel = [20, 10]
ni = 2

[options.solver]
method = "iterative"

[run]
nt = 500

[sides]
bottom = "no slip"

[[zone]]
hi = [20.0, 4.0]
lo = [0.0, 0.0]
name = "base"
rho = 2700.0
shape = "block"
[[zone]]
name = "wedge"
rho = 1900.0
shape = "polygon"
vertices = [[0.0, 4.0], [20.0, 4.0], [0.0, 8.0]]
[[zone]]
centre = [14.0, 3.0]
name = "lens"
radius = 1.5
rho = 2100.0
shape = "ball"
```

A polygon of several outlines is written as `rings = [[…], […]]` instead of `vertices`. The zones come in order: the
later one wins where they overlap. A layout's `folder` is not written: it is the folder the file is in.
