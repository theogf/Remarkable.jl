using Remarkable
using Test

@testset "Remarkable.jl" begin
   client = RemarkableClient(path_to_token = @__DIR__)
   @test Remarkable.token(client) != String(read(joinpath(@__DIR__, ".token")))
   list = list_items(client)
   @test list isa Remarkable.Collection
   @test list[1] isa Remarkable.Collection
   @test list[2] isa Remarkable.Document
   print_tree(list)
end