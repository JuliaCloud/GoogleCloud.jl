#! /usr/bin/env julia

import Documenter
using GoogleCloud

Documenter.makedocs(
    modules=[GoogleCloud], doctest=true,
    sitename="Google Cloud JSON APIs",
    format=Documenter.Formats.HTML,
    deps=Deps.pip("mkdocs", "python-markdown-math"),
    repo="github.com/joshbode/GoogleCloud.jl.git",
    julia="0.5"
)
