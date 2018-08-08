# Google Cloud APIs for Julia

This module wraps Google Cloud Platform (GCP) APIs with Julia.

Currently only the Google Storage API has been added.

## Quick Start

This Quick Start walks through the steps required to store and retrieve data from Google Cloud Storage.

### Google Cloud Prerequisites

1. If you don't already have a Google account, create one [here](https://accounts.google.com/SignUp?hl=en).

2. Sign in to the GCP console [here](https://console.cloud.google.com/).

3. Create a new project by clicking on the **Project** drop-down menu at the
   top of the page. If you already have a GCP project, click on the drop-down
   menu at the top of the page and select **Create project**.

    A GCP project is a set of resources with common settings that is billed and
    managed separately from any resource outside the set. Thus a resource
    exists in exactly one project. Examples of resources include GCE instances,
    storage volumes and data on those volumes. A project's settings include
    ownership, users and their permissions, and associated GCP services. As a
    user anything you do on GCP happens within a project, including data
    storage, compute, messaging, logging, etc.


4. Associated with your project are credentials that allow users to add, read
   and remove resources from the project. Get the credentials for your project
   as a JSON file from your [GCP Credentials](https://console.cloud.google.com/apis/credentials)
   page:

    - Type _credentials_ into the search bar at the top of the console.
    - Select **Credentials API Manager** from the search results.
    - Click on the **Create credentials** drop-down menu and select **Service account key**.
    - From the **Service Account** menu select **New service account**.
    - From **Role** select **Storage > Storage Admin**.
    - Ensure the key type is JSON.
    - Click **Create**.

    Credentials are then automatically downloaded in a JSON file. Save this file to your machine. In this tutorial we save the service account credentials to `~/credentials.json`.

### Interacting with the Storage API from Julia

Start Julia and install the [GoogleCloud.jl](https://github.com/joshbode/GoogleCloud.jl) package:

```julia
Pkg.add("GoogleCloud")
using GoogleCloud
```

Load the service account credentials obtained from Google:

```julia
credentials = JSONCredentials(expanduser("~/credentials.json"))
```

Alternatively, if the process is running on a Google Compute Engine instance,
the credentials can be derived from the [instance metadata](https://cloud.google.com/compute/docs/storing-retrieving-metadata)
directly (i.e. without JSON):

```julia
credentials = MetadataCredentials()
```

Now, create a session with the credentials, requesting any required scopes:

```julia
session = GoogleSession(credentials, ["devstorage.full_control"])
```

Set the default session of an API using `set_session!`:

```julia
set_session!(storage, session)    # storage is the API root, exported from GoogleCloud.jl
```

List all existing buckets in your project. The list contains a default bucket:

```julia
bkts = storage(:Bucket, :list)    # storage(:Bucket, :list; raw=true) returns addition information

# Pretty print
for item in bkts
    display(item)
    println()
end
```

Create a bucket called _a12345foo_, for example. **Note**: The bucket name must
be unique... across all buckets in GCP, so choose your own!

```julia
storage(:Bucket, :insert; data=Dict(:name => "a12345foo"))

# Verify the new bucket exists in the project
bkts = storage(:Bucket, :list)
for item in bkts
    display(item)
    println()
end
```

List all objects in the _a12345foo_ bucket. The list is currently empty:

```julia
storage(:Object, :list, "a12345foo")
```

Upload an object to the _a12345foo_ bucket:

```julia
# String containing the contents of test_image.jpg. The semi-colon avoids an error caused by printing the returned value.
file_contents = read(open("test_image.jpg", "r"), String);

# Upload
storage(:Object, :insert, "a12345foo";     # Returns metadata about the object
    name="image.jpg",           # Object name is "image.jpg"
    data=file_contents,         # The data being stored on your project
    content_type="image/jpeg"   # The contents are specified to be in JPEG format
)

# Verify that the object is in the bucket
obs = storage(:Object, :list, "a12345foo")    # Ugly print
map(x -> x[:name], obs)                       # Pretty print
```

Get the _image.jpg_ object from the bucket:

```julia
s = storage(:Object, :get, "a12345foo", "image.jpg");
s == file_contents    # Verify that the retrieved data is the same as that originally posted
```

Delete the _image.jpg_ object from the bucket:

```julia
storage(:Object, :delete, "a12345foo", "image.jpg")

# Verify that the bucket is now empty
storage(:Object, :list, "a12345foo")
```

Delete the bucket:

```julia
storage(:Bucket, :delete, "a12345foo")

# Verify that the bucket has been deleted
bkts = storage(:Bucket, :list)
for item in bkts
    display(item)
    println()
end
```

## High-Level API
```@contents
Pages = ["custom_api/index.md"]
Depth = 2
```

## Low-Level API
```@contents
Pages = ["api/credentials.md", "api/session.md", "api/api.md", "api/root.md", "api/error.md"]
Depth = 2
```

## Index
```@index
```
