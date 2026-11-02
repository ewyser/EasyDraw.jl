# The shapes a zone may take, the rule saying which points they contain (`inside`), their form in files
# (`shape_dict`/`parse_shape`) and whether one reaches outside a domain (`outside`).

"""
    inpolygon(x, z, vertices) -> Bool

Whether the point `(x, z)` lies inside the polygon with these vertices (`[x, z]` pairs, the first not repeated at
the end), by the even–odd rule, so that concave and self-touching polygons work. A point exactly on an edge may
count as either side.

# Examples
```jldoctest
julia> inpolygon(1.0, 1.0, [[0, 0], [4, 0], [4, 4], [0, 4]])
true
```

See also [`inside`](@ref), [`Polygon`](@ref).
"""
function inpolygon(x::Real, z::Real, v)
    inside, j = false, length(v)
    for i ∈ eachindex(v)
        xi, zi, xj, zj = v[i][1], v[i][2], v[j][1], v[j][2]
        if (zi > z) != (zj > z) && x < (xj - xi)*(z - zi)/(zj - zi) + xi
            inside = !inside
        end
        j = i
    end
    return inside
end

"""
    AbstractShape

The supertype of a zone's shape: [`Polygon`](@ref), [`Block`](@ref), [`Ball`](@ref) or [`Region`](@ref).
[`inside`](@ref)`(shape, x)` tells whether a point lies in it.

A new shape is a subtype with an `inside` method. Like a `Region`, it then works in code (sampling, points) but cannot
be written to a file, drawn in the window or partitioned.
"""
abstract type AbstractShape end
"""
    Polygon

A polygon in the x–z plane, of one outline or several. In 3D it is extruded along y.

A point is inside when it lies inside an odd number of the outlines (the even–odd rule), so several outlines make
one zone of several parts, or with holes. The window leaves a zone in this form when a later zone cuts it.

# Fields
- `vertices::Vector{Vector{Float64}}`: the `[x, z]` vertices of every outline, one outline after the other, the first
  vertex of each not repeated at its end.
- `sizes::Vector{Int}`: how many vertices each outline has.

# Constructors
    Polygon(vertices)          # one outline: a vector of [x, z] vertices
    Polygon(rings)             # several outlines: a vector of such vectors
    Polygon(vertices, sizes)   # the fields themselves

# Throws
- `ArgumentError`: when an outline has fewer than 3 vertices, a vertex is not two coordinates, or `sizes` does not
  add up to the number of vertices.

# Examples
```jldoctest
julia> square = Polygon([[0, 0], [4, 0], [4, 4], [0, 4]]);

julia> inside(square, (1.0, 1.0))
true

julia> frame = Polygon([[[0, 0], [4, 0], [4, 4], [0, 4]], [[1, 1], [3, 1], [3, 3], [1, 3]]]);   # with a hole

julia> inside(frame, (2.0, 2.0)), frame.sizes
(false, [4, 4])
```

See also [`polygon_rings`](@ref), [`inside`](@ref).
"""
struct Polygon <: AbstractShape
    vertices::Vector{Vector{Float64}}
    sizes::Vector{Int}
    function Polygon(v, sizes=nothing)
        nested = isnothing(sizes) && !isempty(v) && first(v) isa AbstractVector && !isempty(first(v)) && first(first(v)) isa AbstractVector
        rings  = nested ? collect(v) : [v]
        vs = [Float64.(collect(p)) for r ∈ rings for p ∈ r]
        ns = isnothing(sizes) ? [length(r) for r ∈ rings] : collect(Int, sizes)
        sum(ns) == length(vs) && all(≥(3), ns) && all(length.(vs) .== 2) ||
            throw(ArgumentError("a Polygon needs at least 3 [x, z] vertices per outline"))
        return new(vs, ns)
    end
end
"""
    polygon_rings(polygon::Polygon) -> Vector{Vector{Vector{Float64}}}

The outlines of `polygon`, each a vector of its `[x, z]` vertices.

# Examples
```jldoctest
julia> polygon_rings(Polygon([[[0, 0], [4, 0], [4, 4]], [[1, 1], [2, 1], [2, 2]]]))
2-element Vector{Vector{Vector{Float64}}}:
 [[0.0, 0.0], [4.0, 0.0], [4.0, 4.0]]
 [[1.0, 1.0], [2.0, 1.0], [2.0, 2.0]]
```
"""
function polygon_rings(s::Polygon)
    ends = cumsum(s.sizes)
    return [s.vertices[e-n+1:e] for (n, e) ∈ zip(s.sizes, ends)]
end
"""
    Block

The axis-aligned box `lo ≤ x ≤ hi`, its bounds included. Given by two coordinates (x, z), it is extruded along y in
3D.

# Fields
- `lo::Vector{Float64}`: the lower corner.
- `hi::Vector{Float64}`: the upper corner.

# Constructors
    Block(lo, hi)

# Throws
- `ArgumentError`: when `lo` and `hi` differ in length, or `lo` exceeds `hi` along an axis.

# Examples
```jldoctest
julia> b = Block([0, 0], [10, 2]);

julia> inside(b, (10.0, 2.0)), inside(b, (5.0, 3.0))
(true, false)
```
"""
struct Block <: AbstractShape
    lo::Vector{Float64}
    hi::Vector{Float64}
    function Block(lo, hi)
        length(lo) == length(hi) || throw(ArgumentError("Block bounds need the same length"))
        all(lo .≤ hi) || throw(ArgumentError("Block needs lo ≤ hi"))
        return new(Float64.(collect(lo)), Float64.(collect(hi)))
    end
