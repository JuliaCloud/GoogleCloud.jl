# Google Cloud APIs for Julia

This module wraps Google Cloud Platform (GCP) APIs with Julia.

Currently only the Google Storage API has been added.

## Quick Start

This Quick Start walks through the steps required to store and retrieve data from Google Cloud Storage.

1. If you don't already have a Google account, create one [here](https://accounts.google.com/SignUp?hl=en).

2. Sign in to the GCP console [here](https://console.cloud.google.com/).

3. Create a new project by clicking on the _Project_ drop-down menu at the top of the page. If you already have a GCP project, click on the drop-down menu at the top of the page and select _Create project_.

    A GCP **Project** is a set of resources with common settings that is billed and managed separately from any resource outside the set. Thus a resource exists in exactly one project. Examples of resources include GCE instances, storage volumes and data on those volumes. A project's settings include ownership, users and their permissions, and associated GCP services. As a user anything you do on GCP happens within a project, including data storage, compute, messaging, logging, etc.

4. Install the [GoogleCloud.jl](https://github.com/joshbode/GoogleCloud.jl) package.

   ```julia
   Pkg.add("GoogleCloud")
   using GoogleCloud
   ```

5. Associated with your project are credentials that allow users to add, read and remove resources from the project. Get the credentials for your project as a JSON file from your [GCP Credentials](https://console.cloud.google.com/apis/credentials) page.

    - From _Service Account_ select _New_ service account.
    - From _Role_ select _Storage > Storage Admin_.

   ```julia
   creds = GoogleCredentials(expanduser("~/credentials.json"))    # Credentials stored in ~/credentials.json
   ```

6. Create a session with the credentials, requesting any required scopes.

   ```julia
   session = GoogleSession(creds, ["devstorage.full_control"])
   ```

7. Set the default session of an API using `set_session`

   ```julia
   set_session(storage, session)    # storage is a variable exported from GoogleCloud.jl
   ```

8. List existing buckets in your project. The list contains a default bucket.

   ```julia
   bkts = storage(:Bucket, :list)

   for item in bkts[:items]
       display(item)
       println()
   end
   ```

9. Create a bucket called _a12345foo_. __Note__: The bucket name must be unique...across all buckets in GCP!

   ```julia
   storage(:Bucket, :insert; data=Dict(:name => "a12345foo"))

   bkts = storage(:Bucket, :list)
   for item in bkts[:items]
       display(item)
       println()
   end
   ```

10. List all objects in the _a12345foo_ bucket.

   ```julia
   storage(:Object, :list, "foo")
   ```

11. Upload an object to the _a12345foo_ bucket.

   ```julia
   file_contents = readstring(open("test_image.jpg", "r"))    # String containing the contents of test_image.jpg

   #storage(:Object, :insert, "a12345foo";
   storage(:Object, :insert, "jocktest_foo";
       name="image.jpg",           # Object name is "image.jpg"
       data=file_contents,         # The data being stored on your project
       content_type="image/jpeg"   # The contents are specified to be in JPEG format
   )

   storage(:Object, :list, "a12345foo")
   ```

12. Get the _image.jpg_ object from the bucket.

   ```julia
   s = storage(:Object, :get, "a12345foo", "image.jpg");    # Semi-colon avoids printing, which may throw a UnicodeError
   s == file_contents                                       # Check that the retrieved data is the same as that originally posted
   ```

13. Delete the _image.jpg_ object from the bucket.

   ```julia
   storage(:Object, :delete, "a12345foo", "image.jpg")
   storage(:Object, :list, "a12345foo")
   ```

14. Delete the bucket.

   ```julia
   storage(:Bucket, :delete, "a12345foo")
   storage(:Bucket, :list)
   ```


## API Documentation
```@contents
Pages = [joinpath("api", x) for x in readdir("api") if splitext(x)[2] == ".md"]
Depth = 2
```

## Index
```@index
```
