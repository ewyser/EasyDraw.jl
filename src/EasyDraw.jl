"""
    EasyDraw

Zones of a 2D (x–z) model, drawn in a window or written in code: shapes (`Polygon`, `Block`, `Ball`, `Region`) and
which points they contain (`inside`), named zones with properties (`Zone`; a point belongs to the last zone
containing it).
"""
module EasyDraw

export AbstractShape, Polygon, Block, Ball, Region, Zone, inside, inpolygon, polygon_rings

include("shapes.jl")
include("layout.jl")

end