end
"""
    Ball

The points at most `radius` from `centre`: a disk in 2D, a sphere in 3D, or, with a two-coordinate (x, z) centre in
3D, a cylinder along y. The circle itself is included.

# Fields
- `centre::Vector{Float64}`: the centre.
- `radius::Float64`: the radius.

# Constructors
    Ball(centre, radius)

# Throws
- `ArgumentError`: when `radius` is negative.

# Examples
```jldoctest
julia> lens = Ball([5, 2], 1.0);

julia> inside(lens, (5.5, 2.5)), inside(lens, (6.5, 2.0))
(true, false)
```
"""
struct Ball <: AbstractShape
    centre::Vector{Float64}
    radius::Float64
    Ball(c, r) = r ≥ 0 ? new(Float64.(collect(c)), Float64(r)) : throw(ArgumentError("Ball needs radius ≥ 0"))
end
"""
    Region{F}

The points `x` for which `f(x)` is true: any shape, written as a Julia function. `x` holds the point's coordinates,
`(x, z)` in 2D, so `x[end]` is its height in 2D and 3D alike.

A `Region` works in code only: it cannot be written to a file, drawn in the window or partitioned.

# Fields
- `f::F`: the predicate, returning a `Bool`.

# Constructors
    Region(f)

# Examples
```jldoctest
julia> above = Region(x -> x[end] > 0.5x[1]);   # above the line z = x/2

julia> inside(above, (2.0, 3.0))
true
```
"""
struct Region{F} <: AbstractShape
    f::F
end

# a point's (x, z): what a two-coordinate shape reads of a 3D point
xz(x) = (x[1], x[end])
"""
    inside(shape::AbstractShape, x) -> Bool

Whether the point `x` (its coordinates, `(x, z)` or `(x, y, z)`) lies in `shape`:

- a [`Polygon`](@ref) by the even–odd rule over all its outlines;
- a [`Block`](@ref) with its bounds included;
- a [`Ball`](@ref) as its closed disk or sphere;
- a [`Region`](@ref) by its predicate.

A shape given by two coordinates reads a 3D point's x and z, so it is extruded along y.

# Throws
- `ArgumentError`: when a `Block` or `Ball` has neither as many coordinates as the point nor two.

# Examples
```jldoctest
julia> inside(Ball([0, 0], 1.0), (0.5, 0.5))
true

julia> inside(Block([0, 0], [1, 1]), (0.5, 7.0, 0.5))   # an (x, z) block in 3D: extruded along y
true
```
"""
function inside(s::Polygon, x)                                # even–odd over all its outlines
    odd, o = false, 0
    for n ∈ s.sizes
        inpolygon(x[1], x[end], view(s.vertices, o+1:o+n)) && (odd = !odd)
        o += n
    end
    return odd
end
function inside(s::Block, x)
    c = length(s.lo) == length(x) ? x : xz(x)
    length(c) == length(s.lo) || throw(ArgumentError("a Block of $(length(s.lo)) coordinates in $(length(x))D"))
    return all(i -> s.lo[i] ≤ c[i] ≤ s.hi[i], eachindex(s.lo))
end
function inside(s::Ball, x)
    c = length(s.centre) == length(x) ? x : xz(x)
    length(c) == length(s.centre) || throw(ArgumentError("a Ball of $(length(s.centre)) coordinates in $(length(x))D"))
    d2 = 0.0
    for i ∈ eachindex(s.centre)
        Δ = c[i] - s.centre[i]; d2 += Δ*Δ
    end
    return sqrt(d2) ≤ s.radius
end
inside(s::Region, x) = s.f(x)::Bool

# ---- shapes in files: a `[[zone]]` table holds its shape as `shape = "polygon"` with `vertices` (or `rings`),
# `"block"` with `lo`/`hi`, or `"ball"` with `centre`/`radius`

const SHAPES = ("polygon", "block", "ball")
function shape_dict(s::AbstractShape)
    if s isa Polygon                                         # one outline as `vertices`; several as `rings`
        rs = polygon_rings(s)
        return Dict{String,Any}("shape" => "polygon", length(rs) == 1 ? "vertices" => only(rs) : "rings" => rs)
    end
    s isa Block     && return Dict{String,Any}("shape" => "block", "lo" => s.lo, "hi" => s.hi)
    s isa Ball    && return Dict{String,Any}("shape" => "ball", "centre" => s.centre, "radius" => s.radius)
    throw(ArgumentError("a $(nameof(typeof(s))) zone (a Julia predicate) cannot be written to TOML"))
end
function parse_shape(z::AbstractDict, name)
    kind = get(z, "shape", "")
    kind == "polygon" && return Polygon(haskey(z, "rings") ? z["rings"] : z["vertices"])
    kind == "block"     && return Block(z["lo"], z["hi"])
    kind == "ball"    && return Ball(z["centre"], z["radius"])
    throw(ArgumentError("zone \"$name\": shape = \"$kind\" is not one of $(SHAPES)"))
end

# whether a shape reaches outside the domain [0, L] (the x–z plane for two-coordinate shapes)
function outside(shape::AbstractShape, L)
    lims(c) = length(c) == length(L) ? L : [L[1], L[end]]
    shape isa Polygon && return any(v -> !(0 ≤ v[1] ≤ L[1] && 0 ≤ v[2] ≤ L[end]), shape.vertices)
    shape isa Block     && return any(shape.lo .< 0) || any(shape.hi .> lims(shape.lo))
    shape isa Ball    && return any(shape.centre .- shape.radius .< 0) || any(shape.centre .+ shape.radius .> lims(shape.centre))
    return false
end
