#! /usr/bin/env julia

import Documenter
using GoogleCloud

Documenter.makedocs(
    modules=[GoogleCloud], doctest=true,
    sitename="Google Cloud JSON APIs",
    format=Documenter.Formats.HTML
)
