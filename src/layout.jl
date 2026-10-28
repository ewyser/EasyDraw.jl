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

# the sides of the domain [0, Lx] × [0, Lz]
const SIDES = ("left", "right", "bottom", "top")

"""
    Layout(; L, nel, ni=2, width=nothing, nely=nothing, zones=[], sides=Dict(), defaults=Dict(), options=Dict(),
             run=Dict(), folder="")

A 2D (x–z) model as drawn: the domain `[0, L[1]] × [0, L[2]]` with `nel` cells per axis and `ni`×`ni` points per
cell (where the window previews points; `ni = 1`: the cell centres), optionally extruded along y (`width`, `nely`
cells); its `zones` (a point belongs to the last zone containing it); a boundary kind per side (`sides`: `"left"`,
`"right"`, `"bottom"`, `"top"`); the default of each zone property (`defaults`, by key); the options (`options`,
nested by key: `"basis.which"` is `options["basis"]["which"]`) and run settings (`run`, by key); and the folder it
was created in (`folder`, set by the window's Create…). Values are kept as given (SI in, SI out). Written to and
read from TOML by `save_layout`/`load_layout`.
"""
struct Layout
    L        :: Vector{Float64}
    nel      :: Vector{Int}
    ni       :: Int
    width    :: Union{Nothing,Float64}
    nely     :: Union{Nothing,Int}
    zones    :: Vector{Zone}
    sides    :: Dict{String,String}
    defaults :: Dict{String,Any}
    options  :: Dict{String,Any}
    run      :: Dict{String,Any}
    folder   :: String
end
function Layout(; L, nel, ni::Integer=2, width=nothing, nely=nothing, zones=Zone[], sides=Dict{String,String}(),
                  defaults=Dict{String,Any}(), options=Dict{String,Any}(), run=Dict{String,Any}(), folder="")
    L, nel = Float64.(collect(L)), Int.(collect(nel))
    length(L) == length(nel) == 2 || throw(ArgumentError("a layout is 2D (x–z): L and nel need 2 entries each"))
    all(L .> 0) && all(nel .≥ 1) && ni ≥ 1 || throw(ArgumentError("L > 0, nel ≥ 1 and ni ≥ 1 are needed"))
    isnothing(width) == isnothing(nely) || throw(ArgumentError("extrude along y with both width and nely"))
    isnothing(width) || (width > 0 && nely ≥ 1) || throw(ArgumentError("width > 0 and nely ≥ 1 are needed"))
    s = Dict{String,String}(String(k) => String(v) for (k, v) ∈ sides)
    all(∈(SIDES), keys(s)) || throw(ArgumentError("sides are $(SIDES)"))
    strings(d) = Dict{String,Any}(String(k) => v isa AbstractDict ? strings(v) : v for (k, v) ∈ d)
    return Layout(L, nel, Int(ni), isnothing(width) ? nothing : Float64(width), isnothing(nely) ? nothing : Int(nely),
                  collect(Zone, zones), s, strings(defaults), strings(options), strings(run), String(folder))
end

"""
    save_layout(file, layout) -> file
    load_layout(file) -> Layout

A layout as TOML: `[domain]` (`L`, `nel`, `ni`, optionally `width` and `nely`), `[sides]`, `[defaults]`, `[options]`
(nested tables), `[run]` and one `[[zone]]` table per zone (`name`, its shape as `shape = "polygon"` with `vertices`
or `rings`, `"block"` with `lo`/`hi`, or `"ball"` with `centre`/`radius`, and its properties). A zone given by a
Julia predicate (`Region`) cannot be written. The folder is not written: it is where the file is.
"""
function save_layout(file::AbstractString, l::Layout)
    dom = Dict{String,Any}("L" => l.L, "nel" => l.nel, "ni" => l.ni)
    isnothing(l.width) || (dom["width"] = l.width; dom["nely"] = l.nely)
    zones = map(l.zones) do z
        d = shape_dict(z.shape)
        d["name"] = z.name
        foreach(((k, v),) -> d[string(k)] = v, z.props)
        d
    end
    d = Dict{String,Any}("domain" => dom, "sides" => l.sides, "defaults" => l.defaults, "options" => l.options, "run" => l.run,
                         "zone" => zones)
    mkpath(dirname(abspath(file)))
    open(io -> TOML.print(io, d; sorted=true), file, "w")
    return file
end
function load_layout(file::AbstractString)
    d = TOML.parsefile(file)
    haskey(d, "domain") || throw(ArgumentError("a layout file needs a [domain] table (L, nel)"))
    dom = d["domain"]
    known = ("name", "shape", "vertices", "rings", "lo", "hi", "centre", "radius")
    zones = map(enumerate(get(d, "zone", []))) do (i, z)
        name = String(get(z, "name", "zone $i"))
        Zone(name, parse_shape(z, name), Dict{Symbol,Any}(Symbol(k) => v for (k, v) ∈ z if k ∉ known))
    end
    return Layout(; L=dom["L"], nel=dom["nel"], ni=get(dom, "ni", 2), width=get(dom, "width", nothing), nely=get(dom, "nely", nothing),
                    zones, sides=get(d, "sides", Dict()), defaults=get(d, "defaults", Dict()), options=get(d, "options", Dict()),
                    run=get(d, "run", Dict()), folder=dirname(abspath(file)))
end
