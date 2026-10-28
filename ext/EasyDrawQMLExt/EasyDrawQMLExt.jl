# QML (Qt Quick) window for EasyDraw's `draw`: a thin view of an `Editor` (src/editor/). Install QML in your
# default environment (] activate; add QML) and `using QML` next to EasyDraw (or a package using it) to enable it.
module EasyDrawQMLExt

using QML
using EasyDraw: EasyDraw, Editor, background_json, overlay_json, panel_json, transform, press!, move!, release!, leave!, wheel!,
                zoom!, fit!, key!, set_step!, set_domain_field!, set_bc!, new_zone!, set_circle!, select_zone!, rename_zone!,
                set_prop!, swap_zone!, delete_zone!, set_picked!, remove_picked!, undo!, redo!, set_option!, type_option!,
                tick_option!, tick_value!, set_run!, pick_run!, ready!, create!, cancel!, load!, use_picture!, set_backdrop!, load_catalog!,
                remove_backdrop!, backdrop_size!, set_backdrop_field!, scale_bar!, apply_scale!, sections, julia_index,
                qml_index, localpath, fileurl, tab_steps, tab_step

const EDITOR = Ref{Editor}()                                 # the editor the open window shows
const QMLFILE = joinpath(@__DIR__, "EasyDraw.qml")

# ---- what QML calls (`Julia.<name>(…)`), on the open window's editor: QML's strings arrive as Julia strings, its
# 0-based indices go through `julia_index`; an action returns nothing (QML needs no editor back)

plain(x) = x isa AbstractString ? String(x) : x
act(f) = (args...) -> (f(EDITOR[], plain.(args)...); nothing)
todata(e, px, py, w, h) = transform(e, w, h).todata(px, py)
const CALLS = (;
    background = (w, h) -> background_json(EDITOR[], Float64(w), Float64(h)),
    overlay    = (w, h) -> overlay_json(EDITOR[], Float64(w), Float64(h)),
    panel      = () -> panel_json(EDITOR[]),
    press      = act((e, px, py, right, middle, w, h) -> press!(e, todata(e, px, py, w, h)...; right=Bool(right), pan=Bool(middle))),
    move       = act((e, px, py, w, h) -> move!(e, todata(e, px, py, w, h)...)),
    release    = act(release!),
    leave      = act(leave!),
    wheel      = act((e, px, py, angle, dx, dy, zoom, w, h) -> begin                    # a trackpad's pixels: content moves
                     t = transform(e, w, h)
                     wheel!(e, t.todata(px, py)..., Float64(angle), (dx/t.s, -dy/t.s); zoom=Bool(zoom))
                 end),
    pinch      = act((e, px, py, scale, w, h) -> zoom!(e, todata(e, px, py, w, h)..., 1/Float64(scale))),   # about its centre
    fit_view   = act(fit!),
    key        = act((e, name, cmd, shift) -> key!(e, name; cmd=Bool(cmd), shift=Bool(shift))),
    set_step   = act((e, i) -> set_step!(e, tab_step(e, julia_index(i)))),         # the tab's step
    set_field  = act(set_domain_field!),
    set_ni     = act((e, i) -> e.ni = julia_index(i)),
    set_bc     = act((e, side, j) -> set_bc!(e, side, e.catalog.boundary[julia_index(j)])),
    new_zone   = act((e, shape) -> new_zone!(e, Symbol(shape))),                  # "polygon", "rectangle", "triangle", "circle"
    set_circle = act(set_circle!),
    select_zone = act((e, i) -> select_zone!(e, julia_index(i))),
    rename_zone = act(rename_zone!),
    set_prop   = act(set_prop!),
    swap_zone  = act((e, d) -> swap_zone!(e, Int(d))),
    delete_zone = act(delete_zone!),
    set_picked = act(set_picked!),
    remove_picked = act(remove_picked!),
    undo       = act(undo!),
    redo       = act(redo!),
    toggle     = act((e, name, on) -> setfield!(e, Symbol(name), Bool(on))),     # the snapping and points check boxes
    set_section = act((e, i) -> e.section = sections(e.catalog)[julia_index(i)]),
    set_option = act((e, k, j) -> set_option!(e, k, julia_index(j))),
    type_option = act(type_option!),
    tick_option = act((e, k, on) -> tick_option!(e, k, Bool(on))),
    tick_value = act((e, k, i, on) -> tick_value!(e, k, julia_index(i), Bool(on))),
    pick_run   = act((e, key, j) -> pick_run!(e, key, julia_index(j))),         # a run setting's drop-down
    set_run    = act(set_run!),
    ready      = () -> ready!(EDITOR[]),
    create     = url -> create!(EDITOR[], localpath(String(url))),
    cancel     = act(cancel!),
    load       = act((e, url) -> load!(e, localpath(url))),
    load_catalog = act((e, url) -> load_catalog!(e, localpath(url))),             # Load catalog…
    use_picture = act((e, on) -> use_picture!(e, Bool(on))),                      # the Domain step's choice
    set_backdrop = act((e, url) -> set_backdrop!(e, localpath(url))),
    remove_backdrop = act(remove_backdrop!),
    backdrop_size = act(backdrop_size!),
    set_backdrop_field = act(set_backdrop_field!),
    scale_bar  = act(scale_bar!),
    apply_scale = act(apply_scale!),
)

# registered for each window: QML.jl forgets them when a window's application ends, so registering once
# (in __init__) left a second window of the same session with none
register_functions() = foreach(((name, f),) -> QML.qmlfunction(string(name), f), pairs(CALLS))

"""
    window(editor; shots=nothing, startdir=pwd())

Open the QML window on an `Editor` (`draw` makes one), blocking until Create…, Cancel or closing it; the editor's
`result` is then the layout, or `nothing`. With `shots = (dir, steps)` the window instead saves a PNG of each listed
step into `dir` and closes (for tests and documentation; run it with `QT_QPA_PLATFORM=offscreen`). Its file and
folder dialogs start in `startdir`.
"""
function EasyDraw.window(e::Editor; shots=nothing, startdir=pwd())
    EDITOR[] = e
    isnothing(shots) || (ENV["QT_QUICK_CONTROLS_STYLE"] = get(ENV, "QT_QUICK_CONTROLS_STYLE", "Fusion"))
    register_functions()
    steps = isnothing(shots) ? Int[] : filter(∈(tab_steps(e)), collect(Int, shots[2]))   # the steps it has
    loadqml(QMLFILE; shotdir=isnothing(shots) ? "" : shots[1], shotsteps=steps,                    # names, tabs
            shottabs=[qml_index(findfirst(==(s), tab_steps(e))) for s ∈ steps],
            startdir=fileurl(startdir))
    @info "Drawing window open: domain, zones, options and run, then click Create… (Cancel or closing the window aborts)"
    exec()
    return e
end

end
