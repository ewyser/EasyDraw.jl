# EasyDraw's tests, run on their own (`] test EasyDraw` in an environment that has it) and from ElastoPlasm's suite
# (test/testset/test_easydraw.jl)
using Test, EasyDraw

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
end
