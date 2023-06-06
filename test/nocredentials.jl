using Test

using GoogleCloud
using JSON

creds = NoCredentials()

session = GoogleSession(creds, ["devstorage.full_control"])
bucketName = "atari-replay-datasets"
prefix="dqn/Pong/1/replay_logs/\$store\$_action"

fileList = GoogleCloud.storage(:Object, :list, bucketName; prefix, session)

parities = map(fileList) do item
    reduce(⊻, GoogleCloud.storage(:Object, :get, bucketName, item[:name]; session))
end

EXPECTED_PARITY = 0xf1

@testset "NoCredentials" begin
    @test reduce(⊻, fetch.(parities)) == EXPECTED_PARITY
end
