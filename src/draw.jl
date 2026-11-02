"""
    draw(layout::Layout; catalog=Catalog(), step=2, check, save, load, title="EasyDraw", shots=nothing, startdir=pwd())
    draw(file; kwargs...)
    draw(; L=[10, 5], nel=[20, 10], ni=2, kwargs...)

Open the drawing window on a layout, a layout file, or a new domain, and wait until it closes. Returns the `Layout`
when **Create…** wrote it, `nothing` after **Cancel** or when the window is closed.

The window has four steps, **Domain**, **Zones**, **Options** (only when the catalog has options) and **Run**; see
[Drawing in the window](@ref). The first window of a session takes about 20 s, while Qt loads; the next ones open at
once.

# Arguments
- `catalog`: what the window offers: a [`Catalog`](@ref), a `Dict` shaped like its TOML, or a catalog file.
- `step`: the step it opens on, 1 (Domain) to 4 (Run): 2 with a layout or a file, 1 for a new domain.
- `check`: `check(layout)` returns `(; errors, warnings, info)`, vectors of strings shown on the Run step: an error
  blocks Create…, a warning needs a second click. By default: the number of points, and the zones that reach outside
  the domain or hold no point.
- `save`: `save(layout, folder)` writes the layout into the folder chosen at Create…; by default as
  `<folder name>_layout.toml` ([`save_layout`](@ref)).
- `load`: `load(file)` returns the `Layout` that "Start from a file…" opens; by default [`load_layout`](@ref).
- `title`: the window's title.
- `shots`: `(dir, steps)`: instead of waiting, save a picture of each listed step into `dir` (`step1.png`, …) and
  close. For tests and documentation, offscreen (`QT_QPA_PLATFORM=offscreen`).
- `startdir`: the folder the file and folder dialogs start in.

# Throws
- `ArgumentError`: when a zone is a [`Region`](@ref) or a 3D shape, which the window cannot draw.

# Examples
```julia
l = draw()                                                      # a new domain
l = draw("model_layout.toml"; catalog="catalog.toml")           # edit a layout, with a host's catalog
```
"""
function draw(l::Layout; catalog=Catalog(), step::Integer=2, check::Function=default_check, save::Function=default_save,
              load::Function=load_layout, title::AbstractString="EasyDraw", shots=nothing, startdir=pwd())
    e = Editor(l, catalog; step, check, save, load, title)
    window(e; shots, startdir)
    return e.result
end
draw(file::AbstractString; kwargs...) = draw(load_layout(file); kwargs...)
draw(; L=[10.0, 5.0], nel=[20, 10], ni::Integer=2, kwargs...) = draw(Layout(; L, nel, ni); step=1, kwargs...)
