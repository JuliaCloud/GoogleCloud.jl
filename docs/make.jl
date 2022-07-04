#! /usr/bin/env julia

using Documenter
using GoogleCloud

makedocs(
    doctest=true,
    sitename="Google Cloud JSON APIs"
)

deploydocs(
    deps=Deps.pip("pygments", "mkdocs", "python-markdown-math"),
    repo="github.com/JuliaCloud/GoogleCloud.jl.git",
    push_preview = true,
)
