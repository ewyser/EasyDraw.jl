# EasyDraw's tests, run on their own (`] test EasyDraw` in an environment that has it) and from ElastoPlasm's suite
# (test/testset/test_easydraw.jl): shapes, zones, layouts and catalogs, the editor driven as a user would (everything
# but Qt), then the QML window itself, offscreen, where QML is installed
using Test, EasyDraw
const ED = EasyDraw

# a catalog as a host would give one: two zone properties (φ only for a frictional model), two boundary kinds,
# options of every kind on two pages, run settings shown by mode
const CAT = Catalog(; zone=[Field("E"; label="E [MPa]", scale=1e-6, default=1.0e6),
                            Field("phi"; label="φ [°]", scale=180/π, default=0.3, show_if=Dict("model.kind" => ["frictional"]))],
                      boundary=["free", "fixed"], colors=["#cccccc", "#b22222"],
                      options=[Field("model.kind", :menu; values=["frictional", "cohesive"], default="frictional"),
                               Field("model.damping"; values=[0.0, 0.1], default=0.1),
                               Field("grid.lengths"; values=[[1.0, 1.0]], default=[2.5, 2.5]),
                               Field("grid.n", :integer; values=[10, 20], default=10),
                               Field("plot.what", :list; values=["p", "q"], default=["p"], names=["pressure", "deviator"])],
                      run=[Field("mode", :menu; values=["fast", "slow"], default="fast"),
                           Field("dt"; label="dt [s]", default=0.1, min=0, show_if=Dict("mode" => ["fast"])),
                           Field("steps", :integer; default=10, min=1, show_if=Dict("mode" => ["slow"]))])
editor(l; kwargs...) = ED.Editor(l, CAT; kwargs...)
const L1, L2 = 64.1584, 64.1584/4                            # a 4:1 domain (the slump's)
click!(e, x, z) = (ED.move!(e, x, z); ED.press!(e, x, z); ED.release!(e))
# a plain grey picture, w × h px (BMP: no compression to write)
function write_bmp(file, w, h)
    row = 4*cld(3w, 4)                                       # rows padded to 4 bytes
    open(file, "w") do io
        write(io, b"BM", UInt32(54 + row*h), UInt32(0), UInt32(54))
        write(io, UInt32(40), Int32(w), Int32(h), UInt16(1), UInt16(24), UInt32(0), UInt32(row*h), Int32(2835), Int32(2835), UInt32(0), UInt32(0))
        foreach(_ -> write(io, fill(0xc8, row)), 1:h)
    end
    return file
end

