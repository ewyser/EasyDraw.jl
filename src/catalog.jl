"""
    Field

One entry of a [`Catalog`](@ref): a zone property, an option or a run setting, as the window shows it.

# Fields
- `key::String`: the key the value is stored under. An option's key starts with its section, the page it is shown
  on: `"solver.method"`.
- `kind::Symbol`: `:menu` (one of `values`), `:numeric` (any number, or a list of numbers when the default is one;
  `values` are presets), `:integer` (a whole number) or `:list` (several of `values`).
- `label::String`: what the window shows; the key by default.
- `values::Vector{Any}`: a menu's or a list's choices; a number's presets.
- `default::Any`: the value when none is set; `nothing` for none.
- `scale::Float64`: for a zone property, the factor the window shows its value with (`1e-3` shows pascals as
  kilopascals); the layout keeps the value as given.
- `min::Union{Nothing,Float64}`: for an option or a run setting, the smallest number the window accepts.
- `show_if::Dict{String,Vector{Any}}`: for a zone property or a run setting, show the field only while each of these
  options or run settings has one of the listed values. Options are always listed.
- `names::Vector{String}`: the names the window shows for `values`, one per value; none to show the values.

# Constructors
    Field(key, kind=:numeric; label=key, values=[], default=nothing, scale=1, min=nothing, show_if=Dict(), names=[])

# Throws
- `ArgumentError`: when `kind` is not one of the four, or `names` does not have one name per value.

# Examples
```jldoctest
julia> f = Field("eta"; label="η [Pa s]", default=1.0e21);

julia> f.kind, f.label
(:numeric, "η [Pa s]")
```
"""
struct Field
    key     :: String
    kind    :: Symbol
    label   :: String
    values  :: Vector{Any}
    default :: Any
    scale   :: Float64
    min     :: Union{Nothing,Float64}
    show_if :: Dict{String,Vector{Any}}
    names   :: Vector{String}
end
const KINDS = (:menu, :numeric, :integer, :list)
function Field(key::AbstractString, kind::Symbol=:numeric; label=key, values=[], default=nothing, scale=1.0, min=nothing,
               show_if=Dict{String,Vector{Any}}(), names=String[])
    kind ∈ KINDS || throw(ArgumentError("field $key: kind = $kind is not one of $(KINDS)"))
    isempty(names) || length(names) == length(values) || throw(ArgumentError("field $key: one name per value"))
    return Field(String(key), kind, String(label), collect(Any, values), default, Float64(scale),
                 isnothing(min) ? nothing : Float64(min), Dict{String,Vector{Any}}(String(k) => collect(Any, v) for (k, v) ∈ show_if),
                 String.(names))
end

"""
    Catalog

What the drawing window offers, given by its host program: the properties a zone may set, the boundary kinds, the
options and the run settings. An empty catalog gives zones without properties, sides without a kind, and no Options
step.

# Fields
- `zone::Vector{Field}`: the properties a zone may set.
- `boundary::Vector{String}`: the kinds of boundary a side may be.
- `colors::Vector{String}`: the colour each kind is drawn in (`"#4682b4"`), or none.
- `side::String`: the default kind, the first one unless given.
- `options::Vector{Field}`: the options, shown on pages by the first part of their keys.
- `run::Vector{Field}`: the run settings.

# Constructors
    Catalog(; zone=[], boundary=[], colors=[], side="", options=[], run=[])
    Catalog(dict)   # plain data shaped like the catalog's TOML (write_catalog), so a host builds no EasyDraw type
    Catalog(file)   # that TOML file, as read_catalog

# Throws
- `ArgumentError`: when there are colours but not one per kind, or `side` is not one of the kinds.

# Examples
```jldoctest
julia> c = Catalog(Dict("boundary" => Dict("kinds" => ["free slip", "no slip"]),
                        "zone"     => [Dict("key" => "rho", "label" => "ρ [kg/m³]", "default" => 3300.0)]));

julia> c.side, [f.key for f in c.zone]
("free slip", ["rho"])
```

See also [`write_catalog`](@ref), [`draw`](@ref).
"""
struct Catalog
    zone     :: Vector{Field}
    boundary :: Vector{String}
    colors   :: Vector{String}
    side     :: String
    options  :: Vector{Field}
    run      :: Vector{Field}
end
function Catalog(; zone=Field[], boundary=String[], colors=String[], side="", options=Field[], run=Field[])
    length(colors) ∈ (0, length(boundary)) || throw(ArgumentError("a colour per boundary kind, or none"))
    side = isempty(side) && !isempty(boundary) ? first(boundary) : String(side)
    isempty(boundary) || side ∈ boundary || throw(ArgumentError("the default side \"$side\" is not one of $(boundary)"))
    return Catalog(collect(Field, zone), String.(boundary), String.(colors), side, collect(Field, options), collect(Field, run))
end
Catalog(c::Catalog) = c
Catalog(file::AbstractString) = read_catalog(file)
function Catalog(d::AbstractDict)
    b = get(d, "boundary", Dict{String,Any}())
    return Catalog(; zone=parse_field.(get(d, "zone", [])), options=parse_field.(get(d, "options", [])), run=parse_field.(get(d, "run", [])),
                     boundary=get(b, "kinds", String[]), colors=get(b, "colors", String[]), side=get(b, "default", ""))
