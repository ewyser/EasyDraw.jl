"""
    Field(key, kind=:numeric; label=key, values=[], default=nothing, scale=1, min=nothing, show_if=Dict(), names=[])

One entry of a `Catalog`: a zone property, an option or a run setting, by `key` (an option's key has its section
first, `"basis.which"`). `kind` is `:menu` (one of `values`), `:numeric` (any number, or list of numbers when the
default is one; `values` are presets), `:integer`, or `:list` (several of `values`). The window shows a value times
`scale` (e.g. 1e-3 for kPa) and the `names` of `values` when given; `min` bounds a number from below; `show_if`
(`key => values`) shows the field only while that option or run setting has one of these values.
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
    Catalog(; zone=[], boundary=[], colors=[], side="", options=[], run=[])
    Catalog(dict)
    Catalog(file)

What a drawing window offers, from its host: the properties a zone may set (`zone`, `Field`s), the kinds of
boundary each side may be (`boundary`, drawn in `colors`; `side` the default), the options (`options`, grouped
into pages by the first part of their key) and the run settings (`run`). Empty by default: zones without
properties, no boundaries and no options. A host may give it as plain data instead, a `Dict` shaped like the
catalog's TOML (`read_catalog`), so that it builds no EasyDraw type, or as that TOML file (e.g. a solver's own);
`draw` takes any of them.
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
    field_value(field, x) -> value

The value of `field` for `x`, a value or its label (text): one of its `values`; for a number field any number (or
list of numbers, when its default is one), at least `min`, whole for `:integer`; for a `:list` a list of its values
(or of their names). Throws an `ArgumentError` otherwise.
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
    read_catalog(file) -> Catalog

A catalog as TOML: `[boundary]` (`kinds`, `colors`, `default`) and a `[[zone]]`, `[[options]]` or `[[run]]` table per
field (`key`, `kind`, `label`, `values`, `default`, `scale`, `min`, `show_if`, `names`; all but `key` optional). The same
shape as a `Dict` is a catalog too (`Catalog(dict)`); `write_catalog` takes either.
"""
function write_catalog(file::AbstractString, catalog)
    c = Catalog(catalog)
    d = Dict{String,Any}("zone" => field_dict.(c.zone), "options" => field_dict.(c.options), "run" => field_dict.(c.run))
    isempty(c.boundary) || (d["boundary"] = Dict{String,Any}("kinds" => c.boundary, "colors" => c.colors, "default" => c.side))
    mkpath(dirname(abspath(file)))
    open(io -> TOML.print(io, d), file, "w")
    return file
end
read_catalog(file::AbstractString) = Catalog(TOML.parsefile(file))
