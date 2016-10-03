"""
Google Cloud Storage API
"""
module storage_api

export storage, KeyStore, Mode

using Base.Dates

using ..api
using ...root
using ...session

"""
Google Cloud Storage API root.
"""
storage = APIRoot(
    "$API_ROOT/storage/v1",
    Dict(
        "devstorage.full_control" => "Read/write and ACL management access to Google Cloud Storage",
        "devstorage.read_write" => "Read/write access to Google Cloud Storage",
        "devstorage.read_only" => "Read-only access to Google Cloud Storage",
    );
    Bucket=APIResource("b";
        delete=APIMethod(:DELETE, "{bucket}", "Permanently deletes an empty bucket."),
        get=APIMethod(:GET, "{bucket}", "Returns metadata for the specified bucket."),
        insert=APIMethod(:POST, "", "Creates a new bucket."),
        list=APIMethod(:GET, "", "Retrieves a list of buckets for a given project."; transform=(x, t) -> map(t, get(x, :items, []))),
        patch=APIMethod(:PATCH, "{bucket}", "Updates a bucket. This method supports patch semantics."),
        update=APIMethod(:PUT, "{bucket}", "Updates a bucket."),
    ),
    BucketAccessControls=APIResource("b/{bucket}/acl";
        delete=APIMethod(:DELETE, "{entity}", "Permanently deletes the ACL entry for the specified entity on the specified bucket."),
        get=APIMethod(:GET, "{entity}", "Returns the ACL entry for the specified entity on the specified bucket."),
        insert=APIMethod(:POST, "", "Creates a new ACL entry on the specified bucket."),
        list=APIMethod(:GET, "", "Retrieves ACL entries on a specified bucket."; transform=(x, t) -> map(t, get(x, :items, []))),
        patch=APIMethod(:PATCH, "{entity}", "Updates an ACL entry on the specified bucket. This method supports patch semantics."),
        update=APIMethod(:PUT, "{entity}", "Updates an ACL entry on the specified bucket."),
    ),
    Object=APIResource("b/{bucket}/o";
        compose=APIMethod(:POST, "{destinationObject}/compose", "Concatenates a list of existing objects into a new object in the same bucket."),
        copy=APIMethod(:POST, "{sourceObject}/copyTo/b/{destinationBucket}/o/{destinationObject}", "Copies a source object to a destination object. Optionally overrides metadata."),
        delete=APIMethod(:DELETE, "{object}", "Deletes an object and its metadata. Deletions are permanent if versioning is not enabled for the bucket, or if the generation parameter is used."),
        get=APIMethod(:GET, "{object}", "Retrieves an object or its metadata.",
            Dict(:alt => "media")
        ),
        insert=APIMethod(:POST, "$API_ROOT/upload/storage/v1/b/{bucket}/o", "Stores a new object and metadata.",
            Dict(:uploadType => "media")
        ),
        list=APIMethod(:GET, "", "Retrieves a list of objects matching the criteria."; transform=(x, t) -> map(t, get(x, :items, []))),
        patch=APIMethod(:PATCH, "{object}", "Updates a data blob's associated metadata. This method supports patch semantics."),
        rewrite=APIMethod(:POST, "{sourceObject}/rewriteTo/b/{destinationBucket}/o/{destinationObject}", "Rewrites a source object to a destination object. Optionally overrides metadata."),
        update=APIMethod(:PUT, "{object}", "Updates an object's metadata."),
        watchAll=APIMethod(:POST, "watch", "Watch for changes on all objects in a bucket."),
    ),
    ObjectAccessControls=APIResource("b/{bucket}/o/{object}/acl";
        delete=APIMethod(:DELETE, "{entity}", "Permanently deletes the ACL entry for the specified entity on the specified object."),
        get=APIMethod(:GET, "{entity}", "Returns the ACL entry for the specified entity on the specified object."),
        insert=APIMethod(:POST, "", "Creates a new ACL entry on the specified object."),
        list=APIMethod(:GET, "", "Retrieves ACL entries on the specified object."; transform=(x, t) -> map(t, get(x, :items, []))),
        patch=APIMethod(:PATCH, "{entity}", "Updates an ACL entry on the specified object. This method supports patch semantics."),
        update=APIMethod(:PUT, "{entity}", "Updates an ACL entry on the specified object."),
    ),
    DefaultObjectAccessControls=APIResource("b/{bucket}/defaultObjectAcl";
        delete=APIMethod(:DELETE, "entity", "Permanently deletes the default object ACL entry for the specified entity on the specified bucket."),
        get=APIMethod(:GET, "entity", "Returns the default object ACL entry for the specified entity on the specified bucket."),
        insert=APIMethod(:POST, "", "Creates a new default object ACL entry on the specified bucket."),
        list=APIMethod(:GET, "", "Retrieves default object ACL entries on the specified bucket."; transform=(x, t) -> map(t, get(x, :items, []))),
        patch=APIMethod(:PATCH, "entity", "Updates a default object ACL entry on the specified bucket. This method supports patch semantics."),
        update=APIMethod(:PUT, "entity", "Updates a default object ACL entry on the specified bucket."),
    ),
    Channels=APIResource("channels";
        stop=APIMethod(:POST, "stop", "Stop receiving object change notifications through this channel."),
    ),
)


# higher-level access to API
import Base:
    print, show, display, getindex, setindex!, delete!, pop!, get, haskey, in,
    keys, values, start, next, done, iteratorsize, SizeUnknown

module Mode
    LOCAL, REMOTE = 1, 2
end

