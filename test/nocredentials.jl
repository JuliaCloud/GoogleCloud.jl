using Test

using GoogleCloud
using JSON

creds = NoCredentials()

session = GoogleSession(creds, ["devstorage.full_control"])

## Test download of JSON data from Pong dataset
bucketName = "atari-replay-datasets"
prefix="dqn/Pong/1/replay_logs/\$store\$_action"

fileList = GoogleCloud.storage(:Object, :list, bucketName; prefix, session)

parities = map(fileList) do item
    reduce(⊻, GoogleCloud.storage(:Object, :get, bucketName, item[:name]; session))
end

EXPECTED_PARITY = 0xf1

## Test download of binary data from sentinel dataset
sentinelbucket = "gcp-public-data-sentinel-2"
sentinelpath = "L2/tiles/32/T/NS/S2A_MSIL2A_20210506T102021_N0300_R065_T32TNS_20210506T132458.SAFE/GRANULE/L2A_T32TNS_A030664_20210506T102022/IMG_DATA/R20m/T32TNS_20210506T102021_B07_20m.jp2"
sentinelimage = GoogleCloud.storage(:Object, :get, sentinelbucket, sentinelpath; session)
EXPECTED_PARITY_SENTINEL = 0x6e

@testset "storage access and NoCredentials" begin
    @test reduce(⊻, fetch.(parities)) == EXPECTED_PARITY
    @test reduce(⊻, sentinelimage) == EXPECTED_PARITY_SENTINEL
end
