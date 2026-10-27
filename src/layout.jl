"""
    Zone(name, shape; props...)
    Zone(name, shape, props::AbstractDict)

A named part of a model: the points in `shape`, with properties `props` (any names; numbers are stored as
`Float64`, lists of numbers as `Vector{Float64}`, anything else as given). A point belongs to the last zone that
contains it.
"""
struct Zone
    name::String
    shape::AbstractShape
    props::Dict{Symbol,Any}
    function Zone(name::AbstractString, shape::AbstractShape, props::AbstractDict)
        number_list(v) = (v isa AbstractVector || v isa Tuple) && all(x -> x isa Real, v)
        p = Dict{Symbol,Any}(Symbol(k) => v isa Real ? Float64(v) : number_list(v) ? Float64.(collect(v)) : v for (k, v) ∈ props)
        return new(String(name), shape, p)
    end
end
Zone(name::AbstractString, shape::AbstractShape; props...) = Zone(name, shape, Dict{Symbol,Any}(props))
