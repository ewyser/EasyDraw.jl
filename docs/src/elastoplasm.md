# With ElastoPlasm.jl

[ElastoPlasm.jl](https://github.com/ewyser/ElastoPlasm.jl), a material point method solver, uses EasyDraw for its
shapes, its zones and its drawing window. The two share the points, so a model moves between them without loss:

```julia
using ElastoPlasm
case = draw_case()                           # the window, with ElastoPlasm's catalog; returns a case
case = slump_case([64.16, 16.04], [40, 10])
save_layout("slump_layout.toml", case)       # a layout file, for EasyDraw alone (values in SI)
write_geo("slump.geo", case)                 # a case works wherever EasyDraw takes a layout:
p = points(case)                             #   its points are the simulation's material points, to the bit
case = load_case("drawn_layout.toml")        # and back: a layout drawn with ElastoPlasm's catalog is a case
```

A layout drawn with EasyDraw alone becomes a case when it was drawn with ElastoPlasm's catalog: write it with
`write_catalog("elastoplasm_catalog.toml", get_catalog())`, then load that file with **Load catalog…**.

Opened in EasyDraw directly, an ElastoPlasm case file (`*_case.toml`) loses its material, boundary conditions and
solver options, and its friction angles stay in degrees: `load_layout` warns. Convert it first with
`save_layout(file, load_case(case_file))`.
