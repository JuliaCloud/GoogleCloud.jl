#! /usr/bin/env julia

using Documenter
using GoogleCloud

makedocs(
    modules=[GoogleCloud], doctest=true,
    sitename="Google Cloud JSON APIs"
)

deploydocs(
    deps=Deps.pip("pygments", "mkdocs", "python-markdown-math"),
    repo="github.com/joshbode/GoogleCloud.jl.git",
    julia="0.5"
)
