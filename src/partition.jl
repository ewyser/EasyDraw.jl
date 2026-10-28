# A layout as disjoint regions, for finite-element meshers: the partition (shared edges and vertices, each edge with
# the regions on its two sides, the domain's sides) and its Gmsh script.

"""
    Partition

A layout as disjoint regions (`partition`): `vertices` (`[x, z]`); `edges` (vertex index pairs, each once) with the
region on each side, `left` and `right` of the edge's direction (a zone's index, 0 for the background, -1 outside the
domain), and for an edge on the domain's boundary its `side` (`"left"`, `"right"`, `"bottom"`, `"top"`; `""` inside);
and `regions`, the parts of each zone (or of the background, zone 0), each an outer outline (counterclockwise) and its
holes (clockwise), as loops of vertex indices.
"""
struct Partition
    vertices :: Vector{Vector{Float64}}
    edges    :: Vector{Tuple{Int,Int}}
    left     :: Vector{Int}
    right    :: Vector{Int}
    side     :: Vector{String}
    regions  :: Vector{@NamedTuple{zone::Int, outer::Vector{Int}, holes::Vector{Vector{Int}}}}
end

# a shape's outlines in the x–z plane, a circle's as an inscribed `ngon`-gon
function outlines(s::AbstractShape, ngon)
    s isa Polygon && return polygon_rings(s)
    s isa Block && length(s.lo) == 2 && return [[[s.lo[1], s.lo[2]], [s.hi[1], s.lo[2]], [s.hi[1], s.hi[2]], [s.lo[1], s.hi[2]]]]
    s isa Ball && length(s.centre) == 2 && return [[s.centre .+ s.radius .* [cos(2π*j/ngon), sin(2π*j/ngon)] for j ∈ 0:ngon-1]]
    throw(ArgumentError("a partition is made of x–z polygons, blocks and balls, not of a $(nameof(typeof(s))) like this one"))
end
# the signed area of an outline, a loop of vertex indices (counterclockwise: positive)
function signed_area(pts, loop)
    a = 0.0
    for (k, i) ∈ enumerate(loop)
        j = loop[mod1(k + 1, length(loop))]
        a += pts[i][1]*pts[j][2] - pts[j][1]*pts[i][2]
    end
    return a/2
end

"""
    partition(layout; ngon=32, background=true) -> Partition

The layout as disjoint regions, as a finite-element mesher needs it: each zone where it applies (a point belongs to
the last zone containing it, so an overlap goes to the later zone), within the domain, and with `background` the rest
of the domain as zone 0. Neighbouring regions share their edges and vertices exactly. A circle is an inscribed
`ngon`-gon, for itself and for the zones it meets. Built from the arrangement of every zone's outline and of the
domain's: a piece of edge is kept where the regions on its two sides differ.
"""
function partition(l::Layout; ngon::Integer=32, background::Bool=true)
    L = l.L
    scale = maximum(L); tol, ε = 1e-9scale, 1e-7scale
    zr = [outlines(z.shape, ngon) for z ∈ l.zones]
    shapes = Polygon.(zr)                                    # their inside rule, a circle as its polygon
    box = [[0.0, 0.0], [L[1], 0.0], [L[1], L[2]], [0.0, L[2]]]
    rings = [[box]; reduce(vcat, zr; init=Vector{Vector{Float64}}[])]
    pts, pieces = arrangement(rings, falses(length(rings)), tol)
    owner(x) = 0 ≤ x[1] ≤ L[1] && 0 ≤ x[2] ≤ L[2] ? something(findlast(s -> inside(s, x), shapes), 0) : -1
    kept, left, right = Tuple{Int,Int}[], Int[], Int[]
    for (i, j) ∈ sort(collect(keys(pieces)))
        a, b = owner.(probes(pts[i], pts[j], ε))
        a == b && continue
        push!(kept, (i, j)); push!(left, a); push!(right, b)
    end
    used = sort(unique(Iterators.flatten(kept)))             # the vertices the kept edges use, renumbered
    new = Dict(v => k for (k, v) ∈ enumerate(used))
    vertices = [copy(pts[v]) for v ∈ used]
    edges = [(new[i], new[j]) for (i, j) ∈ kept]
    side = map(eachindex(edges)) do k
        -1 ∈ (left[k], right[k]) || return ""
        m = (vertices[edges[k][1]] .+ vertices[edges[k][2]]) ./ 2
        abs(m[1]) ≤ tol ? "left" : abs(m[1] - L[1]) ≤ tol ? "right" : abs(m[2]) ≤ tol ? "bottom" : "top"
    end
    regions = @NamedTuple{zone::Int, outer::Vector{Int}, holes::Vector{Vector{Int}}}[]
    for o ∈ sort(unique(filter(z -> z > 0 || (background && z == 0), [left; right])))
        loops = trace(vertices, [left[k] == o ? e : reverse(e) for (k, e) ∈ enumerate(edges) if o ∈ (left[k], right[k])])
        outer = filter(r -> signed_area(vertices, r) > 0, loops)
        holes = [Vector{Int}[] for _ ∈ outer]
        for h ∈ filter(r -> signed_area(vertices, r) < 0, loops)   # in the smallest outer outline around it
            q = probes(vertices[h[1]], vertices[h[2]], ε)[2]   # inside the hole (the region is on the left)
            in_ = [k for (k, r) ∈ enumerate(outer) if inpolygon(q[1], q[2], vertices[r])]
            push!(holes[in_[argmin([signed_area(vertices, outer[k]) for k ∈ in_])]], h)
        end
        append!(regions, [(; zone=o, outer=r, holes=holes[k]) for (k, r) ∈ enumerate(outer)])
    end
    return Partition(vertices, edges, left, right, side, regions)