end
"The pages of a catalog's options: the first parts of their keys, in the catalog's order."
sections(c::Catalog) = unique(first(split(f.key, ".")) for f ∈ c.options)
"The field of `fields` with this key."
function field(fields, key)
    i = findfirst(f -> f.key == key, fields)
    isnothing(i) && throw(ArgumentError("no field $key"))
    return fields[i]
end

# ---- values: as typed or read (a value or its label) to the value the field holds

# a number list typed as text: "2.5, 2.5, 2.5" or "[2.5, 2.5, 2.5]"
function parse_numbers(s::AbstractString)
    t = split(strip(s, ['[', ']', ' ']), r"[,\s]+"; keepempty=false)
    v = tryparse.(Float64, t)
    return isempty(v) || any(isnothing, v) ? nothing : Float64.(v)
end
"""
    field_value(field::Field, x) -> value

The value of `field` for `x`, a value or the text the window got:

- for a menu, one of its `values`;
- for a number, any number (or a list of numbers, when its default is one), at least `min`, whole for `:integer`;
- for a list, a list of its values (or of their names).

# Throws
- `ArgumentError`: when `x` is none of these.

# Examples
```jldoctest
julia> EasyDraw.field_value(Field("nt", :integer; min=1), "250")
250
```
"""
function field_value(f::Field, x)
    if f.kind == :list
        x isa AbstractVector || throw(ArgumentError("$(f.key) is a list of $(string.(f.values))"))
        return [list_value(f, s) for s ∈ x]
    end
    i = findfirst(v -> string(v) == string(x), f.values)
    isnothing(i) || return f.values[i]
    f.kind ∈ (:numeric, :integer) || throw(ArgumentError("$(f.key) = $x is not one of $(string.(f.values))"))
    d = f.default
    y = x isa AbstractString ? (d isa AbstractVector ? parse_numbers(x) : tryparse(Float64, x)) : x
    if d isa AbstractVector
        y isa AbstractVector{<:Real} || throw(ArgumentError("$(f.key) = $x is not a list of numbers"))
        return Float64.(y)
    end
    y isa Real && !(y isa Bool) && isfinite(y) || throw(ArgumentError("$(f.key) = $x is not a number"))
    isnothing(f.min) || y ≥ f.min || throw(ArgumentError("$(f.key) = $x is below $(f.min)"))
    f.kind == :integer && !isinteger(y) && throw(ArgumentError("$(f.key) = $x is not an integer"))
    return f.kind == :integer ? Int(y) : Float64(y)
end
# a value of a list field, by its label or its name
function list_value(f::Field, s)
    i = something(findfirst(v -> string(v) == string(s), f.values), findfirst(==(string(s)), f.names), 0)
    i == 0 && throw(ArgumentError("$(f.key): $s is not one of $(string.(f.values))"))
    return f.values[i]
end

# ---- the catalog as TOML: [boundary] (kinds, colors, default) and one [[zone]], [[options]] or [[run]] table per field

function field_dict(f::Field)
    d = Dict{String,Any}("key" => f.key, "kind" => string(f.kind), "label" => f.label, "scale" => f.scale)
    isempty(f.values) || (d["values"] = f.values)
    isnothing(f.default) || (d["default"] = f.default)
    isnothing(f.min) || (d["min"] = f.min)
    isempty(f.show_if) || (d["show_if"] = f.show_if)
    isempty(f.names) || (d["names"] = f.names)
    return d
end
function parse_field(d::AbstractDict)
    haskey(d, "key") || throw(ArgumentError("a catalog field needs a key"))
    return Field(d["key"], Symbol(get(d, "kind", "numeric")); label=get(d, "label", d["key"]), values=get(d, "values", []),
                 default=get(d, "default", nothing), scale=get(d, "scale", 1.0), min=get(d, "min", nothing),
                 show_if=get(d, "show_if", Dict()), names=get(d, "names", String[]))
end
"""
    write_catalog(file, catalog) -> file

Write `catalog` (a [`Catalog`](@ref), or a `Dict` shaped like one) to `file` as TOML, making its folder if needed:

- `[boundary]`: `kinds`, `colors` and `default`;
- one `[[zone]]`, `[[options]]` or `[[run]]` table per field: `key`, `kind`, `label`, `values`, `default`, `scale`,
  `min`, `show_if`, `names`, all but `key` optional when written by hand.

# Examples
```jldoctest
julia> c = Catalog(; boundary=["free slip", "no slip"], zone=[Field("rho"; default=3300.0)]);

julia> file = write_catalog(joinpath(mktempdir(), "catalog.toml"), c);

julia> read_catalog(file).zone[1].default
3300.0
```

See also [`read_catalog`](@ref).
"""
function write_catalog(file::AbstractString, catalog)
    c = Catalog(catalog)
    d = Dict{String,Any}("zone" => field_dict.(c.zone), "options" => field_dict.(c.options), "run" => field_dict.(c.run))
    isempty(c.boundary) || (d["boundary"] = Dict{String,Any}("kinds" => c.boundary, "colors" => c.colors, "default" => c.side))
    mkpath(dirname(abspath(file)))
    open(io -> TOML.print(io, d), file, "w")
    return file
end
"""
    read_catalog(file) -> Catalog

Read a catalog from its TOML file, in the format [`write_catalog`](@ref) writes; the same as `Catalog(file)`.
"""
function read_catalog(file::AbstractString)
    return Catalog(TOML.parsefile(file))
end
