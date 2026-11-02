"""
    EasyDraw

Draw the zones of a 2D (x–z) model in a window, or write them in code, and get them back as data for a solver: the
zone or a property at any coordinates, for finite differences and particles, or disjoint regions written as a Gmsh
script, for finite elements.

- Shapes and zones: [`Polygon`](@ref), [`Block`](@ref), [`Ball`](@ref), [`Region`](@ref), [`Zone`](@ref); a point
  belongs to the last zone that contains it.
- The model: [`Layout`](@ref), [`save_layout`](@ref), [`load_layout`](@ref).
- The window: [`draw`](@ref), offering what its host's [`Catalog`](@ref) lists.
- On a grid: [`zone_at`](@ref), [`zone_index`](@ref), [`property`](@ref), [`points`](@ref).
- For a mesher: [`partition`](@ref), [`write_geo`](@ref).
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
include("window/window.jl")
include("draw.jl")

end
