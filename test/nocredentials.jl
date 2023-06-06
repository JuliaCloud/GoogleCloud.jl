using Test

using GoogleCloud
using JSON

creds = NoCredentials()

session = GoogleSession(creds, ["devstorage.full_control"])
bucketName = "atari-replay-datasets"
@show mydata = GoogleCloud.storage(:Object, :list, bucketName; prefix="dqn/Pong/1/replay_logs/\$store\$_action", session=session)
fileList = JSON.parse(IOBuffer(mydata))

parities = map(fileList["items"]) do item
    reduce(⊻, GoogleCloud.storage(:Object, :get, bucketName, item["name"], session=session))
end

@testset "NoCredentials" begin
    @test reduce(⊻, fetch.(parities)) == 0xf1
end
