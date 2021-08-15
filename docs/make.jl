using Mixes
using Documenter

DocMeta.setdocmeta!(Mixes, :DocTestSetup, :(using Mixes); recursive=true)

makedocs(;
    modules=[Mixes],
    authors="Constantine Evans <const@costinet.org> and contributors",
    repo="https://github.com/cgevans/Mixes.jl/blob/{commit}{path}#{line}",
    sitename="Mixes.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://cgevans.github.io/Mixes.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/cgevans/Mixes.jl",
    devbranch="main",
)
