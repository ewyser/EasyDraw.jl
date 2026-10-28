# Regions bounded by zones' outlines: the arrangement of all their edges, split where they cross or touch
# (`arrangement`), a piece kept when the region lies on exactly one side of it, probed with the zones' own `inside` rule,
# and the kept pieces chained into outlines (`trace`). Cutting a zone by the zones drawn after it (`cut`) and the
# partition of a layout into disjoint regions (`partition`, partition.jl) are both built so. Probing sides, rather than
# following crossings, keeps shared edges and vertices (the window's snapped boundaries) exact, where clipping
# algorithms need special cases for them.

# the signed angle from direction u to v (left turns positive)
function turn(u, v)
    return atan(u[1]*v[2] - u[2]*v[1], u[1]*v[1] + u[2]*v[2])
end
# the index of point p in `pts`, merged with one closer than `tol` (added if there is none)
function point_index!(pts, p, tol)
    k = findfirst(q -> dist(p, q) < tol, pts)
    isnothing(k) || return k
    push!(pts, p)
    return length(pts)
end

# where segment c–d meets segment a–b, as parameters along a–b (0 at a, 1 at b): a crossing or a touching end, or
# the ends of a collinear overlap, within `tol` [m]
function meets(a, b, c, d, tol)
    r, s, w = b .- a, d .- c, c .- a
    lr, ls = hypot(r...), hypot(s...)
    den = r[1]*s[2] - r[2]*s[1]
    ts = Float64[]
    if abs(den) > 1e-12*lr*ls                                # not parallel: one point, if it is on both
        t = (w[1]*s[2] - w[2]*s[1])/den
        u = (w[1]*r[2] - w[2]*r[1])/den
        -tol/lr ≤ t ≤ 1 + tol/lr && -tol/ls ≤ u ≤ 1 + tol/ls && push!(ts, clamp(t, 0.0, 1.0))
    elseif abs(w[1]*r[2] - w[2]*r[1]) ≤ tol*lr               # collinear: the other's ends that lie on it
        for q ∈ (c, d)
            t = ((q[1] - a[1])*r[1] + (q[2] - a[2])*r[2])/lr^2
            -tol/lr ≤ t ≤ 1 + tol/lr && push!(ts, clamp(t, 0.0, 1.0))
        end
    end
    return ts
end

"""
    arrangement(rings, own, tol) -> (points, pieces)

The edges of the outlines `rings`, split where the others cross or touch them (within `tol` [m]): the `points` (the
outlines' vertices first, exactly as they are, merged when closer than `tol`, then the crossings), and each piece
between consecutive points once (both directions are one piece), as `(i, j) => on_own`, whether it lies on an
outline flagged in `own`.
"""
function arrangement(rings, own, tol)
    segs, flag, pts = Tuple{Vector{Float64},Vector{Float64}}[], Bool[], Vector{Float64}[]
    for (r, o) ∈ zip(rings, own), i ∈ eachindex(r)
        p, q = r[i], r[mod1(i + 1, length(r))]
        dist(p, q) > tol || continue
        push!(segs, (p, q)); push!(flag, o)
        point_index!(pts, p, tol)                             # the vertices first, exactly as they are
    end
    pieces = Dict{Tuple{Int,Int},Bool}()
    for (k, (p, q)) ∈ enumerate(segs)
        ts = [0.0, 1.0]
        for (l, (c, d)) ∈ enumerate(segs)
            l == k || append!(ts, meets(p, q, c, d, tol))
        end
        ids = unique([point_index!(pts, t == 0 ? p : t == 1 ? q : p .+ t .* (q .- p), tol) for t ∈ sort(ts)])
        for m ∈ 1:length(ids)-1
            key = minmax(ids[m], ids[m+1])
            pieces[key] = get(pieces, key, false) || flag[k]
        end
    end
    return pts, pieces
end
"""
    trace(points, directed) -> outlines (vertex indices)

Directed pieces `(i, j)` (the region on their left) chained into outlines: from each piece's end, the unused piece
turning most to the left. Outlines of fewer than 3 vertices are dropped.
"""
function trace(pts, directed)
    outgoing = Dict{Int,Vector{Int}}()
    for (k, (i, _)) ∈ enumerate(directed)
        push!(get!(outgoing, i, Int[]), k)
    end
    used, rings = falses(length(directed)), Vector{Vector{Int}}()
    for k0 ∈ eachindex(directed)
        used[k0] && continue
        ring, k = Int[], k0
        while true
            used[k] = true
            i, j = directed[k]
            push!(ring, i)
            next = [c for c ∈ get(outgoing, j, Int[]) if !used[c]]
            isempty(next) && break
            k = next[argmax([turn(pts[j] .- pts[i], pts[directed[c][2]] .- pts[j]) for c ∈ next])]
        end
        length(ring) ≥ 3 && push!(rings, ring)
    end
    return rings
end
# the side probes of a piece: points ε to its left and right, at its midpoint
function probes(p, q, ε)
    d = q .- p
    n, m = [-d[2], d[1]] ./ hypot(d...), (p .+ q) ./ 2
    return m .+ ε .* n, m .- ε .* n
end

"""
    cut(a, bs, scale) -> outlines, or nothing

The part of the zone with outlines `a` (even–odd) outside every zone of `bs` (each a vector of outlines), as
outlines: empty when nothing is left, `nothing` when no zone of `bs` takes any of it. Its vertices are theirs,
exactly, and the points where their outlines cross. `scale` [m], the domain's size, sets the tolerances: points
closer than 1e-9 scale are one, the sides of an edge are probed 1e-7 scale away.
"""
function cut(a, bs, scale)
    tol, ε = 1e-9scale, 1e-7scale
    A, Bs = Polygon(a), Polygon.(bs)                          # their inside rule, `case_points`'s
    rings = [a; reduce(vcat, bs; init=Vector{Vector{Float64}}[])]
    pts, pieces = arrangement(rings, [trues(length(a)); falses(length(rings) - length(a))], tol)
    # a piece bounds the difference when it lies on exactly one side of it: kept, directed with the difference on its
    # left. Unchanged when the kept pieces are exactly the zone's own
    directed, changed = Tuple{Int,Int}[], false
    for ((i, j), on_a) ∈ pieces
        left, right = (inside(A, x) && !any(B -> inside(B, x), Bs) for x ∈ probes(pts[i], pts[j], ε))
        changed |= (left != right) != on_a
        left != right && push!(directed, left ? (i, j) : (j, i))
    end
    changed || return nothing
    return [[copy(pts[i]) for i ∈ ring] for ring ∈ trace(pts, directed)]
end
