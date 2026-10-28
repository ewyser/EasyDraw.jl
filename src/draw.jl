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
It opens on the domain step without a layout, on the zones step with one (`step`, 1–4). `catalog` is a `Catalog`
or a `Dict` shaped like its TOML (`Catalog(dict)`). `check(layout)` gives the
Run step's errors, warnings and info (by default `default_check`); `load(file)` reads "Start from a file…" (by
default `load_layout`). With `shots = (dir, steps)` the window saves a PNG of each listed step into `dir` and closes
(tests, documentation).

The window is the QML extension of EasyDraw (`using QML`); without it, an error says how to install it.
"""
function draw(l::Layout; catalog=Catalog(), step::Integer=2, check::Function=default_check, save::Function=default_save,
              load::Function=load_layout, title::AbstractString="EasyDraw", shots=nothing, startdir=pwd())
    e = Editor(l, catalog; step, check, save, load, title)
    window(e; shots, startdir)
    return e.result
end
draw(file::AbstractString; kwargs...) = draw(load_layout(file); kwargs...)
draw(; L=[10.0, 5.0], nel=[20, 10], ni::Integer=2, kwargs...) = draw(Layout(; L, nel, ni); step=1, kwargs...)

"""
    window(editor; shots, startdir)

Show the window on `editor` until Create…, Cancel or closing it: defined by the QML extension; without it, an error
saying how to get it (`drawing_window_help`).
"""
window(e; kwargs...) = error(drawing_window_help())

# the Qt this session already loads (Plots/GR, for one, load Qt6Base_jll), which QML must be built for: "6.8.2", or nothing
function session_qt()
    m = [v for (k, v) ∈ Base.loaded_modules if k.name == "Qt6Base_jll"]
    isempty(m) && return nothing
    v = pkgversion(only(m))
    return "$(v.major).$(v.minor).$(v.patch)"
end

"""
    drawing_window_help(; installed, qt) -> String

What to do when the drawing window is missing: install QML, or load it. When the session already loads a Qt (`qt`,
e.g. through Plots/GR), every Qt library must be pinned to that version: a QML built for another Qt fails at
`using QML` with a missing `_qt_version_tag_…` symbol, before EasyDraw can say anything, hence the explanation here.
"""
function drawing_window_help(; installed::Bool=!isnothing(Base.find_package("QML")), qt=session_qt())
    if isnothing(qt)
        msg = installed ? "QML is installed but not loaded: run `using QML`." :
                          "install QML in your default environment (] activate; add QML), then `using QML`."
        return "the drawing window needs the QML extension: " * msg * " If `using QML` fails with a missing " *
               "`_qt_version_tag` symbol, another package loads a different Qt: pin QML's Qt libraries to that version."
    end
    pins = join(("$(p)@$(qt)" for p ∈ ("Qt6Base_jll", "Qt6Declarative_jll", "Qt6ShaderTools_jll", "Qt6Svg_jll", "Qt6Wayland_jll")), " ")
    fix  = "] activate; add QML $pins"
    why  = "a missing `_qt_version_tag` symbol, QML was built for another Qt than the $qt this session loads (through Plots/GR, for one)"
    msg  = installed ? "QML is installed but not loaded: run `using QML`. If it fails with $why; pin them together: $fix." :
                       "install QML in your default environment, with Qt pinned to the $qt this session loads (through Plots/GR, " *
                       "for one; otherwise `using QML` fails with a missing `_qt_version_tag` symbol): $fix, then `using QML`."
    return "the drawing window needs the QML extension: " * msg
end
