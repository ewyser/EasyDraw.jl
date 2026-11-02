# Finite differences and particles

A grid-based code needs the model at its own points: the zone of each, or a property's field. EasyDraw evaluates a
layout at any coordinates: cell centres, vertices, or a staggered grid's velocity points.

```jldoctest grids
julia> using EasyDraw

julia> l = Layout(; L=[100, 50], nel=[50, 25],
                    zones=[Zone("mantle", Block([0, 0], [100, 40]); rho=3300.0, eta=1e21),
                           Zone("plume",  Ball([50, 15], 8.0);       rho=3200.0, eta=1e19)]);

julia> xc, zc = 1.0:2.0:99.0, 1.0:2.0:49.0;                    # the cell centres

julia> phase = zone_index(l, xc, zc);                          # the zone of each, 0 where none

julia> size(phase), phase[25, 8], phase[1, 1], phase[1, 25]
((50, 25), 2, 1, 0)
```

## A property's field

[`property`](@ref) gives a property at every point: the value of the point's zone, or a default where the zone does
not set it or no zone holds the point.

```jldoctest grids
julia> eta = property(l, "eta", xc, zc; default=1e18);         # 1e18 above the mantle

julia> eta[25, 8], eta[1, 1], eta[1, 25]
(1.0e19, 1.0e21, 1.0e18)
```

Without `default`, it is the layout's default for that property (`l.defaults`), else `NaN`.

## One point

[`zone_at`](@ref) gives the zone of one point: the index of the last zone that contains it, 0 for none.

```jldoctest grids
julia> zone_at(l, (50.0, 15.0)), l.zones[2].name
(2, "plume")
```

For an extruded layout (a `width` and `nely`), points are `(x, y, z)`.

## Markers and material points

[`points`](@ref) gives points spread evenly in the zones, `ni`×`ni` per cell at the centres of the sub-cells, with the
zone of each: markers for a marker-in-cell code, or material points. They are the points the window previews.

```jldoctest grids
julia> p = points(l);                                          # ni = 2: 4 per cell

julia> length(p.x) == length(p.z) == length(p.zone)
true
```
