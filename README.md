# EasyDraw.jl

EasyDraw lets you draw the zones of a 2D (x–z) model, by hand on a domain or over a scanned cross-section, and get
them back as data for your solver:

- **Finite differences, particles:** the zone or a property at any coordinates, e.g. on your grid.
- **Finite elements:** disjoint regions with shared edges, written as a Gmsh script.

The same zones can be written in code instead of drawn. A point belongs to the **last** zone that contains it, so a
zone drawn later overrides the ones below it.

## Install

EasyDraw is not registered yet. It lives in the ElastoPlasm.jl repository, in `lib/EasyDraw`:

```julia
] add https://github.com/ewyser/ElastoPlasm.jl:lib/EasyDraw
```

The drawing window needs QML (Qt Quick), installed in your default environment:

```julia
] activate
] add QML
```

If `using QML` then fails with a missing `_qt_version_tag` symbol, another package in your session (Plots/GR, for
one) already loads a different Qt. Pin QML's Qt libraries to that version; `draw()` without QML prints the command.
Everything except the window works without QML.

## Draw

```julia
using EasyDraw, QML
l = draw()                          # an empty domain; returns a Layout, or nothing if cancelled
l = draw("plume/plume_layout.toml") # edit a layout file
```

The window has four steps:

1. **Domain:** its size and cell size, points per cell, the boundary kind of each side. You can also choose
   *Picture to draw on*: load a picture, measure a scale bar on it, and the domain follows the picture.
2. **Zones:** polygons, rectangles, triangles and circles, with their properties. A new zone is cut out of the
   zones it overlaps. Clicks snap to vertices, edges and the grid.
3. **Options:** only shown if your catalog has options (see below).
4. **Run:** your run settings and the checks.

**Create…** asks for a folder, writes the layout there as `<folder name>_layout.toml`, and returns it.

## Or write it in code

```julia
using EasyDraw
l = Layout(; L=[100.0, 50.0], nel=[50, 25],                     # [0, 100] × [0, 50] m, 50 × 25 cells
             zones=[Zone("mantle", Block([0, 0], [100, 40]); rho=3300.0, eta=1e21),
                    Zone("plume",  Ball([50, 15], 8.0);       rho=3200.0, eta=1e19)])
save_layout("plume.toml", l); l = load_layout("plume.toml")
```

The shapes are:

- `Polygon(vertices)`: also several outlines, `Polygon(rings)`, for parts or holes (even–odd rule).
- `Block(lo, hi)`: an axis-aligned box.
- `Ball(centre, r)`: a disk.
- `Region(x -> …)`: any predicate on a point. It works in code only, and cannot be written to a file.

A zone's properties can have any name. Numbers are stored as `Float64`.

## Finite differences: sample on your grid

```julia
xc, zc = 1.0:2.0:99.0, 1.0:2.0:49.0           # e.g. the cell centres
phase = zone_index(l, xc, zc)                 # the zone of each point, 0 where none
rho   = property(l, "rho", xc, zc)            # a zone's value, else the layout's default, else NaN
eta   = property(l, "eta", xc, zc; default=1e21)
zone_at(l, (50.0, 15.0))                      # one point
p = points(l)                                 # (; x, z, zone): ni × ni points per cell, e.g. markers
```

Use any coordinates: cell centres, vertices, or a staggered grid's velocity points.

## Finite elements: regions for Gmsh

```julia
write_geo("plume.geo", l; h=1.0)              # then: gmsh plume.geo -2, or Gmsh.jl
part = partition(l)                           # the same as data
```

The partition holds:

- each zone where it applies: overlaps go to the later zone, and the zone is clipped to the domain;
- the rest of the domain as the background (zone 0);
- edges and vertices shared exactly by neighbouring regions, so the mesh is conforming.

In the `.geo` file there is:

- a `Physical Surface` per zone name, plus one called `"background"`;
- a `Physical Curve` per side of the domain (`"left"`, `"right"`, `"bottom"`, `"top"`).

Circles are inscribed 32-gons (`ngon`).

`Partition` gives the vertices, the edges with the region on each side, and each region's outline and holes.

## What the window offers: a catalog

The window's zone properties, boundary kinds, options and run settings come from a catalog that your code passes.
You can write it as TOML:

```toml
[boundary]
kinds  = ["free slip", "no slip"]
colors = ["#4682b4", "#b22222"]
default = "free slip"

[[zone]]
key = "rho"
label = "ρ [kg/m³]"
default = 3300.0

[[zone]]
key = "eta"
label = "η [Pa s]"
default = 1.0e21

[[options]]                                   # pages by the key's first part: "solver"
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
l = draw(; catalog="catalog.toml")            # the file itself (or read_catalog("catalog.toml"))
l.run["nt"]                                   # every run setting
get(get(l.options, "solver", Dict()), "method", "direct")   # options: only those ticked, as overrides of the default
```

The field kinds are:

- `menu`: one of `values`;
- `numeric`: any number, or a list of numbers when the default is one; `values` are presets;
- `integer`: a whole number;
- `list`: several of `values`.

Each field can also set:

- `scale`: the factor the window shows a value with, e.g. `0.001` for kPa;
- `min`: the smallest value accepted;
- `show_if`: show the field only while another one has one of the listed values, e.g.
  `show_if = { "solver.method" = ["iterative"] }`;
- `names`: the names the window shows for `values`.

A host can also give the catalog as plain data, a `Dict` shaped like this TOML (`Catalog(dict)`; `draw` takes
a `Catalog`, a `Dict` or a file), so that its code builds no EasyDraw type. `write_catalog` writes either as TOML.

In the window, **Load catalog…** (Domain step) loads another catalog file, e.g. your solver's, without restarting:

- Nothing drawn is lost. Each zone keeps all its properties: those the new catalog lists are shown, the others are
  carried through.
- Option overrides and run settings that are still valid are kept. The old catalog's other ones are dropped.
- A side whose boundary kind the new catalog lacks takes the new default.
- Undo does not undo the load: load the previous catalog back instead.

Your code can also pass functions for what a file cannot hold:

- `check(layout)`: the checks on the Run step, as `(; errors, warnings, info)`;
- `save(layout, folder)`: what **Create…** writes;
- `load(file)`: what "Start from a file…" reads;
- `title`: the window's title.

ElastoPlasm.jl's `draw_case` is one such host: its `get_catalog()` lists its material constants and solver options.

## Limits

- **2D (x–z) only.** A `width` and `nely` extrude a layout along y, and `zone_at` takes (x, y, z) points.
- **The picture is not saved.** It is a drawing aid only, not stored with the layout.
- **Zones are cut only when one is drawn.** Moving a zone afterwards can leave an overlap (the later zone wins) or a
  gap.
