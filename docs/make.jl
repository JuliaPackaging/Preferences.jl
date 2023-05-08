using Documenter
using Preferences

makedocs(
    sitename = "Preferences",
    format = Documenter.HTML(),
    modules = [Preferences],
    pages = [
        "index.md",
        "api.md",
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/JuliaPackaging/Preferences.jl",
    devbranch = "master",
    push_preview = true,
    forcepush = true,
)

