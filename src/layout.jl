"""
    Zone

A named part of a model: the points in its shape, with properties of any name. Where zones overlap, a point belongs
to the last zone that contains it.

# Fields
- `name::String`: the zone's name.
- `shape::AbstractShape`: its [`Polygon`](@ref), [`Block`](@ref), [`Ball`](@ref) or [`Region`](@ref).
- `props::Dict{Symbol,Any}`: its properties. A number is stored as a `Float64`, a list of numbers as a
  `Vector{Float64}`, anything else as given.

# Constructors
    Zone(name, shape; props...)
    Zone(name, shape, props::AbstractDict)

# Examples
```jldoctest
julia> z = Zone("lens", Ball([5, 2], 1.0); rho=2100, note="wet");

julia> z.props[:rho], z.props[:note]
(2100.0, "wet")
```

See also [`Layout`](@ref), [`zone_at`](@ref).
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
    Layout

A 2D (x–z) model, as drawn in the window or written in code: its domain, its zones, a boundary kind per side, and the
values its host's [`Catalog`](@ref) asks for. Values are kept as given: SI in, SI out.

# Fields
- `L::Vector{Float64}`: the domain's size `[Lx, Lz]`: the domain is `[0, Lx] × [0, Lz]`.
- `nel::Vector{Int}`: the number of cells along x and z.
- `ni::Int`: points per cell and axis, where the window previews points and [`points`](@ref) samples (`1`: the cell
  centres).
- `width::Union{Nothing,Float64}`: a width along y, to extrude the model in 3D; `nothing` in 2D.
- `nely::Union{Nothing,Int}`: the number of cells along y, with `width`.
- `zones::Vector{Zone}`: the zones, in order: where they overlap, the later one wins.
- `sides::Dict{String,String}`: a boundary kind per side, by `"left"`, `"right"`, `"bottom"` or `"top"`.
- `defaults::Dict{String,Any}`: each zone property's default, by key, for the zones that do not set it.
- `options::Dict{String,Any}`: the options set, nested by the parts of their keys: `"solver.method"` is
  `options["solver"]["method"]`. Only the options ticked in the window are there.
- `run::Dict{String,Any}`: the run settings, by key.
- `folder::String`: the folder the layout was created in (the window's Create…) or read from; `""` otherwise.

# Constructors
    Layout(; L, nel, ni=2, width=nothing, nely=nothing, zones=[], sides=Dict(), defaults=Dict(), options=Dict(),
             run=Dict(), folder="")

# Throws
- `ArgumentError`: when `L` or `nel` does not have 2 entries, a size or count is not positive, only one of `width`
  and `nely` is given, or a side is not one of the four.

# Examples
```jldoctest
julia> l = Layout(; L=[100, 50], nel=[50, 25], zones=[Zone("lens", Ball([50, 20], 5.0); rho=2100)]);

julia> l.L, l.nel, l.ni
([100.0, 50.0], [50, 25], 2)
```

See also [`save_layout`](@ref), [`draw`](@ref).
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
    save_layout(file, layout::Layout) -> file

Write `layout` to `file` as TOML, making its folder if needed:

- `[domain]`: `L`, `nel`, `ni`, and `width` and `nely` when the layout is extruded;
- `[sides]`, `[defaults]`, `[run]`, and `[options]` as nested tables;
- one `[[zone]]` table per zone: its `name`, its shape (`shape = "polygon"` with `vertices`, or `rings` for several
  outlines; `"block"` with `lo` and `hi`; `"ball"` with `centre` and `radius`) and its properties.

The folder is not written: it is where the file is.

# Throws
- `ArgumentError`: when a zone is a [`Region`](@ref), a Julia function, which a file cannot hold.

# Examples
```jldoctest
julia> l = Layout(; L=[10, 5], nel=[10, 5], zones=[Zone("base", Block([0, 0], [10, 2]); rho=2000)]);

julia> file = save_layout(joinpath(mktempdir(), "model_layout.toml"), l);

julia> load_layout(file).zones[1].props[:rho]
2000.0
```

See also [`load_layout`](@ref).
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
"""
    load_layout(file) -> Layout

Read a layout from its TOML file, in the format [`save_layout`](@ref) writes. Its `folder` is the file's folder.

Tables a layout does not have, from another program's file (an ElastoPlasm case file, say), are ignored with a
warning. A zone without a name is called `"zone i"`, by its position.

# Throws
- `ArgumentError`: when the file has no `[domain]` table, or a zone's `shape` is not `"polygon"`, `"block"` or
  `"ball"`.

See also [`draw`](@ref), which also takes a layout file.
"""
function load_layout(file::AbstractString)
    d = TOML.parsefile(file)
    haskey(d, "domain") || throw(ArgumentError("a layout file needs a [domain] table (L, nel)"))
    other = setdiff(keys(d), ("domain", "sides", "defaults", "options", "run", "zone"))   # another program's file?
    isempty(other) || @warn "$(basename(file)): not part of a layout, ignored: $(join(sort(collect(other)), ", ")). The zones' values are read as written."
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
