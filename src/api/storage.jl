"""
Google Cloud Storage API
"""
module storage_api

export storage, KeyStore

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
import Base: print, show, display, getindex, setindex!, delete!, pop!, haskey, in, keys, values

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
    function KeyStore(bucket_name::String, session::GoogleSession=get_session(storage),
        key_reader::Function=(x) -> parse(K, x), key_writer::Function=string,
        val_reader::Function=(x) -> parse(V, x), val_writer::Function=string
    )
        bucket = storage(:Bucket, :get, bucket_name; session=session)
        if haskey(bucket, :error)
            metadata = storage(:Bucket, :insert; session=session, data=Dict(:name => bucket_name))
            if haskey(metadata, :error)
                error("Unable to create bucket: $(bucket[:error][:message])")
            end
        end
        new(bucket_name, session, key_reader, key_writer, val_reader, val_writer)
    end
end
print(io::IO, store::KeyStore) = print(io, "KeyStore($(store.bucket_name))")
show(io::IO, store::KeyStore) = print(io, store)
display(store::KeyStore) = print(store)

function getindex{K, V}(store::KeyStore{K, V}, key::K)
    name = store.key_writer(key)
    val = storage(:Object, :get, store.bucket_name, name; session=store.session)
    if isa(val, Dict{Symbol, Any}) && haskey(val, :error)
        throw(KeyError("$(store.bucket_name):$name"))
    end
    data = store.val_reader(val)
    if !isa(data, V)
        throw(TypeError(:getindex, "$(store.bucket_name):$name", V, data))
    else
	data
    end
end

function setindex!{K, V}(store::KeyStore{K, V}, val::V, key::K)
    name = store.key_writer(key)
    data = store.val_writer(val)
    storage(:Object, :insert, store.bucket_name; session=store.session, name=name, data=data, content_type="text/plain")
    val
end

function delete!{K, V}(store::KeyStore{K, V}, key::K)
    name = store.key_writer(key)
    storage(:Object, :delete, store.bucket_name, name; session=store.session)
end

function pop!{K, V}(store::KeyStore{K, V}, key::K)
    val = store[key]
    delete!(store, key)
    val
end

function haskey{K, V}(store::KeyStore{K, V}, key::K)
    name = store.key_writer(key)
    metadata = storage(:Object, :get, store.bucket_name, name; session=store.session, alt="")
    !haskey(metadata, :error)
end

function in{K, V}(store::KeyStore{K, V}, key::K)
    haskey(store, key)
end

function keys{K, V}(store::KeyStore{K, V})
    result = K[]
    for metadata in storage(:Object, :list, store.bucket_name; session=store.session)
        name = metadata[:name]
        key = store.key_reader(name)
        if !isa(key, K)
            throw(TypeError(:keys, "$(store.bucket_name):$name", K, key))
        end
        push!(result, key)
    end
    result
end

function values{K, V}(store::KeyStore{K, V})
    V[store[key] for key in keys(store)]
end

end
