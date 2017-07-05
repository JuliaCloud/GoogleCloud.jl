"""
Google Cloud Storage API
"""
module _storage

export storage

using ..api
using ...root

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
        insert=APIMethod(:POST, "", "Creates a new bucket.",
            Dict(:project => :project_id)
        ),
        list=APIMethod(:GET, "", "Retrieves a list of buckets for a given project.",
            Dict(:project => :project_id);
            transform=(x, t) -> map(t, get(x, :items, []))
        ),
        patch=APIMethod(:PATCH, "{bucket}", "Updates a bucket. This method supports patch semantics."),
        update=APIMethod(:PUT, "{bucket}", "Updates a bucket."),
    ),
    BucketAccessControl=APIResource("b/{bucket}/acl";
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
    ObjectAccessControl=APIResource("b/{bucket}/o/{object}/acl";
        delete=APIMethod(:DELETE, "{entity}", "Permanently deletes the ACL entry for the specified entity on the specified object."),
        get=APIMethod(:GET, "{entity}", "Returns the ACL entry for the specified entity on the specified object."),
        insert=APIMethod(:POST, "", "Creates a new ACL entry on the specified object."),
        list=APIMethod(:GET, "", "Retrieves ACL entries on the specified object."; transform=(x, t) -> map(t, get(x, :items, []))),
        patch=APIMethod(:PATCH, "{entity}", "Updates an ACL entry on the specified object. This method supports patch semantics."),
        update=APIMethod(:PUT, "{entity}", "Updates an ACL entry on the specified object."),
    ),
    DefaultObjectAccessControl=APIResource("b/{bucket}/defaultObjectAcl";
        delete=APIMethod(:DELETE, "entity", "Permanently deletes the default object ACL entry for the specified entity on the specified bucket."),
        get=APIMethod(:GET, "entity", "Returns the default object ACL entry for the specified entity on the specified bucket."),
        insert=APIMethod(:POST, "", "Creates a new default object ACL entry on the specified bucket."),
        list=APIMethod(:GET, "", "Retrieves default object ACL entries on the specified bucket."; transform=(x, t) -> map(t, get(x, :items, []))),
        patch=APIMethod(:PATCH, "entity", "Updates a default object ACL entry on the specified bucket. This method supports patch semantics."),
        update=APIMethod(:PUT, "entity", "Updates a default object ACL entry on the specified bucket."),
    ),
    Channel=APIResource("channels";
        stop=APIMethod(:POST, "stop", "Stop receiving object change notifications through this channel."),
    ),
)

end
