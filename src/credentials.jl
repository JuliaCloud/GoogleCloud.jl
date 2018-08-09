"""
Google Cloud Platform service-account API credentials.
"""
module credentials

export Credentials, JSONCredentials, MetadataCredentials

import Base: show, print
import JSON
import MbedTLS
#import Requests
import HTTP
using HTTP.URIs

using ..error
using ..root

abstract type Credentials end

"""
Get credential/service-account information from GCE metadata server

See [Storing and Retreiving Instance Metadata](https://cloud.google.com/compute/docs/storing-retrieving-metadata)
"""
struct MetadataCredentials <: Credentials
    url::String
    service_account::String
    project_id::String
    client_email::String
    scopes::Vector{String}
    function MetadataCredentials(; url::AbstractString=METADATA_ROOT, service_account::AbstractString="default")
        metadata = new(url, service_account)
        project_id, client_email, scopes = try
            (
                get(metadata, "project-id"; context=:project),
                get(metadata, "email"; context=:service_account),
                split(chomp(get(metadata, "scopes"; context=:service_account)), '\n')
            )
        catch e
            throw(CredentialError("Unable to contact metadata server"))
        end
        new(url, service_account, project_id, client_email, scopes)
    end
end

function Base.get(credentials::MetadataCredentials, path::AbstractString; context::Symbol=:service_account)
    headers = Dict{String, String}("Metadata-Flavor" => "Google")
    if context == :service_account
        url = joinpath(credentials.url, "instance/service-accounts/$(credentials.service_account)")
    elseif context == :instance
        url = joinpath(credentials.url, "instance")
    elseif context == :project
        url = joinpath(credentials.url, "project")
    else
        throw(CredentialError("Unknown metadata context: $context"))
    end
    res = HTTP.get(joinpath(url, path), headers=headers)
    if HTTP.Messages.status(res) != 200
        throw(CredentialError("Unable to obtain credentials from metadata server"))
    end
    String(res.data)
end

"""
    JSONCredentials(...)

Parse JSON credentials created for a service-account at
[Google Cloud Platform Console](https://console.cloud.google.com/apis/credentials)
"""
struct JSONCredentials <: Credentials
    account_type::String
    project_id::String
    private_key_id::String
    private_key::MbedTLS.PKContext
    client_email::String
    client_id::String
    auth_uri::URI
    token_uri::URI
    auth_provider_x509_cert_url::URI
    client_x509_cert_url::URI
    function JSONCredentials(account_type::AbstractString, project_id::AbstractString,
                             private_key_id::AbstractString, private_key::AbstractString,
                             client_email::AbstractString, client_id::AbstractString,
                             auth_uri::AbstractString, token_uri::AbstractString,
                             auth_provider_x509_cert_url::AbstractString,
                             client_x509_cert_url::AbstractString)
        ctx = MbedTLS.PKContext()
        MbedTLS.parse_key!(ctx, private_key)
        new(
            account_type, project_id, private_key_id, ctx, client_email, client_id,
            URI(auth_uri), URI(token_uri), URI(auth_provider_x509_cert_url), URI(client_x509_cert_url)
        )
    end
end

"""
    JSONCredentials(data::Dict{Symbol, String})

Initialise credentials from dictionary containing values.
"""
function JSONCredentials(data::AbstractDict{Symbol, <: AbstractString})
    fields = fieldnames(JSONCredentials)
    fields = [fields...,]
    fields[findfirst(x->x==:account_type, fields)] = :type  # type is a keyword!
    missing = setdiff(fields, keys(data))
    if !isempty(missing)
        info(missing)
        throw(CredentialError("Missing fields in key: ", join(missing, ", ")))
    end
    JSONCredentials((data[field] for field in fields)...)
end

"""
    JSONCredentials(filename)

Load credentials from a JSON file.
"""
JSONCredentials(filename::AbstractString) = JSONCredentials(JSON.parsefile(filename; dicttype=Dict{Symbol, String}))
JSONCredentials(io::IO) = JSONCredentials(JSON.parse(io; dicttype=Dict{Symbol, String}))

Base.convert(::Type{JSONCredentials}, x::AbstractString) = JSONCredentials(x)

function print(io::IO, x::Credentials)
    fields = [:project_id, :client_email]
    print(io, join(("$field: $(getfield(x, field))" for field in fields), "\n"))
end
show(io::IO, x::JSONCredentials) = print(io, x)

end
