using GoogleCloud
using Mocking
using Test
using HTTP
using JSON

Mocking.activate()

const FIXTURES_DIR = joinpath(@__DIR__, "fixtures")

model_params = (
  temperature=0.7,
  maxOutputTokens=200,
  topP=0.7,
  topK=40
)

params = Dict(
  :instances => [
    Dict(:prompt => "Tell about yourself")
  ],
  :parameters => model_params
)

http_response_mock = HTTP.Response(
  200,
  Dict("Content-Type" => "application/json"),
  read(joinpath(FIXTURES_DIR, "text_service_response.json"))
)

authorize_response_mock = Dict(:access_token => "test-token", :token_type => "Bearer")

@testset "Testing text_service" begin
  http_patch = @patch HTTP.request(args...; kwargs...) = http_response_mock
  authorize_patch = @patch GoogleCloud.api.authorize(_session) = authorize_response_mock

  default_region = "us-central1"
  project_id = "test-project-id"

  apply([http_patch, authorize_patch]) do
    response = text_service(
      :PALM,
      :predict,
      default_region,
      project_id,
      default_region,
      GoogleCloud.BISON_TEXT_MODEL_NAME,
      data=params
    )

    @test response isa AbstractDict
    @test haskey(response, :predictions)
    @test haskey(response, :metadata)
  end
end
