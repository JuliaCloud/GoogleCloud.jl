using Test 
using GoogleCloud
import GoogleCloud.api 

@testset "test api functions" begin 
    @test "/this/is/it" == GoogleCloud.api.path_replace(
                                "/{foo}/{bar}/{baz}", 
                                ["this", "is", "it"])

    @test api.path_tokens("/{foo}/{bar}/x/{baz}") == ["{foo}", "{bar}", "{baz}"]
end 
