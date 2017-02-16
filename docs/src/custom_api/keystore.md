# Key-Value Store

The `KeyStore` API is a custom key-value API built on the object storage API. That is, it is not an API offered by the Google Cloud Platform. It is intended to be used to store key-value pairs. Below is a brief tutorial that walks through some typical usage of the `KeyStore` API.


First, load the package.

```julia
using GoogleCloud
session = GoogleSession(expanduser("~/credentials.json"), ["devstorage.full_control"])
```

Define a function for serializing data to Vector{UInt8} before writing to the key-value store. Also define a corresponding deserializer, which is called when reading from the store. 

```julia
function serialize_to_uint8_vector(x)
    io = IOBuffer()
    serialize(io, x)
    takebuf_array(io)
end

deserialize_from_vector(x) = deserialize(IOBuffer(x))
```

Initialize the key-value store. In this case our store uses the default options, which synchronizes the data in the remote store with the data in the local store.

```julia
kv_sync = KeyStore{Int, Int}(
    "kvtest",                                  # Key-value store name. Created if it doesn't already exist.
    session;
    location    = "US",
    empty       = false,                        # Defaults to false. Empty the bucket if it exists.
    gzip        = true,
    key_format  = K <: String ? :string : :json # the formating function of key
    val_format  = V <: String ? :string : :json # the formating function of value
)
```

Run some basic get/set methods, verifying their effects along the way.

```julia
# Get the data from the key-value store. Currently there is no data.
keys(kv_sync)       # Returns array of keys
values(kv_sync)     # Returns array of values
collect(kv_sync)    # Returns array of Pair(key, value)

# Write key-value pairs both locally (determined by use_cache = true) and remotely (determined by use_remote = true)
kv_sync[1] = 11
kv_sync[2] = 22

# Verify local store
kv_sync.cache

# Verify remote store
clearcache!(kv_sync)    # Clear local store
kv_sync.cache           # Verify local store is empty again
collect(kv_sync)        # Pull data from remote store and populate local store
kv_sync.cache           # Local store now contains our data
```

If you are writing frequently then the latency of persisting each write to the remote store may be unacceptably slow. One solution is to do all your writes locally, then persist them remotely with one `commit`, as follows:

```julia
kv_local = KeyStore{Int, Int}(
    "kvtest";                                  # The store name is the same as before.
    session    = session,                      # As before
    val_writer = serialize_to_uint8_vector,    # As before
    val_reader = deserialize_from_vector,      # As before
    use_remote = false                         # Work locally only, then manually sync with the remote store.
)

kv_local.cache        # Empty because kv_local is not synchronized with the remote store (because use_remote is false)
collect(kv_local)     # Empty because use_remote is false, so collect(kv_local) only looks at kv_local.cache
fetch!(kv_local)      # Manually fetch the data in the remote store
collect(kv_local)     # Local store is now populated
kv_local[3] = 33      # Writes to local store only
kv_sync[3]            # Error because key 3 hasn't been committed from kv_local to remote store
kv_local.pending      # List of changes made locally that have not been committed to the remote store
commit!(kv_local)     # Commit the local changes to the remote store
kv_local.pending      # The list of pending changes is now empty
kv_sync[3]            # Now returns 33 from the remote store
```

Finally we clean up.

```julia
delete!(kv_sync)      # Error: Can't delete a non-empty remote store
reset!(kv_sync)       # Remove all data from remote store. Alternatively, delete!(kv_sync, 1), delete!(kv_sync, 2), etc.
delete!(kv_sync)      # Detaches local store from remote store and deletes remote store
```

Additional methods include:

```julia
clearpending!(kvstore)    # Empty the list of local changes that haven't been committed to the remote store
sync!(kvstore)            # Commit local changes to remote store, then fetch data from remote store
```
