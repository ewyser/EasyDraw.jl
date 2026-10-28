"""
    draw(layout=Layout(; L=[10, 5], nel=[20, 10]); catalog=Catalog(), step, check, save, load, title="EasyDraw",
         shots=nothing, startdir=pwd()) -> Layout or nothing
    draw(file; kwargs...)

Edit a layout (or a layout file) in a window, in four steps: **Domain** (optionally start from a file; draw on a
domain, dragging its corner or typing `Lx`, `Lz`, or on a picture, scaled by a scale bar measured on it, which the
domain then follows; the cell size; a width to extrude along y; points per cell; a boundary kind per side),
**Zones** (polygons, rectangles, triangles, circles, each with the properties the `catalog` lists; a new zone is cut
out of the earlier ones), **Options** (the catalog's options; ticked ones override their default) and **Run** (the
catalog's run settings, the checks). **Create…** asks for a folder, where the host's `save(layout, folder)` writes it
(by default `<folder name>_layout.toml`), and returns the layout; **Cancel** or closing the window returns `nothing`.
It opens on the domain step without a layout, on the zones step with one (`step`, 1–4). `catalog` is a `Catalog`,
a `Dict` shaped like its TOML (`Catalog(dict)`), or that TOML file, e.g. a solver's own (`Catalog(file)`); the window's
**Load catalog…** (Domain step) replaces it with another file's (`load_catalog!`). `check(layout)` gives the
Run step's errors, warnings and info (by default `default_check`); `load(file)` reads "Start from a file…" (by
default `load_layout`). With `shots = (dir, steps)` the window saves a PNG of each listed step into `dir` and closes
(tests, documentation).
"""
function draw(l::Layout; catalog=Catalog(), step::Integer=2, check::Function=default_check, save::Function=default_save,
              load::Function=load_layout, title::AbstractString="EasyDraw", shots=nothing, startdir=pwd())
    e = Editor(l, catalog; step, check, save, load, title)
    window(e; shots, startdir)
    return e.result
end
draw(file::AbstractString; kwargs...) = draw(load_layout(file); kwargs...)
draw(; L=[10.0, 5.0], nel=[20, 10], ni::Integer=2, kwargs...) = draw(Layout(; L, nel, ni); step=1, kwargs...)