@testset "EasyDraw" verbose = true begin
    @testset "shapes" begin
        @test inside(Block([0, 0], [1, 1]), [1.0, 0.0]) && !inside(Block([0, 0], [1, 1]), [1.0 + 1e-12, 0.5])   # bounds included
        @test inside(Block([0, 0], [1, 1]), [0.5, 9.0, 1.0])                                    # (x, z) box extruded along y
        @test inside(Block([0, 0, 0], [1, 1, 1]), [0.5, 0.5, 0.5]) && !inside(Block([0, 0, 0], [1, 1, 1]), [0.5, 2.0, 0.5])
        @test inside(Ball([0, 0], 1.0), [0.6, 0.8]) && !inside(Ball([0, 0], 1.0), [0.6, 0.81])
        @test inside(Ball([0, 0, 0], 1.0), [0.0, 0.6, 0.8]) && inside(Ball([0, 0], 1.0), [0.6, 5.0, 0.8])   # sphere; cylinder
        ell = Polygon([[0, 0], [2, 0], [2, 1], [1, 1], [1, 2], [0, 2]])                          # concave
        @test inside(ell, [0.5, 1.5]) && inside(ell, [1.5, 0.5]) && !inside(ell, [1.5, 1.5])
        @test inside(Region(x -> x[1] > x[end]), [2.0, 1.0])
        @test_throws ArgumentError Polygon([[0, 0], [1, 0]])
        donut = Polygon([[[0, 0], [4, 0], [4, 4], [0, 4]], [[1, 1], [3, 1], [3, 3], [1, 3]], [[5, 0], [6, 0], [6, 1]]])   # several outlines:
        @test inside(donut, [0.5, 0.5]) && !inside(donut, [2.0, 2.0]) && inside(donut, [5.8, 0.2])   # a hole, a second part
        @test donut.sizes == [4, 4, 3]
        @test_throws ArgumentError Polygon([[[0, 0], [1, 0], [1, 1]], [[2, 2], [3, 3]]])
        @test_throws ArgumentError Block([1, 0], [0, 1])
    end
    @testset "zones" begin
        z = Zone("z", Block([0, 0], [1, 1]); E=1, v=(1, -2), note="any")
        @test z.props == Dict(:E => 1.0, :v => [1.0, -2.0], :note => "any") && z.props[:E] isa Float64
        @test Zone("z", Ball([0, 0], 1.0), Dict("k" => 3)).props[:k] === 3.0
    end
    @testset "layouts and their files" begin
        l = Layout(; L=[20, 10], nel=[20, 10], ni=3, width=4.0, nely=4, sides=Dict("bottom" => "fixed"), defaults=Dict("E" => 2e6),
                     options=Dict("model" => Dict("kind" => "cohesive")), run=Dict("steps" => 5),
                     zones=[Zone("soil", Polygon([[0, 0], [20, 0], [20, 6], [0, 6]]); E=5e7), Zone("boulder", Ball([10, 4], 1.0); v=[0, -1]),
                            Zone("lens", Polygon([[[2, 2], [8, 2], [8, 5], [2, 5]], [[4, 3], [5, 3], [5, 4]]])), Zone("rock", Block([0, 0], [20, 2]))])
        f = save_layout(joinpath(mktempdir(), "l.toml"), l); back = load_layout(f)
        @test (back.L, back.nel, back.ni, back.width, back.nely, back.sides, back.defaults, back.options, back.run) ==
              (l.L, l.nel, l.ni, l.width, l.nely, l.sides, l.defaults, l.options, l.run) && back.folder == dirname(f)
        @test [z.name for z ∈ back.zones] == ["soil", "boulder", "lens", "rock"] && back.zones[1].props == Dict(:E => 5e7)
        @test back.zones[2].shape.radius == 1.0 && back.zones[2].props[:v] == [0.0, -1.0] && back.zones[3].shape.sizes == [4, 3]
        @test_throws ArgumentError Layout(; L=[1, 1, 1], nel=[1, 1, 1])                       # 2D only
        @test_throws ArgumentError Layout(; L=[1, 1], nel=[1, 1], sides=Dict("front" => "x"))
        @test_throws ArgumentError save_layout(joinpath(mktempdir(), "r.toml"), Layout(; L=[1, 1], nel=[1, 1], zones=[Zone("r", Region(x -> true))]))
    end
    @testset "sampling: zones, properties, points" begin
        l = Layout(; L=[4, 2], nel=[4, 2], ni=1, defaults=Dict("rho" => 1000.0),
                     zones=[Zone("a", Block([0, 0], [4, 1]); rho=2000), Zone("b", Block([1, 0.5], [3, 1.5]); eta=5)])
        @test zone_at(l, (0.5, 0.5)) == 1 && zone_at(l, (2.0, 0.75)) == 2 && zone_at(l, (0.5, 1.5)) == 0   # the last zone wins
        @test zone_at(l, (2.0, 7.0, 0.75)) == 2                                             # extruded: (x, y, z)
        xs, zs = 0.5:1.0:3.5, 0.5:1.0:1.5                                                  # the cell centres
        @test zone_index(l, xs, zs) == [1 0; 2 2; 2 2; 1 0]
        @test property(l, "rho", xs, zs) == [2000 1000; 1000 1000; 1000 1000; 2000 1000]   # b does not set it: the default
        @test isequal(property(l, :eta, xs, zs), [NaN NaN; 5 5; 5 5; NaN NaN])           # no default: NaN
        p = points(l); @test p.zone == [1, 2, 2, 1, 2, 2] && (p.x[2], p.z[2]) == (1.5, 0.5)   # ni = 1: the cell centres
    end
    @testset "partition: disjoint regions, shared edges, sides" begin
        area(p, r) = ED.signed_area(p.vertices, r.outer) + sum((ED.signed_area(p.vertices, h) for h ∈ r.holes); init=0.0)
        zone_area(p, k) = sum(area(p, r) for r ∈ p.regions if r.zone == k)
        l = Layout(; L=[4, 2], nel=[4, 2], zones=[Zone("a", Block([0, 0], [4, 1])), Zone("b", Block([1, 0.5], [3, 1.5])),
                                                  Zone("c", Block([-1, 1.5], [0.5, 3]))])  # reaching out of the domain
        p = partition(l)
        @test zone_area(p, 1) ≈ 3 && zone_area(p, 2) ≈ 2 && zone_area(p, 3) ≈ 0.25 && zone_area(p, 0) ≈ 8 - 5.25   # a minus b; clipped
        @test all(r -> area(p, r) > 0 && isempty(r.holes), p.regions) && sum(r -> area(p, r), p.regions) ≈ 8
        @test all(k -> p.left[k] != p.right[k], eachindex(p.edges))                        # an edge between two regions
        @test all(k -> (p.side[k] == "") == (-1 ∉ (p.left[k], p.right[k])), eachindex(p.edges))
        len(k) = hypot((p.vertices[p.edges[k][2]] .- p.vertices[p.edges[k][1]])...)
        @test [sum(len(k) for k ∈ findall(==(s), p.side)) for s ∈ ED.SIDES] ≈ [2, 2, 4, 4]   # the domain's sides, covered
        @test length(unique(p.vertices)) == length(p.vertices) && [0.0, 1.0] ∈ p.vertices && [3.0, 1.0] ∈ p.vertices   # shared
        @test count(r -> r.zone == 1, partition(l; background=false).regions) == 1 && all(r -> r.zone > 0, partition(l; background=false).regions)
        ring = Layout(; L=[10, 10], nel=[10, 10], zones=[Zone("ring", Polygon([[[2, 2], [8, 2], [8, 8], [2, 8]], [[4, 4], [6, 4], [6, 6], [4, 6]]])),
                                                         Zone("disk", Ball([5, 5], 3.0))])        # over the ring's hole
        q = partition(ring; ngon=24)
        n = 24; disk = n/2*9*sin(2π/n)                                                     # the inscribed 24-gon's area
        @test isapprox(zone_area(q, 2), disk; rtol=1e-12) && isapprox(zone_area(q, 1), 36 - disk; rtol=1e-12)
        @test isapprox(zone_area(q, 0), 64; rtol=1e-12)
        @test count(r -> r.zone == 0, q.regions) == 1 && length(only(r for r ∈ q.regions if r.zone == 0).holes) == 1   # around the ring
        @test_throws ArgumentError partition(Layout(; L=[1, 1], nel=[1, 1], zones=[Zone("r", Region(x -> true))]))
        g = read(write_geo(joinpath(mktempdir(), "l.geo"), l; h=0.25), String)
        @test count("\nPoint(", g) == length(p.vertices) && count("\nLine(", g) == length(p.edges) && occursin("h = 0.25;", g)
        @test count("\nPlane Surface(", g) == length(p.regions) && all(n -> occursin("Physical Surface(\"$n\")", g), ["a", "b", "c", "background"])
        @test all(s -> occursin("Physical Curve(\"$s\")", g), ED.SIDES)
    end
    @testset "catalogs: fields, values, files" begin
        f = Field("n", :integer; values=[1, 2], default=1, min=1)
        @test ED.field_value(f, "2") === 2 && ED.field_value(f, 3.0) === 3
        @test_throws ArgumentError ED.field_value(f, "0")
        @test_throws ArgumentError ED.field_value(f, "1.5")
        @test_throws ArgumentError ED.field_value(f, "x")
        @test ED.field_value(ED.field(CAT.options, "grid.lengths"), "[1, 2]") == [1.0, 2.0]
        @test ED.field_value(ED.field(CAT.options, "plot.what"), ["deviator", "p"]) == ["q", "p"]    # by name or value
        @test_throws ArgumentError ED.field_value(ED.field(CAT.options, "model.kind"), "elastic")
        @test_throws ArgumentError Field("x", :slider)
        @test_throws ArgumentError Catalog(; boundary=["a"], side="b")
        @test CAT.side == "free" && ED.sections(CAT) == ["model", "grid", "plot"]
        back = read_catalog(write_catalog(joinpath(mktempdir(), "c.toml"), CAT))
        @test (back.boundary, back.colors, back.side) == (CAT.boundary, CAT.colors, CAT.side)
        @test all(k -> ED.field_dict.(getfield(back, k)) == ED.field_dict.(getfield(CAT, k)), (:zone, :options, :run))
        @test isempty(read_catalog(write_catalog(joinpath(mktempdir(), "e.toml"), Catalog())).options)
        d = Dict("zone" => [Dict("key" => "rho", "default" => 3300.0)], "boundary" => Dict("kinds" => ["a", "b"], "default" => "b"),
                 "run" => [Dict("key" => "nt", "kind" => "integer", "min" => 1)])               # plain data, as a host may give it
        c = Catalog(d); @test only(c.zone).default == 3300.0 && c.side == "b" && only(c.run).kind == :integer && Catalog(c) === c
        @test ED.Editor(Layout(; L=[1, 1], nel=[1, 1]), d).catalog.side == "b"                 # the window takes it as is
    end
    @testset "drawing a zone" begin
        e = editor(Layout(; L=[L1, L2], nel=[40, 10]))
        ED.new_zone!(e)
        foreach(p -> click!(e, p...), [(0.1, 0.05), (64.1, 0.1), (64.0, 1.95), (22.5, 12.05), (0.05, 12.0), (0.2, 0.1)])   # last: closes
        ED.set_prop!(e, "phi", "7.5")
        @test ED.ready!(e) && ED.create!(e, joinpath(mktempdir(), "drawn")) && e.result isa Layout && length(e.result.zones) == 1
        v = e.result.zones[1].shape.vertices
        @test length(v) == 5 && v[1] == [0.0, 0.0] && v[4][2] ≈ 15*L2/20                  # snapped to the sub-cell lattice
        @test e.result.zones[1].props[:phi] ≈ 7.5*π/180 rtol=1e-14
    end
    @testset "closing on the first vertex" begin
        e = editor(Layout(; L=[L1, L2], nel=[40, 10]))
        ED.new_zone!(e); click!(e, 10.0, 2.0); click!(e, 30.0, 2.0)
        first = copy(e.drawing[1]); near = first .+ 0.3                                     # within the snap radius
        ED.move!(e, near...); @test e.cursor[2] != :close                                   # 2 vertices: no closing yet
        ED.press!(e, near...); ED.release!(e); @test length(e.drawing) == 2                 # and no repeated first vertex
        click!(e, 30.0, 8.0)
        ED.move!(e, near...)
        @test e.cursor == (first, :close) && occursin("close", e.readout)                  # snapped onto it
        @test occursin("\"r\":9", ED.overlay_json(e, 800.0, 600.0))                           # drawn as the closing marker
        ED.press!(e, near...); ED.release!(e)
        @test isnothing(e.drawing) && length(e.regions) == 1                                # closed, exactly on it:
        @test e.regions[1].vertices[1] == first && length(e.regions[1].vertices) == 3       # no extra vertex
    end
    @testset "snap radius follows the zoom; the cursor's colour and shape" begin
        e = editor(Layout(; L=[L1, L2], nel=[40, 10], zones=[Zone("base", Block([0, 0], [L1, 4]))]))
        v = [0.0, 4.0]; @test v ∈ e.regions[1].vertices
        r0 = ED.tol(e); ED.zoom!(e, 5.0, 4.0, 0.1); @test ED.tol(e) ≈ 0.1r0               # 10× in: a 10× smaller radius
        ED.move!(e, (v .+ 0.5r0)...);  @test e.cursor[2] == :grid                          # no longer on the vertex
        ED.move!(e, (v .+ 0.05r0)...); @test e.cursor[2] == :vertex
        ED.fit!(e)
        cur() = ED.cursor_json(e, (x, z) -> [x, z])
        ED.move!(e, v...);      @test cur().color == "#9ca3af" && cur().shape == "square"   # not drawing: grey
        ED.move!(e, 30.0, 4.0); @test cur().color == "#9ca3af" && cur().shape == "diamond"  # on the base's top edge
        ED.new_zone!(e); ED.move!(e, 30.0, 9.0)
        @test cur().color == "#dc2626" && cur().shape == "ring"                             # drawing: red
        @test occursin("\"drawing\":true", ED.panel_json(e))                              # the crosshair, the highlighted button
    end
    @testset "navigating: dragging the canvas, the middle button, a trackpad, fitting" begin
        e = editor(Layout(; L=[L1, L2], nel=[40, 10], zones=[Zone("base", Block([0, 0], [L1, 4]))])); v0 = e.view
        ED.zoom!(e, 10.0, 2.0, 0.5); v = e.view
        ED.press!(e, 20.0, 8.0); @test !isnothing(e.grab) && occursin("\"panning\":true", ED.panel_json(e))   # on nothing: pans
        ED.move!(e, 25.0, 9.0); @test all(e.view .≈ v .- (5.0, 5.0, 1.0, 1.0))               # the grabbed point follows the cursor
        ED.release!(e); @test isnothing(e.grab)
        ED.press!(e, 30.0, 4.0); @test isnothing(e.grab) && !isempty(e.drag); ED.release!(e)   # on an edge: an edit, not a pan
        ED.new_zone!(e); click!(e, 10.0, 8.0); v = e.view
        ED.press!(e, 12.0, 8.0; pan=true); ED.move!(e, 11.0, 8.0); ED.release!(e)            # the middle button, while drawing
        @test length(e.drawing) == 1 && all(e.view .≈ v .+ (1.0, 1.0, 0.0, 0.0))
        v = e.view; ED.wheel!(e, 10.0, 8.0, 0.0, (2.0, -1.0))                                 # two fingers: the content follows
        @test all(e.view .≈ v .- (2.0, 2.0, -1.0, -1.0))
        v = e.view; ED.wheel!(e, 10.0, 8.0, 120.0, (2.0, -1.0); zoom=true); @test e.view[2] - e.view[1] ≈ 0.9(v[2] - v[1])   # Cmd: zoom
        v = e.view; ED.wheel!(e, 10.0, 8.0, -120.0, (0.0, 0.0)); @test e.view[2] - e.view[1] ≈ (v[2] - v[1])/0.9   # a mouse wheel: zoom
        ED.set_step!(e, 1); ED.press!(e, 1.0, 1.0); @test !isnothing(e.grab) && !e.resizing; ED.release!(e)   # away from the corner
        ED.set_step!(e, 3); ED.press!(e, 1.0, 1.0); @test !isnothing(e.grab); ED.release!(e)   # options: the canvas only pans
        ED.set_step!(e, 2); @test e.view == v0                                                # fitted (also the Fit view button)
        t = ED.transform(e, 800.0, 600.0); P = ED.PAD                                       # a 4:1 domain on a 4:3 canvas:
        @test t.box == (P.left, P.top, 800 - P.left - P.right, 600 - P.top - P.bottom)      # the axes fill the canvas,
        @test all(t.view[1:2] .≈ e.view[1:2]) && t.view[3] < e.view[3] && t.view[4] > e.view[4]  # widened along z only,
        @test all(t.todata(t.topx(3.0, 2.0)...) .≈ (3.0, 2.0)) && all(t.topx(1.0, 1.0) .- t.topx(0.0, 0.0) .≈ (t.s, -t.s))   # equal scales
    end
    @testset "the selected zone: clicked inside; zones drawn where they apply" begin
        e = editor(Layout(; L=[L1, L2], nel=[40, 10], zones=[Zone("base", Block([0, 0], [L1, 4])), Zone("top", Block([0, 4], [L1, 8]))]))
        @test e.selected == 1
        click!(e, 30.0, 6.0); @test e.selected == 2                                          # a click inside a zone selects it
        ED.press!(e, 30.0, 2.0); ED.move!(e, 35.0, 2.0); ED.release!(e); @test e.selected == 2   # a drag pans, keeps it
        j = ED.overlay_json(e, 800.0, 600.0)                                                  # drawn where it applies: outside
        @test occursin("\"selected\":false,\"later\":[1]", j) && occursin("\"selected\":true,\"later\":[]", j)   # the later zones
        push!(e.regions, ED.circle_region("lens", [50.0, 12.0], 1.0, Dict{String,Float64}()))   # away from both: covers neither
        @test occursin("\"later\":[1]", ED.overlay_json(e, 800.0, 600.0)) && !occursin("\"later\":[1,2]", ED.overlay_json(e, 800.0, 600.0))
        @test occursin("\"color\":\"$(ED.zone_color(2))\"", ED.panel_json(e))                # its swatch in the panel
    end
    @testset "a new zone is cut out of the earlier ones" begin
        rock = [Zone("rock", Block([0, 0], [20, 8]))]                                      # on a 0.5 m lattice
        fresh() = editor(Layout(; L=[40, 20], nel=[40, 20], zones=rock))
        rect!(e, a, b) = (ED.new_zone!(e, :rectangle); click!(e, a...); click!(e, b...))
        points(e, rs=e.regions) = ED.drawn_points(e.L, e.nel, e.ni, rs)
        e = fresh(); before = deepcopy(e.regions)                                           # a notch
        rect!(e, (10, 4), (30, 12))
        @test Set(e.regions[1].vertices) == Set([[0.0, 0], [20, 0], [20, 4], [10, 4], [10, 8], [0, 8]]) && e.regions[1].sizes == [6]
        @test [20.0, 4.0] ∈ e.regions[2].vertices && [10.0, 8.0] ∈ e.regions[2].vertices   # where they cross: shared vertices
        @test points(e) == points(e, [before; e.regions[2]]) && e.status == "Cut out of rock."   # the points: as before (later wins)
        ED.undo!(e); @test length(e.regions) == 1 && e.regions[1].vertices == before[1].vertices   # one undo step
        e = fresh(); rect!(e, (0, 3), (20, 5))                                              # a band across: two parts
        @test e.regions[1].sizes == [4, 4] && points(e) == points(e, [before; e.regions[2]])
        ED.press!(e, 0.0, 0.0; right=true); @test sort(e.regions[1].sizes) == [3, 4]             # an outline's vertex deleted …
        ED.press!(e, 20.0, 0.0; right=true); @test sort(e.regions[1].sizes) == [3, 4]            # … down to 3
        click!(e, 10.0, 8.0); @test sort(e.regions[1].sizes) == [3, 5]                            # one inserted on the other outline
        e = fresh(); ED.new_zone!(e, :circle); click!(e, 10, 4); click!(e, 11, 4)            # a circle inside: a hole
        @test sort(e.regions[1].sizes) == [4, 32] && ED.iscircle(e.regions[2]) && points(e) == points(e, [before; e.regions[2]])
        e = fresh(); rect!(e, (20, 0), (30, 8)); @test e.regions[1].sizes == [4] && e.status == ""   # beside it: unchanged
        e = fresh(); rect!(e, (0, 0), (30, 12))                                             # over all of it: removed
        @test length(e.regions) == 1 && e.selected == 1 && e.status == "Covered by it, removed: rock."
    end
    @testset "the picked vertex, typed" begin
        e = editor(Layout(; L=[20.0, 10.0], nel=[20, 10],
                           zones=[Zone("A", Block([0, 0], [20, 4])), Zone("B", Polygon([[0, 4], [20, 4], [20, 8], [0, 8]]))]))
        A, B = () -> e.regions[1].vertices, () -> e.regions[2].vertices
        @test isnothing(e.picked) && occursin("\"vertex\":null", ED.panel_json(e))         # nothing picked: no row
        ED.move!(e, 20.0, 4.0); ED.press!(e, 20.0, 4.0); ED.release!(e)                     # click the shared corner
        @test e.picked == [20.0, 4.0] && e.selected == 2 && occursin("\"vertex\":{\"x\":\"20.0\",\"z\":\"4.0\"}", ED.panel_json(e))
        ED.set_picked!(e, "z", "5")
        @test [20.0, 5.0] ∈ A() && [20.0, 5.0] ∈ B() && [20.0, 4.0] ∉ A() && e.picked == [20.0, 5.0]   # moved in both zones
        ED.set_picked!(e, "x", "abc"); @test e.picked == [20.0, 5.0]                         # not a number: ignored
        ED.undo!(e); @test [20.0, 4.0] ∈ B() && occursin("\"vertex\":null", ED.panel_json(e))   # the picked one is gone
        ED.move!(e, 0.0, 8.0); ED.press!(e, 0.0, 8.0); ED.release!(e); n = length(B())
        ED.remove_picked!(e); @test length(B()) == n - 1 && isnothing(e.picked)              # deleted
        @test occursin("\"picked\":null", ED.overlay_json(e, 800.0, 600.0))
    end
    @testset "new zones: rectangle, triangle" begin
        e = editor(Layout(; L=[20.0, 10.0], nel=[20, 10], zones=[Zone("base", Block([0, 0], [20, 2]))]))
        ED.new_zone!(e, :rectangle); click!(e, 4.0, 2.0); click!(e, 4.0, 6.0)               # not opposite corners
        @test length(e.regions) == 1 && occursin("opposite", e.status)
        click!(e, 10.0, 6.0)
        @test length(e.regions) == 2 && isnothing(e.drawing) && Set(e.regions[2].vertices) == Set([[4.0, 2.0], [10.0, 2.0], [10.0, 6.0], [4.0, 6.0]])
        @test [4.0, 2.0] ∈ e.regions[1].vertices && [10.0, 2.0] ∈ e.regions[1].vertices     # corners on the base: shared
        ED.new_zone!(e, :triangle); click!(e, 12.0, 2.0); click!(e, 18.0, 2.0)
        ED.move!(e, 15.0, 7.0); @test length(ED.sketch_px(e, (x, z) -> [x, z])) == 4          # closed back to its first corner
        click!(e, 15.0, 7.0)
        @test length(e.regions) == 3 && isnothing(e.drawing) && length(e.regions[3].vertices) == 3   # closes on its third
        @test_throws ArgumentError ED.new_zone!(e, :hexagon)
    end
    @testset "circles (Ball zones)" begin
        l = Layout(; L=[1.0, 1.0], nel=[20, 20], zones=[Zone("disk 1", Ball([0.25, 0.25], 0.1); v=[1.0, 1.0]),
                                                        Zone("disk 2", Ball([0.75, 0.75], 0.1); v=[-1.0, -1.0])])
        e = editor(l)
        @test all(ED.iscircle, e.regions) && e.regions[1].centre == [0.25, 0.25] && e.regions[1].radius == 0.1
        back = ED.current_layout(e).zones
        @test all(i -> back[i].shape isa Ball && back[i].shape.centre == l.zones[i].shape.centre &&
                       back[i].shape.radius == l.zones[i].shape.radius && back[i].props[:v] == l.zones[i].props[:v], 1:2)
        ED.new_zone!(e, :circle); click!(e, 0.5, 0.5); click!(e, 0.6, 0.5)                          # centre, then a point on it
        c = e.regions[3]; @test ED.iscircle(c) && c.centre == [0.5, 0.5] && c.radius ≈ 0.1 && e.selected == 3
        ED.move!(e, 0.5, 0.5); ED.press!(e, 0.5, 0.5); ED.move!(e, 0.7, 0.6); ED.release!(e)  # drag the centre
        @test c.centre ≈ [0.7, 0.6] && c.radius ≈ 0.1
        h = ED.radius_handle(c); ED.move!(e, h...); ED.press!(e, h...); ED.move!(e, 0.95, 0.6); ED.release!(e)
        @test c.radius ≈ 0.25                                                               # the handle sets the radius
        ED.set_circle!(e, "r", "0.15"); ED.set_circle!(e, "r", "-1"); @test c.radius == 0.15   # typed; ≤ 0 ignored
        ED.undo!(e); @test e.regions[3].radius ≈ 0.25
        @test occursin("\"circle\":{\"x\":", ED.panel_json(e)) && occursin("\"handles\"", ED.overlay_json(e, 800.0, 600.0))
    end
    @testset "a picture to draw on: its scale, and the domain fitted to it" begin
        e = editor(Layout(; L=[30.0, 20.0], nel=[30, 20]); step=1)                      # h = 1 m
        ED.use_picture!(e, true); @test e.picture && occursin("Choose a picture", e.status)   # the Domain step's choice
        ED.set_backdrop!(e, "section.png")
        @test occursin("\"backdrop\":null", ED.background_json(e, 800.0, 600.0))           # drawn once its size is known
        ED.backdrop_size!(e, 800, 400); b = e.backdrop
        @test (b.x0, b.z0, b.width, ED.height(b)) == (0.0, 0.0, 30.0, 15.0) && e.L == [30.0, 15.0]   # the domain's width; fitted
        @test occursin("\"backdrop\":{\"url\":\"file://", ED.background_json(e, 800.0, 600.0))
        ED.set_backdrop_field!(e, "width", "24"); @test ED.height(b) == 12.0 && e.L == [24.0, 12.0] && e.nel == [24, 12]
        # a scale bar drawn 5 m long on the picture, as it shows at width 24: its ends 6 m apart; true width 20 m
        ED.scale_bar!(e); ED.key!(e, "escape"); @test isnothing(e.calib)                  # Escape cancels
        ED.scale_bar!(e); ED.press!(e, 2.0, 1.0); ED.press!(e, 8.0, 1.0)                  # its ends: clicks, not edits
        @test length(e.calib) == 2 && !e.resizing && occursin("\"shown\":\"6.0\"", ED.panel_json(e))
        ED.apply_scale!(e, "-5"); ED.apply_scale!(e, "abc"); @test b.width == 24.0 && length(e.calib) == 2   # no valid length
        ED.apply_scale!(e, "5")
        @test b.width ≈ 20.0 && ED.height(b) ≈ 10.0 && e.L ≈ [20.0, 10.0] && isnothing(e.calib)   # scaled, domain fitted
        ED.set_backdrop_field!(e, "width", "20.3"); @test e.L == [20.0, 10.0] && e.nel == [20, 10]   # in whole square elements
        ED.set_backdrop_field!(e, "width", "20")
        ED.set_backdrop_field!(e, "x0", "-2"); @test b.x0 == -2.0 && e.L ≈ [18.0, 10.0]   # moved (cropped): the domain follows
        ED.set_backdrop_field!(e, "opacity", "3"); ED.set_backdrop_field!(e, "width", "abc")
        @test b.opacity == 1.0 && b.width ≈ 20.0                                            # clamped; ignored
        ED.use_picture!(e, false)                                                           # a domain again: hidden, kept
        @test occursin("\"backdrop\":null", ED.background_json(e, 800.0, 600.0)) && !isnothing(e.backdrop)
        ED.use_picture!(e, true); @test occursin("\"backdrop\":{", ED.background_json(e, 800.0, 600.0))
        ED.remove_backdrop!(e); @test isnothing(e.backdrop) && occursin("\"backdrop\":null", ED.panel_json(e))
    end
    @testset "editing: snapping, shared edges, drag, undo" begin
        e = editor(Layout(; L=[L1, L2], nel=[40, 10]))
        ED.new_zone!(e); foreach(p -> click!(e, p...), [(0.1, 0.1), (64.0, 0.05), (64.0, 4.0), (0.05, 4.05), (0.2, 0.2)])
        ED.new_zone!(e); foreach(p -> click!(e, p...), [(0.3, 4.3), (0.0, 12.0), (22.0, 12.0), (30.3, 4.3)]); ED.key!(e, "enter")
        A, B = e.regions[1].vertices, e.regions[2].vertices
        @test B[1] ∈ A && B[end][2] == A[3][2] && B[end] ∈ A                                # vertex snap; the edge snap split A's edge
        corner = copy(B[1])
        ED.move!(e, corner...); ED.press!(e, corner...); ED.move!(e, 0.0, 7*L2/20); ED.release!(e)
        @test e.regions[2].vertices[1] != corner && e.regions[2].vertices[1] ∈ e.regions[1].vertices   # dragged together
        ED.key!(e, "z"; cmd=true);  @test e.regions[2].vertices[1] == corner                # undo
        ED.key!(e, "z"; cmd=true, shift=true); @test e.regions[2].vertices[1] != corner     # redo
        ED.press!(e, e.regions[1].vertices[2]...; right=true)                              # right click: delete a vertex
        @test length(e.regions[1].vertices) == length(A) - 1
        e.ni = 3; ED.new_zone!(e); foreach(p -> click!(e, p...), [(40.1, 10.1), (50.0, 10.0), (45.0, 14.0)]); ED.key!(e, "enter")
        h3 = (L1/120, L2/30)
        @test all(v -> all(isapprox.(v ./ h3, round.(v ./ h3); atol=1e-6)), e.regions[3].vertices)
        ED.select_zone!(e, 3); ED.swap_zone!(e, -1); @test e.selected == 2
        ED.delete_zone!(e); @test length(e.regions) == 2
    end
    @testset "cached points and checks, the cursor readout" begin
        e = editor(Layout(; L=[L1, L2], nel=[40, 10]))
        ED.new_zone!(e); foreach(p -> click!(e, p...), [(0.0, 0.0), (64.0, 0.0), (64.0, 4.0), (0.0, 4.0)]); ED.key!(e, "enter")
        p = ED.preview_points(e)
        @test ED.preview_points(e) === p && p == ED.drawn_points(e.L, e.nel, e.ni, e.regions)  # cached, and right
        c = ED.checks(e); @test ED.checks(e) === c
        corner = copy(e.regions[1].vertices[3])
        ED.move!(e, corner...); ED.press!(e, corner...); ED.move!(e, 64.0, 8.0)
        @test ED.preview_points(e) === p                                                    # dragging: kept until release
        ED.release!(e)
        q = ED.preview_points(e)
        @test q !== p && q == ED.drawn_points(e.L, e.nel, e.ni, e.regions) && length(q[1]) > length(p[1])
        @test ED.checks(e) !== c                                                            # the zone changed
        c = ED.checks(e); ED.set_prop!(e, "E", "50"); @test ED.checks(e) !== c               # so did its constants
        status = e.status; ED.move!(e, 10.0, 2.0)
        @test e.status == status && startswith(e.readout, "x = ")                          # coordinates on the canvas
        @test occursin("\"readout\":\"x = ", ED.overlay_json(e, 800.0, 600.0))
        ED.leave!(e); @test e.readout == ""
    end
    @testset "domain, sides, zone properties, options, run, files" begin
        e = editor(Layout(; L=[10.0, 5.0], nel=[20, 10]); step=1)
        ED.press!(e, 10.0, 5.0); ED.move!(e, 13.3, 6.7); ED.release!(e)
        @test e.L == [13.0, 7.0] && e.nel == [26, 14]                                       # snapped to 1 m, h = 0.5
        ED.set_domain_field!(e, "h", "1"); @test e.nel == [13, 7]                          # the typed fields
        ED.set_domain_field!(e, "Lx", "abc"); ED.set_domain_field!(e, "Lz", "-2"); @test e.L == [13.0, 7.0]   # ignored
        @test e.sides == Dict(s => "free" for s ∈ ED.SIDES)                                # the catalog's default
        ED.set_bc!(e, "bottom", "fixed"); ED.set_bc!(e, "top", "glued")                   # not a kind: ignored
        @test e.sides["bottom"] == "fixed" && e.sides["top"] == "free"
        @test occursin("\"color\":\"#b22222\"", ED.background_json(e, 800.0, 600.0))         # drawn in its kind's colour
        ED.set_domain_field!(e, "width", "4"); @test e.width == 4.0 && e.nely == 4
        ED.set_step!(e, 2); ED.new_zone!(e); foreach(p -> click!(e, p...), [(0, 0), (13, 0), (13, 3), (0, 3)]); ED.key!(e, "enter")
        ED.set_prop!(e, "E", "50"); ED.set_prop!(e, "phi", "30")
        @test e.regions[1].props == Dict("E" => 5e7, "phi" => 30π/180)
        @test occursin("φ [°]", ED.panel_json(e)) && occursin("default 1.0", ED.panel_json(e))   # E's default, in MPa
        ED.set_option!(e, "model.kind", 2); @test e.options["model"]["kind"] == "cohesive"
        @test !occursin("φ [°]", ED.panel_json(e))                                          # hidden: show_if
        ED.type_option!(e, "model.damping", "0.25"); @test e.options["model"]["damping"] == 0.25
        ED.type_option!(e, "model.damping", "abc");  @test e.options["model"]["damping"] == 0.25   # invalid: ignored
        ED.type_option!(e, "grid.lengths", "1, 2"); @test e.options["grid"]["lengths"] == [1.0, 2.0]
        ED.type_option!(e, "grid.n", "12.5"); @test !haskey(e.options["grid"], "n")         # not an integer
        ED.tick_option!(e, "grid.lengths", false); @test !haskey(e.options, "grid")
        ED.tick_value!(e, "plot.what", 2, true); @test e.options["plot"]["what"] == ["p", "q"]
        e.section = "plot"; @test occursin("\"deviator\"", ED.panel_json(e))                  # shown by its name
        @test occursin("\"tabs\":[\"1 Domain\",\"2 Zones\",\"3 Options\",\"4 Run\"]", ED.panel_json(e))
        ED.set_run!(e, "dt", "0.5"); ED.set_run!(e, "dt", "-1"); @test e.run["dt"] == 0.5    # below its min: ignored
        @test occursin("dt [s]", ED.panel_json(e)) && !occursin("\"steps\"", ED.panel_json(e))
        ED.pick_run!(e, "mode", 2); ED.set_run!(e, "steps", "20")
        @test e.run == Dict("mode" => "slow", "dt" => 0.5, "steps" => 20)
        @test occursin("\"steps\"", ED.panel_json(e)) && !occursin("dt [s]", ED.panel_json(e))   # shown by mode
        push!(e.regions, ED.circle_region("far", [50.0, 50.0], 1.0, Dict{String,Float64}()))   # outside, no point: warnings
        @test length(ED.checks(e).warnings) == 2 && occursin("points, 13 × 7 cells", only(ED.checks(e).info))
        @test !ED.ready!(e) && occursin("again", e.status) && ED.ready!(e)                   # Create… twice
        folder = joinpath(mktempdir(), "layers")
        @test ED.create!(e, folder * "/") && e.finished && isfile(joinpath(folder, "layers_layout.toml"))   # made, the layout in it
        r = e.result
        @test r isa Layout && r.folder == folder && r.width == 4.0 && r.run["steps"] == 20 && r.options["model"]["kind"] == "cohesive"
        @test r.sides["bottom"] == "fixed" && r.zones[1].props == Dict(:E => 5e7, :phi => 30π/180)
        e2 = editor(Layout(; L=[1, 1], nel=[2, 2])); ED.set_backdrop!(e2, "section.png")
        ED.load!(e2, joinpath(folder, "layers_layout.toml"))                                # Start from a file
        @test length(e2.regions) == 2 && e2.width == 4.0 && e2.run["steps"] == 20 && e2.folder == folder
        @test e2.backdrop.file == "section.png" && e2.picture                              # the picture stays
        ED.load!(e2, "nothere.toml"); @test startswith(e2.status, "Not loaded")
        @test_throws ArgumentError editor(Layout(; L=[1, 1], nel=[2, 2], zones=[Zone("r", Region(x -> x[1] < 0.5))]))
        @test ED.qml_index(nothing) == -1 && ED.julia_index(ED.qml_index(3)) == 3              # indices crossing to QML
        @test ED.localpath("file:///a/%C3%89tudes%20x%23%25") == "/a/Études x#%" && ED.localpath("/a b") == "/a b"   # URLs from Qt
        @test ED.localpath(ED.fileurl("/tmp/a b#c%d")) == "/tmp/a b#c%d" && ED.localpath("file:///C:/a%20b") == "C:/a b"
        rs = [ED.DrawnRegion("a", [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0]], Dict{String,Float64}()),
              ED.DrawnRegion("b", [[1.0, 0.0], [2.0, 0.0], [2.0, 1.0], [1.0, 1.0]], Dict{String,Float64}())]
        @test !ED.delete_vertex!(rs, [1.0, 0.0]) && length.(getfield.(rs, :vertices)) == [3, 4]   # shared with a triangle: kept
        @test ED.delete_vertex!(rs, [2.0, 0.0]) && length.(getfield.(rs, :vertices)) == [3, 3]
        @test occursin("\"tab\":$(e.step - 1)", ED.panel_json(e))
        j = ED.json((; a=[1, 2.5], b="x\"y", c=nothing, d=true)); @test j == "{\"a\":[1.0,2.5],\"b\":\"x\\\"y\",\"c\":null,\"d\":true}"
    end
    @testset "an empty catalog: no properties, sides or options" begin
        e = ED.Editor(Layout(; L=[4, 2], nel=[4, 2], zones=[Zone("a", Block([0, 0], [4, 2]); E=1.0)]))
        @test isempty(e.regions[1].props) && e.regions[1].extra == Dict(:E => 1.0)          # carried through
        j = ED.panel_json(e)
        @test occursin("\"tabs\":[\"1 Domain\",\"2 Zones\",\"3 Run\"]", j) && occursin("\"sections\":[]", j)
        @test occursin("\"kinds\":[]", j) && isempty(e.sides) && ED.current_layout(e).zones[1].props == Dict(:E => 1.0)
        @test ED.checks(e) == (; errors=String[], warnings=String[], info=["32 points, 4 × 2 cells"])
    end
    @testset "without the window: how to get it" begin
        @test_throws ErrorException ED.window(nothing)
        for installed ∈ (false, true)
            m = ED.drawing_window_help(; installed, qt="6.8.2")
            @test occursin("Qt6Base_jll@6.8.2", m) && occursin("_qt_version_tag", m)       # the pin, the symptom
            @test occursin("installed but not loaded", m) == installed
            m = ED.drawing_window_help(; installed, qt=nothing)                            # no Qt loaded yet: no pin
            @test !occursin("@", m) && occursin("installed but not loaded", m) == installed
        end
    end

    if isnothing(Base.find_package("QML"))
        @info "QML is not installed: the window itself is not tested"
    else
        ENV["QT_QPA_PLATFORM"] = get(ENV, "QT_QPA_PLATFORM", "offscreen"); ENV["QT_QUICK_BACKEND"] = "software"
        @eval using QML
        @testset "the window, offscreen" begin
            @test !isnothing(Base.get_extension(EasyDraw, :EasyDrawQMLExt))
            d = mktempdir()
            l = Layout(; L=[20.0, 10.0], nel=[20, 10], sides=Dict("bottom" => "fixed"),
                         zones=[Zone("soil", Block([0, 0], [20, 6])), Zone("rock", Block([0, 0], [20, 2]); E=5e7)])
            @test isnothing(draw(l; catalog=CAT, shots=(d, [1, 2, 3, 4])))                      # closes itself; no Create…: nothing
            @test all(k -> isfile(joinpath(d, "step$k.png")), 1:4)
            d2 = mktempdir()                                                                   # a second window, same session,
            @test isnothing(draw(l; shots=(d2, [2, 4]))) && isfile(joinpath(d2, "step2.png"))   # an empty catalog
            e = ED.Editor(l; step=1); pic = write_bmp(joinpath(d2, "a picture.bmp"), 550, 600)  # a space in its name
            ED.set_backdrop!(e, pic); ED.window(e; shots=(d2, [1]))                            # Qt measured it, the domain followed:
            @test e.backdrop.npx == (550, 600) && e.L == [20.0, 22.0]                          # 20 × 21.8 m, whole elements
        end
    end
end