end

"""
    write_geo(file, layout; h, ngon=32, background=true) -> file

The layout's `partition` as a Gmsh script: a `Point` per vertex (x–z as Gmsh's x–y; mesh size `h`, by default the
layout's cell size), a `Line` per edge, shared by the regions on its two sides, a `Plane Surface` per region (its
outer outline and its holes as `Curve Loop`s), a `Physical Surface` per zone name (the background's: "background")
and a `Physical Curve` per side of the domain. Mesh it with `gmsh file -2`, or Gmsh.jl.
"""
function write_geo(file::AbstractString, l::Layout; h=minimum(l.L ./ l.nel), ngon::Integer=32, background::Bool=true)
    p = partition(l; ngon, background)
    name(k) = replace(k == 0 ? "background" : l.zones[k].name, "\"" => "'")
    id = Dict(e => k for (k, e) ∈ enumerate(p.edges))
    line(i, j) = haskey(id, (i, j)) ? id[(i, j)] : -id[(j, i)]   # along the loop: the line, or reversed
    io = IOBuffer()
    println(io, "// EasyDraw: a layout's partition, x–z as x–y. Mesh it with: gmsh $(basename(file)) -2")
    println(io, "h = $(Float64(h));")
    foreach(((k, v),) -> println(io, "Point($k) = {$(v[1]), $(v[2]), 0, h};"), enumerate(p.vertices))
    foreach(((k, (i, j)),) -> println(io, "Line($k) = {$i, $j};"), enumerate(p.edges))
    nloop, surfaces = 0, Dict{String,Vector{Int}}()
    for (s, r) ∈ enumerate(p.regions)
        loops = Int[]
        for c ∈ [[r.outer]; r.holes]
            nloop += 1; push!(loops, nloop)
            println(io, "Curve Loop($nloop) = {$(join((line(c[k], c[mod1(k + 1, length(c))]) for k ∈ eachindex(c)), ", "))};")
        end
        println(io, "Plane Surface($s) = {$(join(loops, ", "))};")
        push!(get!(surfaces, name(r.zone), Int[]), s)
    end
    foreach(n -> println(io, "Physical Surface(\"$n\") = {$(join(surfaces[n], ", "))};"), unique(name(r.zone) for r ∈ p.regions))
    for s ∈ SIDES
        ks = findall(==(s), p.side)
        isempty(ks) || println(io, "Physical Curve(\"$s\") = {$(join(ks, ", "))};")
    end
    mkpath(dirname(abspath(file)))
    write(file, take!(io))
    return file
end
