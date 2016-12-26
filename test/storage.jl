using GoogleCloud
using GoogleCloud.Utils.Storage
using Base.Test

bucketName = "a3426sdfere"
path  = "gs://$(bucketName)/test/a.blk"
a = rand(128,128,128)

# test without compression
info("test array IO without compression...")
create_bucket( bucketName )
gssave(path, a)
b = gsread( path )
delete_bucket(bucketName)
@test all(b .== a)


# info("test array IO with blosc compression ...")
# create_bucket( bucketName )
# gssave(path, a; compression = :blosc)
# b = gsread( path; compression = :blosc)
# delete_bucket(bucketName)
# @test all(b .== a)
