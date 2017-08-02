"""
Google Cloud Platform service-account API credentials.
"""
module credentials

export Credentials, JSONCredentials, MetadataCredentials

import Base: show, print
import JSON
import MbedTLS
import Requests
using URIParser

using ..error

abstract type Credentials end

struct MetadataCredentials <: Credentials
    url::String
    scopes::Vector{String}
    function Metadata(url::AbstractString="$METADATA_ROOT/instance/service-accounts/default")
        headers = Dict{String, String}("Metadata-Flavor" => "Google")
        res = Requests.get(joinpath(url, "scopes"), headers=headers)
        if statuscode(res) != 200
            throw(CredentialError("Unable to obtain credentials from metadata server"))
        end
        scopes = split(String(res.data), '\n')
        new(url, scopes)
    end
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
function JSONCredentials(data::Associative{Symbol, <: AbstractString})
    fields = fieldnames(JSONCredentials)
    fields[findfirst(fields, :account_type)] = :type  # type is a keyword!
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

function print(io::IO, x::JSONCredentials)
    fields = [:client_id, :client_email, :account_type, :project_id]
    print(io, join(("$field: $(getfield(x, field))" for field in fields), "\n"))
end
show(io::IO, x::JSONCredentials) = print(io, x)

end
