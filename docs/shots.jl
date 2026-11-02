# The window's screenshots in the documentation (docs/src/assets/step1.png … step4.png), drawn offscreen. From the
# repository's root:
#
#     QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software julia --project=docs docs/shots.jl
#
# Run it again after a change to the window, and commit the pictures.
using EasyDraw

# a slope over two layers, with a lens of sand in the clay
layout = Layout(; L=[100.0, 50.0], nel=[50, 25],
                  zones=[Zone("bedrock", Block([0, 0], [100, 15]); rho=2700.0, eta=1.0e22),
                         Zone("clay", Polygon([[0, 15], [100, 15], [100, 24], [0, 30]]); rho=1900.0, eta=1.0e19),
                         Zone("sand", Polygon([[0, 30], [100, 24], [100, 28], [70, 28], [40, 40], [0, 40]]); rho=2000.0),
                         Zone("lens", Ball([62, 21], 3.5); rho=2100.0, eta=1.0e18)],
                  sides=Dict("left" => "free slip", "right" => "free slip", "bottom" => "no slip", "top" => "free surface"))

catalog = Catalog(Dict(
    "boundary" => Dict("kinds" => ["free slip", "no slip", "free surface"], "colors" => ["#4682b4", "#b22222", "#2e8b57"],
                       "default" => "free slip"),
    "zone"     => [Dict("key" => "rho", "label" => "ρ [kg/m³]", "default" => 2000.0),
                   Dict("key" => "eta", "label" => "η [Pa s]", "default" => 1.0e20)],
    "options"  => [Dict("key" => "solver.method", "kind" => "menu", "label" => "method", "values" => ["direct", "iterative"],
                        "default" => "direct"),
                   Dict("key" => "solver.tol", "label" => "tolerance", "values" => [1.0e-6, 1.0e-8], "default" => 1.0e-8),
                   Dict("key" => "output.every", "kind" => "integer", "label" => "write every n steps", "default" => 10)],
    "run"      => [Dict("key" => "nt", "kind" => "integer", "label" => "time steps", "default" => 1000, "min" => 1),
                   Dict("key" => "dt", "label" => "time step [s]", "values" => [1.0e9, 1.0e10], "default" => 1.0e10)]))

assets = joinpath(@__DIR__, "src", "assets")
mkpath(assets)
draw(layout; catalog, shots=(assets, [1, 2, 3, 4]))
