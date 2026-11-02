using Documenter, EasyDraw

DocMeta.setdocmeta!(EasyDraw, :DocTestSetup, :(using EasyDraw); recursive=true)

# the home page is the README without its badges, so that the package is described in one place; its pictures are
# under docs/src/assets, which the pages see as assets/
readme = read(joinpath(@__DIR__, "..", "README.md"), String)
lines  = filter(line -> !startswith(line, "[!["), split(readme, '\n'))
home   = replace(join(lines, '\n'), "docs/src/assets/" => "assets/")
write(joinpath(@__DIR__, "src", "index.md"), "```@meta\nCurrentModule = EasyDraw\n```\n\n" * home)

makedocs(;
    modules   = [EasyDraw],
    authors   = "ewyser",
    sitename  = "EasyDraw.jl",
    format    = Documenter.HTML(; canonical="https://ewyser.github.io/EasyDraw.jl/", edit_link="main"),
    pages     = ["Home"                             => "index.md",
                 "Drawing in the window"            => "window.md",
                 "Layouts in code"                  => "code.md",
                 "Finite differences and particles" => "grids.md",
                 "Finite elements (Gmsh)"           => "meshes.md",
                 "Catalogs"                         => "catalog.md",
                 "With ElastoPlasm.jl"              => "elastoplasm.md",
                 "Reference"                        => "api.md"],
    checkdocs = :exports,   # an exported name without a docstring in the pages fails the build
)

# published from CI only (GitHub Pages, the gh-pages branch)
if get(ENV, "GITHUB_ACTIONS", "false") == "true"
    deploydocs(; repo="github.com/ewyser/EasyDraw.jl.git", devbranch="main", push_preview=false)
end
