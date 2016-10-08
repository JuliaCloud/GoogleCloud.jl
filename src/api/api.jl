"""
General framework for representing Google JSON APIs.
"""
module api

export APIRoot, APIResource, APIMethod, set_session!, get_session, iserror

import Base: show, print, getindex
import Requests
import URIParser
import Libz
import JSON

using ..session
using ..error
using ..root

"""
    path_tokens(path)

Extract tokens from a path, e.g.

```
path_tokens("/{foo}/{bar}/x/{baz}")
# output
3-element Array{SubString{String},1}:
 "{foo}"
 "{bar}"
 "{baz}"
```
"""
path_tokens(path::String) = matchall(r"{\w+}", path)

"""
    path_replace(path, values)

Replace path tokens in path with values.

Assumes values are provided in the same order in which tokens appear in the path.

```
path_replace("/{foo}/{bar}/{baz}", ["this", "is", "it"])
# output
"/this/is/it"
```
"""
path_replace(path::String, values) = reduce((x, y) -> replace(x, y[1], y[2], 1), path, zip(path_tokens(path), values))

"""Check if response is/contains an error"""
iserror(x::Any) = isa(x, Dict{Symbol, Any}) && haskey(x, :error)

"""
    APIMethod(verb, path, description)

Maps a method in the API to an HTTP verb and path.
"""
type APIMethod
    verb::Symbol
    path::String
    description::String
    default_params::Dict{Symbol, Any}
    transform::Function
    function APIMethod(verb::Symbol, path::String, description::String,
        default_params::Dict=Dict{Symbol, Any}();
        transform=(x, t) -> x
    )
        new(verb, path, description, default_params, transform)
    end
end
function print(io::IO, x::APIMethod)
    println(io, "$(x.verb): $(x.path)")
    Base.Markdown.print_wrapped(io, x.description)
end
show(io::IO, x::APIMethod) = print(io, x)

"""
    APIResource(path, methods)

Represents a resource in the API, typically rooted at a specific point in the
REST hierarchy.
"""
type APIResource
    path::String
    methods::Dict{Symbol, APIMethod}
    transform::Union{Function, DataType}
    function APIResource(path::String, transform=identity; methods...)
        if isempty(path)
            throw(APIError("Resource path can not be empty."))
        end
        if isempty(methods)
            throw(APIError("Resource must have at least one method."))
        end
        new(path, Dict{Symbol, APIMethod}(methods), transform)
    end
end
function print(io::IO, x::APIResource)
    println(io, x.path, "\n")
    for (name, method) in x.methods
        println(io, name)
        println(io, repeat("-", length(string(name))))
        println(io, method)
    end
end
show(io::IO, x::APIResource) = print(io, x)

"""
    APIRoot(...)

Represent a Google JSON API containing resources, accessible via scopes.
"""
type APIRoot
    path::String
    scopes::Dict{String, String}
    resources::Dict{Symbol, APIResource}
    default_session::Nullable{GoogleSession}
    """
        APIRoot(path, scopes; resources...)

    An API rooted at `path` with specified OAuth 2.0 access scopes and
    resources.
    """
    function APIRoot(path::String, scopes::Dict{String, String}; resources...)
        if !isurl(path)
            throw(APIError("API root must be a valid URL."))
        end
        if isempty(resources)
            throw(APIError("API must contain at least one resource."))
        end
        resources = Dict(resources)
        # build out non-absolute paths
        for resource in values(resources)
            if !isurl(resource.path)
                resource.path = "$(path)/$(resource.path)"
            end
            for method in values(resource.methods)
                if isempty(method.path)
                    method.path = resource.path
                elseif !isurl(method.path)
                    method.path = "$(resource.path)/$(method.path)"
                end
            end
        end
        new(path, scopes, resources, nothing)
    end
end
function print(io::IO, x::APIRoot)
    println(io, x.path, "\n")
    for (name, resource) in x.resources
        println(io, name)
        println(io, repeat("=", length(string(name))))
        println(io, resource)
        println(io, repeat("-", 79))
    end
