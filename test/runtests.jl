using Remarkable
using Test

@testset "Remarkable.jl" begin
   client = RemarkableClient(path_to_token = @__DIR__)
   @test Remarkable.token(client) != String(read(joinpath(@__DIR__, ".token")))

end