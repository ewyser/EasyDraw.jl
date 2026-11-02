# A layout at given coordinates, for grid-based codes (finite differences, particles): the zone of a point, of every
# point of a grid, a property's field, and the points the window previews.

"""
    zone_at(layout, x) -> Int
    zone_at(zones, x) -> Int

The zone of the point `x`: the index of the last zone that contains it, or 0 when none does. `x` is `(x, z)`, or
`(x, y, z)` for an extruded layout.

# Examples
```jldoctest
julia> l = Layout(; L=[10, 5], nel=[10, 5], zones=[Zone("base", Block([0, 0], [10, 2]); rho=2700),
                                                   Zone("lens", Ball([5, 2], 1.0); rho=2100)]);

julia> zone_at(l, (5.0, 1.5)), zone_at(l, (1.0, 1.0)), zone_at(l, (1.0, 4.0))
(2, 1, 0)
```

See also [`zone_index`](@ref), [`property`](@ref).
"""
function zone_at(zones::AbstractVector{Zone}, x)
    return something(findlast(z -> inside(z.shape, x), zones), 0)
end
function zone_at(l::Layout, x)
    return zone_at(l.zones, x)
end

"""
    subcell_centres(L, nel, ni) -> Vector{Vector{Float64}}

The centres of the sub-cells of a domain `[0, L]`, with `nel` cells per axis and `ni` sub-cells per cell and axis, as
one coordinate vector per axis (any dimension): the points [`points`](@ref) and the window's preview are made of.

The range arithmetic is ElastoPlasm's for its material points (cell size `L/nel`, the last node `last(0:h:L)`), so a
preview and a simulation built from the same layout have the same points, to the bit.
"""
function subcell_centres(L, nel, ni)
    return map(eachindex(L)) do d
        h = L[d]/nel[d]
        collect(0.5*h/ni:h/ni:last(0.0:h:L[d]) - 0.5*h/ni)
    end
end

"""
    zone_index(layout, xs, zs) -> Matrix{Int}

The zone of every point `(xs[i], zs[j])` of a grid, as [`zone_at`](@ref) gives it: 0 where no zone holds the point.
Use any coordinates: cell centres, vertices, or a staggered grid's velocity points.

# Examples
```jldoctest
julia> l = Layout(; L=[10, 5], nel=[10, 5], zones=[Zone("base", Block([0, 0], [10, 2]); rho=2700),
                                                   Zone("lens", Ball([5, 2], 1.0); rho=2100)]);

julia> zone_index(l, [1.0, 5.0], [0.5, 1.5, 4.0])
2×3 Matrix{Int64}:
 1  1  0
 1  2  0
```
"""
function zone_index(l::Layout, xs, zs)
    return [zone_at(l, (x, z)) for x ∈ xs, z ∈ zs]
end

"""
    property(layout, key, xs, zs; default) -> Matrix{Float64}

The property `key` at every point `(xs[i], zs[j])` of a grid: the value its zone sets, or `default` where the zone does
not set it or no zone holds the point. `default` is the layout's default for `key` (`layout.defaults`), else `NaN`.

# Throws
- `ArgumentError`: when a zone sets `key` to something other than a number.

# Examples
```jldoctest
julia> l = Layout(; L=[10, 5], nel=[10, 5], zones=[Zone("base", Block([0, 0], [10, 2]); rho=2700),
                                                   Zone("lens", Ball([5, 2], 1.0); rho=2100)]);

julia> property(l, "rho", [1.0, 5.0], [0.5, 2.5, 4.0]; default=1000.0)
2×3 Matrix{Float64}:
 2700.0  1000.0  1000.0
 2700.0  2100.0  1000.0
```
"""
function property(l::Layout, key, xs, zs; default=get(l.defaults, string(key), NaN))
    vals = [get(z.props, Symbol(key), default) for z ∈ l.zones]
    all(v -> v isa Real, vals) || throw(ArgumentError("property $key: a zone sets it to something other than a number"))
    return [(k = zone_at(l, (x, z)); Float64(k == 0 ? default : vals[k])) for x ∈ xs, z ∈ zs]
end

"""
    points(layout) -> (; x, z, zone)

The points the zones hold: the centres of the `ni`×`ni` sub-cells of each cell (`ni = 1`: the cell centres) that lie in
a zone, with the zone of each. These are the points the window previews, e.g. for markers or material points.

# Examples
```jldoctest
julia> l = Layout(; L=[10, 5], nel=[10, 5], zones=[Zone("base", Block([0, 0], [10, 2]); rho=2700),
                                                   Zone("lens", Ball([5, 2], 1.0); rho=2100)]);

julia> p = points(l);

julia> length(p.x), count(==(2), p.zone)
(86, 12)
```
"""
function points(l::Layout)
    x, z, zone = drawn_points(l.L, l.nel, l.ni, [s.shape for s ∈ l.zones])
    return (; x, z, zone)
end