end
show(io::IO, x::APIRoot) = print(io, x)

"""
    set_session!(api, session)

Set the default session for a specific API. Set session to `nothing` to
forget session.
"""
function set_session!(api::APIRoot, session::Union{GoogleSession, Void})
    api.default_session = session
    nothing
end

"""
    get_session(api)

Get the default session (if any) for a specific API. Session is `nothing` if
not set.
"""
function get_session(api::APIRoot)
    get(api.default_session, nothing)
end

function (api::APIRoot)(resource_name::Symbol)
    resource = try api.resources[resource_name] catch
        throw(APIError("Unknown resource type: $resource_name"))
    end
end

function (api::APIRoot)(resource_name::Symbol, method_name::Symbol, args...; kwargs...)
    resource = api(resource_name)
    method = try resource.methods[method_name] catch
        throw(APIError("Unknown method for resource $resource_name: $method_name"))
    end
    kwargs = Dict(kwargs)
    session = pop!(kwargs, :session, get_session(api))
    if session == nothing
        throw(SessionError("Cannot use API without a session."))
    end
    execute(session, resource, method, args...; kwargs...)
end

"""
    execute(session::GoogleSession, resource::APIResource, method::APIMethod, path_args::String...[; ...])

Execute a method against the provided path arguments.

Optionally provide parameters and data (with optional MIME content-type).
"""
function execute(session::GoogleSession, resource::APIResource, method::APIMethod,
    path_args::String...;
    data::Any=nothing, content_type::String="application/json",
    debug=false, raw=false, gzip=true,
    params...
)
    # check if data provided when not expected
    if (data != nothing) $ in(method.verb, (:POST, :UPDATE, :PATCH, :PUT))
        action = data == nothing ? "supplied" : "supported"
        throw(APIError("Resource data not $action for method"))
    end
    if length(path_args) != length(path_tokens(method.path))
        throw(APIError("Number of path arguments do not match"))
    end

    # obtain and use access token
    auth = authorize(session)
    headers = Dict{String, String}(
        "Authorization" => "$(auth[:token_type]) $(auth[:access_token])"
    )

    # merge in default parameters
    params = merge!(copy(method.default_params), Dict(params))

    # add default project ID from credentials if not provided
    if !haskey(params, :project)
        params[:project] = session.credentials.project_id
    end

    # serialise data to JSON if necessary
    if data != nothing
        if !isempty(content_type)
            headers["Content-Type"] = content_type
        end
        if content_type == "application/json" && !isa(data, Union{String, Vector{UInt8}})
            data = JSON.json(data)
        end
        if gzip
            params[:contentEncoding] = "gzip"
            data = read(Vector{UInt8}(data) |> Libz.ZlibDeflateInputStream)
        end
    end
    res = Requests.do_request(
        URIParser.URI(path_replace(method.path, path_args)), string(method.verb);
        query=params, data=data, headers=headers,
        compressed=true
    )

    if debug
        info("Request URL: $(get(res.request).uri)")
        info("Request Headers:\n" * join(("  $name: $value" for (name, value) in sort(collect(get(res.request).headers))), "\n"))
        info("Request Data:\n  " * base64encode(get(res.request).data))
        info("Response Headers:\n" * join(("  $name: $value" for (name, value) in sort(collect(res.headers))), "\n"))
        info("Response Data:\n  " * base64encode(res.data))
    end

    # if response is JSON, parse and return. otherwise, just dump data
    if get(res.headers, "Content-Length", "") == "0"
        nothing
    elseif contains(res.headers["Content-Type"], "application/json")
        result = Requests.json(res; dicttype=Dict{Symbol, Any})
        raw ? result : method.transform(result, resource.transform)
    else
        result, status = Requests.readall(res), Requests.statuscode(res)
        status == 200 ? result : Dict{Symbol, Any}(:error => Dict{Symbol, Any}(:message => result, :code => status))
    end
end

include("storage.jl")

end
