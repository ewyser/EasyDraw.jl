# A layout at given coordinates, for grid-based codes (finite differences, particles): the zone of a point, of every
# point of a grid, a property's field, and the points the window previews.

"""
    zone_at(layout, x) -> Int

The zone of the point `x` (`(x, z)`, or `(x, y, z)` for an extruded layout): the index of the last zone containing
it, 0 for none.
"""
function zone_at(l::Layout, x)
    return something(findlast(z -> inside(z.shape, x), l.zones), 0)
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
