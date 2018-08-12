"""
General framework for representing Google JSON APIs.
"""
module api

export APIRoot, APIResource, APIMethod, set_session!, get_session, iserror

using Base.Dates
using Base64

using HTTP
import MbedTLS
import URIParser
import Libz
import JSON

using ..session
using ..error
using ..root

const GZIP_MAGIC_NUMBER = UInt8[0x1f, 0x8b, 0x08]

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
path_tokens(path::AbstractString) = matchall(r"{\w+}", path)

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
path_replace(path::AbstractString, values) = reduce((x, y) -> replace(x, y[1], URIParser.escape(y[2]), 1), path, zip(path_tokens(path), values))

"""Check if response is/contains an error"""
iserror(x::Associative{Symbol}) = haskey(x, :error)
iserror(::Any) = false

"""
    APIMethod(verb, path, description)

Maps a method in the API to an HTTP verb and path.
"""
struct APIMethod
    verb::Symbol
    path::String
    description::String
    default_params::Dict{Symbol, Any}
    transform::Function
    function APIMethod(verb::Symbol, path::AbstractString, description::AbstractString,
                       default_params::Associative{Symbol}=Dict{Symbol, Any}();
                       transform=(x, t) -> x)
        new(verb, path, description, default_params, transform)
    end
end
function Base.print(io::IO, x::APIMethod)
    println(io, "$(x.verb): $(x.path)")
    Base.Markdown.print_wrapped(io, x.description)
end
Base.show(io::IO, x::APIMethod) = print(io, x)

"""
    APIResource(path, methods)

Represents a resource in the API, typically rooted at a specific point in the
REST hierarchy.
"""
struct APIResource
    path::String
    methods::Dict{Symbol, APIMethod}
    transform::Union{Function, DataType}
    function APIResource(path::AbstractString, transform=identity; methods...)
        if isempty(methods)
            throw(APIError("Resource must have at least one method."))
        end
        methods = Dict(methods)
        # build out non-absolute paths
        if isurl(path)
            for (name, method) in methods
                if isempty(method.path)
                    method_path = path
                elseif !isurl(method.path)
                    method_path = startswith(method.path, ":") ? "$(path)$(method.path)" : "$(path)/$(method.path)"
                else
                    continue
                end
                methods[name] = APIMethod(method.verb, method_path, method.description, method.default_params; transform=method.transform)
            end
        end
        new(path, methods, transform)
    end
end
function Base.print(io::IO, x::APIResource)
    println(io, x.path, "\n")
    for (name, method) in sort(collect(x.methods), by=(x) -> x[1])
        println(io)
        println(io, name)
        println(io, repeat("-", length(string(name))))
        print(io, method)
    end
end
Base.show(io::IO, x::APIResource) = print(io, x)

"""
    APIRoot(...)

Represent a Google JSON API containing resources, accessible via scopes.
"""
struct APIRoot
    path::String
    scopes::Dict{String, String}
    resources::Dict{Symbol, APIResource}
    """
        APIRoot(path, scopes; resources...)

    An API rooted at `path` with specified OAuth 2.0 access scopes and
    resources.
    """
    function APIRoot(path::AbstractString, scopes::Associative{<: AbstractString, <: AbstractString}; resources...)
        if !isurl(path)
            throw(APIError("API root must be a valid URL."))
        end
        if isempty(resources)
            throw(APIError("API must contain at least one resource."))
        end
        resources = Dict(resources)
        # build out non-absolute paths
        for (name, resource) in resources
            if isempty(resource.path)
                resource_path = path
            elseif !isurl(resource.path)
                resource_path = "$(path)/$(resource.path)"
            else
                continue
            end
            resources[name] = APIResource(resource_path, resource.transform; resource.methods...)
        end
        new(path, scopes, resources)
    end
end
function Base.print(io::IO, x::APIRoot)
    println(io, x.path, "\n")
    for (name, resource) in sort(collect(x.resources), by=(x) -> x[1])
        println(io)
        println(io, name)
        println(io, repeat("=", length(string(name))))
        println(io, resource)
        println(io, repeat("-", 79))
    end
end
Base.show(io::IO, x::APIRoot) = print(io, x)

"""
    set_session!(api, session)

Set the default session for a specific API. Set session to `nothing` to
forget session.
"""
function set_session!(api::APIRoot, session::Union{GoogleSession, Void})
    _default_session[api] = session
    nothing
end

"""
    get_session(api)

Get the default session for a specific API.
"""
function get_session(api::APIRoot)
    get(_default_session, api, nothing)
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
    session = pop!(kwargs, :session, get(_default_session, api, nothing))
    if session === nothing
        throw(SessionError("Cannot use API without a session."))
    end
    execute(session, resource, method, args...; kwargs...)
end