"""
High-level container wrapping a Google Storage bucket
"""
type KeyStore{K, V} <: Associative{K, V}
    bucket_name::String
    session::GoogleSession
    key_reader::Function
    key_writer::Function
    val_reader::Function
    val_writer::Function
    mode::Int64
    grace::Second
    cache::Dict{K, Tuple{DateTime, V}}
    function KeyStore(bucket_name::String;
        session::GoogleSession=get_session(storage), mode::Int64=Mode.REMOTE,
        grace::Second=Second(5),
        key_reader::Function=(x) -> parse(K, x), key_writer::Function=string,
        val_reader::Function=(x) -> parse(V, x), val_writer::Function=string
    )
        if mode & (Mode.LOCAL | Mode.REMOTE) == 0
            error("Storage mode must be local and/or remote.")
        end
        if mode & Mode.REMOTE != 0
            bucket = storage(:Bucket, :get, bucket_name; session=session)
            if haskey(bucket, :error)
                metadata = storage(:Bucket, :insert; session=session, data=Dict(:name => bucket_name))
                if haskey(metadata, :error)
                    error("Unable to create bucket: $(bucket[:error][:message])")
                end
            end
        end
        new(bucket_name, session,
            key_reader, key_writer, val_reader, val_writer,
            mode, grace, Dict{K, Tuple{DateTime, V}}()
        )
    end
end
print(io::IO, store::KeyStore) = print(io, "KeyStore($(store.bucket_name))")
show(io::IO, store::KeyStore) = print(io, store)
display(store::KeyStore) = print(store)

function getindex{K, V}(store::KeyStore{K, V}, key::K)
    name = store.key_writer(key)
    if store.mode & Mode.LOCAL != 0
        if haskey(store.cache, key)
            timestamp, val = store.cache[key]
            if store.mode & Mode.REMOTE == 0
                return val
            end
            metadata = storage(:Object, :get, store.bucket_name, name; session=store.session, alt="")
            if !haskey(metadata, :error)
                if timestamp + store.grace > DateTime(metadata[:updated], "yyyy-mm-ddTHH:MM:SS.sssZ")
                    return val
                end
            end
        end
    end
    if store.mode & Mode.REMOTE != 0
        data = storage(:Object, :get, store.bucket_name, name; session=store.session)
        if isa(data, Dict{Symbol, Any}) && haskey(data, :error)
            throw(KeyError(key))
        end
        val = store.val_reader(data)
        if !isa(val, V)
            throw(TypeError(:getindex, "$(store.bucket_name):$name", V, val))
        end
        if store.mode & Mode.LOCAL != 0
            store.cache[key] = (now(), val)
        end
        return val
    end
    throw(KeyError(key))
end

function setindex!{K, V}(store::KeyStore{K, V}, val::V, key::K)
    if store.mode & Mode.LOCAL != 0
        store.cache[key] = (now(), val)
    end
    if store.mode & Mode.REMOTE != 0
        name = store.key_writer(key)
        data = store.val_writer(val)
        storage(:Object, :insert, store.bucket_name; session=store.session,
            name=name, data=data, content_type="text/plain"
        )
    end
    val
end

function delete!{K, V}(store::KeyStore{K, V}, key::K)
    if store.mode & Mode.LOCAL != 0
        delete!(store.cache, key)
    end
    if store.mode & Mode.REMOTE != 0
        name = store.key_writer(key)
        metadata = storage(:Object, :delete, store.bucket_name, name; session=store.session)
    end
    nothing
end

function pop!{K, V}(store::KeyStore{K, V}, key::K, default=nothing)
    val = default == nothing ? store[key] : get(store, key, default)
    delete!(store, key)
    val
end

function get{K, V}(store::KeyStore{K, V}, key::K, default)
    try
        return store[key]
    catch
        return default
    end
end

function haskey{K, V}(store::KeyStore{K, V}, key::K)
    if store.mode & Mode.LOCAL != 0
        if haskey(store.cache, key)
            return true
        end
    end
    if store.mode & Mode.REMOTE != 0
        name = store.key_writer(key)
        metadata = storage(:Object, :get, store.bucket_name, name; session=store.session, alt="")
        if !haskey(metadata, :error)
            return true
        end
    end
    false
end

function in{K, V}(store::KeyStore{K, V}, key::K)
    haskey(store, key)
end

function keys{K, V}(store::KeyStore{K, V})
    result = K[]
    if store.mode & Mode.LOCAL != 0
        append!(result, keys(store.cache))
    end
    if store.mode & Mode.REMOTE != 0
        for metadata in storage(:Object, :list, store.bucket_name; session=store.session)
            name = metadata[:name]
            key = store.key_reader(name)
            if !isa(key, K)
                throw(TypeError(:keys, "$(store.bucket_name):$name", K, key))
            end
            push!(result, key)
        end
    end
    unique(result)
end

# WARNING: potential for race condition. don't zip with keys.
function values{K, V}(store::KeyStore{K, V})
    V[x for x in (get(store, key, nothing) for key in keys(store)) if x != nothing]
end

function fast_forward{K, V}(store::KeyStore{K, V}, key_list)
    while !isempty(key_list)
        key = pop!(key_list)
        val = get(store, key, nothing)
        if val != nothing
            return Pair{K, V}(key, val)
        end
    end
    nothing
end

function start{K, V}(store::KeyStore{K, V})
    key_list = keys(store)
    return (fast_forward(store, key_list), key_list)
end

function next{K, V}(store::KeyStore{K, V}, state)
    pair, key_list = state
    return pair, (fast_forward(store, key_list), key_list)
end

function done{K, V}(store::KeyStore{K, V}, state)
    pair, key_list = state
    pair == nothing
end

iteratorsize{K, V}(::Type{KeyStore{K, V}}) = SizeUnknown()

end
