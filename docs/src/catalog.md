# Catalogs

The window knows nothing of your program. What it offers comes from a [`Catalog`](@ref) that your program passes to
[`draw`](@ref):

- the **properties** a zone may set (ρ, η, …), on the Zones step;
- the **boundary kinds** a side may be, on the Domain step;
- the **options**, on the Options step, which is shown only when there are some;
- the **run settings**, on the Run step.

Without a catalog, zones have no properties and sides no kind: the window still draws zones.

## As a file

A catalog is easiest written as TOML, and passed as the file itself:

```toml
[boundary]
kinds   = ["free slip", "no slip"]
colors  = ["#4682b4", "#b22222"]
default = "free slip"

[[zone]]
key = "rho"
label = "ρ [kg/m³]"
default = 3300.0

[[zone]]
key = "eta"
label = "η [Pa s]"
default = 1.0e21

[[options]]                       # on the page "solver", the first part of the key
key = "solver.method"
kind = "menu"
values = ["direct", "iterative"]
default = "direct"

[[run]]
key = "nt"
kind = "integer"
label = "time steps"
default = 1000
min = 1
```

```julia
l = draw(; catalog="catalog.toml")
```

The window's **Load catalog…** (Domain step) loads another catalog file without restarting it; see
[Changing the catalog](@ref) below.

## Fields

Each `[[zone]]`, `[[options]]` and `[[run]]` table is a [`Field`](@ref). Its `key` is required; the rest is optional.

| `kind`      | the value                                                                          | the window shows      |
|:------------|:-----------------------------------------------------------------------------------|:----------------------|
| `"numeric"` | any number; a list of numbers when the default is one; `values` are presets        | a field, and presets  |
| `"integer"` | a whole number                                                                     | a field               |
| `"menu"`    | one of `values`                                                                    | a drop-down           |
| `"list"`    | several of `values`                                                                | check boxes           |

`"numeric"` is the default kind. A field can also set:

- `label`: what the window shows, the key by default;
- `default`: the value when none is set;
- `names`: the names the window shows for `values`, one per value;
- `scale`, for a zone property: the factor its value is shown with, e.g. `0.001` to show pascals as kilopascals. The
  layout keeps the value as given, in pascals;
- `min`, for an option or a run setting: the smallest number accepted;
- `show_if`, for a zone property or a run setting: show it only while each listed option or run setting has one of
  the listed values, e.g. `show_if = { "solver.method" = ["iterative"] }`. Options are always listed.

An option's key starts with its section, the page it is shown on: `"solver.method"` is on page `solver`.

## In code

A catalog can also be built from [`Field`](@ref)s, or given as plain data, a `Dict` shaped like the TOML. The latter
lets a program describe its catalog without depending on EasyDraw's types:

```julia
catalog = Catalog(; boundary=["free slip", "no slip"],
                    zone=[Field("rho"; label="ρ [kg/m³]", default=3300.0)],
                    run=[Field("nt", :integer; label="time steps", default=1000, min=1)])
catalog = Dict("boundary" => Dict("kinds" => ["free slip", "no slip"]),
               "zone"     => [Dict("key" => "rho", "label" => "ρ [kg/m³]", "default" => 3300.0)])
write_catalog("catalog.toml", catalog)      # either, as the file
```

## What comes back

The layout `draw` returns holds what was set:

- each zone's properties, in `zone.props` (by symbol, `z.props[:rho]`); a blank property is not set, and takes the
  layout's `defaults`;
- the boundary kind of each side, in `l.sides`;
- the options, in `l.options`, nested by the parts of their keys, and only those ticked:
  `get(get(l.options, "solver", Dict()), "method", "direct")`;
- the run settings, in `l.run`: `l.run["nt"]`.

## Your program's own hooks

What a file cannot hold, your program passes as functions:

```julia
l = draw(layout; catalog,
         check = l -> (; errors=String[], warnings=String[], info=["$(length(points(l).x)) markers"]),
         save  = (l, folder) -> my_write(joinpath(folder, "model.toml"), l),
         load  = file -> my_read(file),
         title = "MySolver")
```

- `check(layout)`: the checks on the Run step, as `(; errors, warnings, info)`: an error blocks **Create…**, a warning
  needs a second click.
- `save(layout, folder)`: what **Create…** writes into the chosen folder.
- `load(file)`: what **Start from a file…** reads, returning a `Layout`.
- `title`: the window's title.

ElastoPlasm.jl's `draw_case` is such a program; see [With ElastoPlasm.jl](@ref).

## Changing the catalog

**Load catalog…** replaces the catalog with another file's, e.g. your solver's, while drawing:

- Nothing drawn is lost. Each zone keeps all its properties: those the new catalog lists are shown, the others are
  carried through.
- Option overrides and run settings that are still valid are kept; the old catalog's other ones are dropped.
- A side whose boundary kind the new catalog lacks takes the new default.
- Undo does not undo the load: load the previous catalog back instead.