"""
    execute(session::GoogleSession, resource::APIResource, method::APIMethod, path_args::AbstractString...[; ...])

Execute a method against the provided path arguments.

Optionally provide parameters and data (with optional MIME content-type).
"""
function execute(session::GoogleSession, resource::APIResource, method::APIMethod, path_args::AbstractString...;
    data::Union{AbstractString, Associative, Vector{UInt8}, Void}=nothing,
    gzip::Bool=false, content_type::AbstractString="application/json",
    debug::Bool=false, raw::Bool=false,
    max_backoff::TimePeriod=Second(64), max_attempts::Int64=10,
    params...
)
    if length(path_args) != length(path_tokens(method.path))
        throw(APIError("Number of path arguments do not match"))
    end

    # obtain and use access token
    auth = authorize(session)
    headers = Dict{String, String}(
        "Authorization" => "$(auth[:token_type]) $(auth[:access_token])"
    )
    params = Dict(params)

    # check if data provided when not expected
    if xor((data !== nothing), in(method.verb, (:POST, :UPDATE, :PATCH, :PUT)))
        data = nothing
        content_type = ""
        headers["Content-Length"] = "0"
    end

    # serialise data to JSON if necessary
    if data !== nothing
        if !isempty(content_type)
            headers["Content-Type"] = content_type
        end
        if isa(data, Associative) || content_type == "application/json"
            data = JSON.json(data)
        elseif isempty(data)
            headers["Content-Length"] = "0"
        end
        if gzip
            params[:contentEncoding] = "gzip"
            if !all(data[1:3] .== GZIP_MAGIC_NUMBER)
                # check the data compression using gzip magic number
                data = read(Vector{UInt8}(data) |> Libz.ZlibDeflateInputStream)
            end
        end
    end

    # merge in default parameters and evaluate any expressions
    params = merge!(copy(method.default_params), Dict(params))
    extra = Dict(:project_id => session.credentials.project_id)
    for (key, val) in params
        if isa(val, Symbol)
            params[key] = extra[val]
        end
    end

    # attempt request until exceeding maximum attempts, backing off exponentially
    res = nothing
    max_backoff = Millisecond(max_backoff)
    for attempt = 1:max(max_attempts, 1)
        if debug
            info("Attempt: $attempt")
        end
        req_uri = URIParser.URI(path_replace(method.path, path_args))
        res = try
            HTTP.request(
                string(method.verb), req_uri, headers, data; query=params)
        catch e
            if isa(e, Base.UVError) && e.code in (Base.UV_ECONNRESET, Base.UV_ECONNREFUSED, Base.UV_ECONNABORTED, Base.UV_EPIPE, Base.UV_ETIMEDOUT)
            elseif isa(e, MbedTLS.MbedException) && e.ret in (MbedTLS.MBEDTLS_ERR_SSL_TIMEOUT, MbedTLS.MBEDTLS_ERR_SSL_CONN_EOF)
            else
                rethrow(e)
            end
        end

        if debug && (res !== nothing)
            @info("Request URL: $(req_uri)")
            @info("Request Headers:\n" * join(("  $name: $value" for (name, value) in sort(collect(res.request.headers))), "\n"))
            @info("Request Data:\n  " * Base64.base64encode(res.request.body))
            @info("Response Headers:\n" * join(("  $name: $value" for (name, value) in sort(collect(res.headers))), "\n"))
            @info("Response Data:\n  " * Base64.base64encode(res.body))
            @info("Status: $(res.status)")
        end

        # https://cloud.google.com/storage/docs/exponential-backoff
        if (res === nothing) || (div(statuscode(res), 100) == 5) || (statuscode(res) == 429)
            if attempt < max_attempts
                backoff = min(Millisecond(floor(Int, 1000 * (2 ^ (attempt - 1) + rand()))), max_backoff)
                warn("Unable to complete request: Retrying ($attempt/$max_attempts) in $backoff")
                sleep(backoff / Millisecond(Second(1)))
            else
                warn("Unable to complete request: Stopping ($attempt/$max_attempts)")
            end
        else
            break
        end
    end

    # if response is JSON, parse and return. otherwise, just dump data
    res_headers = Dict(res.headers)
    if occursin(res_headers["Content-Type"], "application/json")
        if get(res_headers, "Content-Length", "") == "0"
            nothing
        else
            result = JSON.parse(String(res.body); dicttype=Dict{Symbol, Any})
            raw || (res.status >= 400) ? result : method.transform(result, resource.transform)
        end
    else
        result, status = res.body, res.status
        status == 200 ? result : Dict{Symbol, Any}(:error => Dict{Symbol, Any}(:message => result, :code => status))
    end
end

const _default_session = Dict{APIRoot, GoogleSession}()

include("iam.jl")
include("storage.jl")
include("compute.jl")
include("container.jl")
include("pubsub.jl")
include("logging.jl")
include("datastore.jl")

end
