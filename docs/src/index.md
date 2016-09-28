# Google Cloud APIs for Julia

This module wraps Google Cloud Platform (GCP) APIs with Julia.

Currently only the Google Storage API has been added.

## Quick-Start

This Quick Start walks through the steps required to store and retrieve data from Google Cloud Storage.

1. If you don't already have a Google account, create one [here](https://accounts.google.com/SignUp?hl=en).

2. Sign in to the GCP console [here](https://console.cloud.google.com/) and create a new project by clicking on _Create Project_ at the top of the page. If you already have a GCP project, click on the drop-down menu at the top of the page and select _Create project_.

A GCP **Project** is a set of resources with common settings that is billed and managed separately from any resource outside the set. Thus a resource exists in exactly one project. Examples of resources include GCE instances, storage volumes and data on those volumes. A project's settings include ownership, users and their permissions, and associated GCP services. As a user anything you do on GCP happens within a project, including data storage, compute, messaging, logging, etc.

3. Install the [GoogleCloud.jl](https://github.com/joshbode/GoogleCloud.jl) package.

   ```julia
   Pkg.add("GoogleCloud")
   using GoogleCloud
   ```

4. Associated with your project are credentials that allow users to add, read and remove resources from the project. Get the credentials for your project as a JSON file from your [GCP Credentials](https://console.cloud.google.com/apis/credentials) page.

   ```julia
   creds = GoogleCredentials(expanduser("~/credentials.json"))    # Credentials stored in ~/credentials.json
   ```

5. Create a session with the credentials, requesting any required scopes.

   ```julia
   session = GoogleSession(creds, ["devstorage.full_control"])
   ```

6. Set the default session of an API using `set_session`

   ```julia
   set_session(storage, session)    # storage is a variable exported from GoogleCloud.jl
   ```

7. List existing buckets in your project.

   ```julia
   storage(:Bucket, :list)
   ```

8. Create a bucket called _foo_.

   ```julia
   storage(:Bucket, :insert; data=Dict(:name => "foo"))
   ```

9. List all objects in the _foo_ bucket.

   ```julia
   storage(:Object, :list, "foo")
   ```

10. Upload an object to the _foo_ bucket.

   ```julia
   storage(:Object, :insert, "foo";
       name="image.jpg",                           # Object name is "image.jpg"
       data=readstring(open("horse.jpg", "r")),    # Object contains the contents of the horser.jpg file
       content_type="image/jpeg"                   # The contents are specified to be in JPEG format
   )
   ```

11. List all objects again.

   ```julia
   storage(:Object, :list, "foo")
   ```

12. Get the _image.jpg_ object from the bucket.

   ```julia
   s = storage(:Object, :get, "foo", "image.jpg")
   s = JSON.parse(s)
   ```

## API Documentation
```@contents
Pages = [joinpath("api", x) for x in readdir("api") if splitext(x)[2] == ".md"]
Depth = 2
```

## Index
```@index
```
