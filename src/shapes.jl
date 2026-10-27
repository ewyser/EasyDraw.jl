# The shapes a zone may take, the rule saying which points they contain (`inside`), their form in files
# (`shape_dict`/`parse_shape`) and whether one reaches outside a domain (`outside`).

"""
    inpolygon(x, z, v) -> Bool

Whether the point `(x, z)` lies inside the polygon with vertices `v` (`[x, z]` pairs, not repeated
at the end), by the even–odd rule, so concave polygons work.
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

abstract type AbstractShape end
"""
    Polygon(vertices)
    Polygon(rings)
    Polygon(vertices, sizes)

A polygon in the x–z plane (`[x, z]` vertices, not repeated at the end; even–odd rule); in 3D it is
extruded along y. Several outlines (`rings`, each a vector of vertices) make one zone of several parts or
with holes, by the even–odd rule over all of them (inside an odd number of outlines: inside), as the drawing
window leaves a zone cut by the ones drawn after it. `vertices` holds every outline's vertices, one outline
after the other, and `sizes` how many each has (`polygon_rings`).
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
"The outlines of a polygon, each a vector of its vertices."
function polygon_rings(s::Polygon)
    ends = cumsum(s.sizes)
    return [s.vertices[e-n+1:e] for (n, e) ∈ zip(s.sizes, ends)]
end
"""
    Block(lo, hi)

The axis-aligned box `lo ≤ x ≤ hi` (bounds included): `D` coordinates, or two (x, z) for a box
extruded along y in 3D.
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
    Ball(centre, radius)

The points at most `radius` from `centre` (bounds included): a disk in 2D, a sphere in 3D, or, with
an (x, z) centre in 3D, a cylinder along y.
"""
struct Ball <: AbstractShape
    centre::Vector{Float64}
    radius::Float64
    Ball(c, r) = r ≥ 0 ? new(Float64.(collect(c)), Float64(r)) : throw(ArgumentError("Ball needs radius ≥ 0"))
end
"""
    Region(f)

The points `x` (a vector of `D` coordinates) for which `f(x)` is true: any shape, from code. A
`Region` cannot be written to a TOML file.
"""
struct Region{F} <: AbstractShape
    f::F
end

# whether the point x (D coordinates) is in the shape; two-coordinate shapes act on (x, z)
xz(x) = (x[1], x[end])
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
