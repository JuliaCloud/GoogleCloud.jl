# Collections


## Key-value Store

This API is a custom wrapper around the object storage API; it is not a GCP API.



using GoogleCloud
session = GoogleSession(expanduser("~/albert.json"), ["devstorage.full_control"])

function serialize_str(x)
    io = IOBuffer()
    serialize(io, x)
    takebuf_array(io)
end


# bucket name is theta_test
# use_remote::Bool, dflt = true => reads/writes from/to remote on every get/set/delete
#    If false, you can still fetch/commit manually
# use_cache::Bool,  dflt = true => store results locally on every get/set/delete
# reset::Bool, true means empty the bucket if it exists (if bucket doesn't exist, KeyStore constructor creates it)
d1 = KeyStore{Int, Int}(
    "theta_test"; session=session,
    val_reader=(x) -> deserialize(IOBuffer(x)),
    val_writer=serialize_str,
    reset=true
)


keys(d1)       # Return array of keys
values(d1)     # Return array of values
collect(d1)    # Return array of Pair(key, value)

d1[1] = 11     # Write key-value pair both locally and remotely (determined by use_remote = true)
d1[2] = 22

# verify local cache
d1.cache
clearcache(d1)
d1.cache
collect(d1)    # pulls from remote and populates local
d1.cache


# Verify the contents of the remote bucket
# A second view of the same bucket, with permission to read/write from/to remote only
d2 = KeyStore{Int, Int}(
    "theta_test"; session=session,
    val_reader=(x) -> deserialize(IOBuffer(x)),
    val_writer=serialize_str,
    use_cache = false
)
collect(d2)
d2.cache    # empty because use_cache is false
fetch(d2)
d2.cache


# Work locally only, then manually commit changes to remote...good for batching writes
d3 = KeyStore{Int, Int}(
    "theta_test"; session=session,
    val_reader=(x) -> deserialize(IOBuffer(x)),
    val_writer=serialize_str,
    use_remote = false
)
d3.cache       # empty
collect(d3)    # local because use-remote is false

fetch(d3)
collect(d3)
d3[3] = 33
d3.pending
d2[3]    # error because key 3 hasn't been committed from d3 to remote
commit(d3)
d2[3]    # returns 33 from remote
d1.cache    # excludes key 3 because d1 hasn't pulled it yet
d1[3]    # pulls key 3 from remote and stores it in cache


delete!(d1, 1)
delete!(d1, 2)
delete!(d1, 3)
collect(d1)

