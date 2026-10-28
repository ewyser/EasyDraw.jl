"""
    EasyDraw

Zones of a 2D (x–z) model, drawn in a window or written in code: shapes (`Polygon`, `Block`, `Ball`, `Region`) and
which points they contain (`inside`), named zones with properties (`Zone`; a point belongs to the last zone
containing it), the model as a whole (`Layout`, `save_layout`/`load_layout`), and the window that draws it (`draw`,
the QML extension), whose properties, options and run settings come from its host's `Catalog`. For grid-based codes
a layout is sampled at any coordinates (`zone_at`, `zone_index`, `property`, `points`); for finite elements it is
split into disjoint regions (`partition`) and written as a Gmsh script (`write_geo`).
"""
module EasyDraw

using TOML

export AbstractShape, Polygon, Block, Ball, Region, Zone, inside, inpolygon, polygon_rings
export Layout, save_layout, load_layout, Field, Catalog, read_catalog, write_catalog, draw
export zone_at, zone_index, property, points, Partition, partition, write_geo

include("shapes.jl")
include("layout.jl")
include("catalog.jl")
include("cut.jl")
include("sample.jl")
include("partition.jl")
include("editor/helpers.jl")
include("editor/editor.jl")
include("editor/view.jl")
include("draw.jl")

end
