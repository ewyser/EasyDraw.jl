# A layout at given coordinates, for grid-based codes (finite differences, particles): the zone of a point, of every
# point of a grid, a property's field, and the points the window previews.

"""
    zone_at(layout, x) -> Int
    zone_at(zones, x) -> Int

The zone of the point `x` (`(x, z)`, or `(x, y, z)` for an extruded layout): the index of the last zone containing
it, 0 for none.
"""
function zone_at(zones::AbstractVector{Zone}, x)
    return something(findlast(z -> inside(z.shape, x), zones), 0)
end
function zone_at(l::Layout, x)
    return zone_at(l.zones, x)
end

"""
    subcell_centres(L, nel, ni) -> axes

The sub-cell centres of a domain `[0, L]` with `nel` cells per axis, `ni` per cell and axis, as one coordinate vector
per axis (any dimension): the points `points` and the window's preview are made of. The range arithmetic is that of
ElastoPlasm's material points (cell size `L/nel`, the last node `last(0:h:L)`), so that a preview and a simulation
built from the same layout have the same points, to the bit.
"""
function subcell_centres(L, nel, ni)
    return map(eachindex(L)) do d
        h = L[d]/nel[d]
        collect(0.5*h/ni:h/ni:last(0.0:h:L[d]) - 0.5*h/ni)
    end
end

"""
    zone_index(layout, xs, zs) -> Matrix{Int}

The zone of every point `(xs[i], zs[j])` of a grid (`zone_at`): e.g. a finite-difference grid's cell centres,
vertices, or a staggered grid's velocity points.
"""
function zone_index(l::Layout, xs, zs)
    return [zone_at(l, (x, z)) for x ∈ xs, z ∈ zs]
end

"""
    property(layout, key, xs, zs; default) -> Matrix{Float64}

The property `key` at every point `(xs[i], zs[j])` of a grid: its zone's value, or `default` (the layout's default
of `key`, else `NaN`) where the zone does not set it or no zone holds the point.
"""
function property(l::Layout, key, xs, zs; default=get(l.defaults, string(key), NaN))
    vals = [get(z.props, Symbol(key), default) for z ∈ l.zones]
    all(v -> v isa Real, vals) || throw(ArgumentError("property $key: a zone sets it to something other than a number"))
    return [(k = zone_at(l, (x, z)); Float64(k == 0 ? default : vals[k])) for x ∈ xs, z ∈ zs]
end

"""
    points(layout) -> (; x, z, zone)

The points the zones hold: the sub-cell centres, `ni`×`ni` per cell (`ni = 1`: the cell centres), that lie in a
zone, and the zone of each (`zone_at`); what the window previews.
"""
function points(l::Layout)
    x, z, zone = drawn_points(l.L, l.nel, l.ni, [s.shape for s ∈ l.zones])
    return (; x, z, zone)
end
