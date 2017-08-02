"""
Basic exceptions.
"""
module error

export CredentialError, SessionError, APIError

import Base: showerror

"""
Base error type.
"""
abstract type Error <: Exception end

showerror(io::IO, e::Error) = print(io, "$(typeof(e)): $(e.message)")

"""
An error in the provided credentials.
"""
struct CredentialError <: Error
    message::String
    CredentialError(message::AbstractString) = new(message)
end

"""
An error in establising a session.
"""
struct SessionError <: Error
    message::String
    SessionError(message::AbstractString) = new(message)
end

"""
An error from the API.
"""
struct APIError <: Error
    message::String
    APIError(message::AbstractString) = new(message)
end

end
