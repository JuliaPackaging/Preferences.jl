# Helper function to detect if we're currently compiling
currently_compiling() = ccall(:jl_generating_output, Cint, ()) != 0

"""
    Preferences.uuid_cache::Dict{Module,UUID}

Runtime cache to store the UUIDs of root modules.
Users can make Preferences.jl to work for non-package modules by manually adding a proper
entry to this cache. It may be useful for debugging or analysis purposes.

```julia
julia> using Preferences, Pkg

julia> Preferences.uuid_cache[Main] =
           Pkg.project().dependencies["XXX"]

julia> include("src/XXX.jl") # `Main.XXX` can load configurations for XXX.jl
```

!!! warning
    Improper manipulation on this cache may cause unexpected behaviors.
    Use with care and only as a last resort if absolutely required.
"""
const uuid_cache = Dict{Module,UUID}()

# Helper function to get the UUID of a module, throwing an error if it can't.
function get_uuid(m::Module)
    rootm = Base.moduleroot(m)
    if haskey(uuid_cache, rootm)
        return uuid_cache[rootm]
    end
    uuid = Base.PkgId(m).uuid
    if uuid === nothing
        throw(ArgumentError("Module $(m) does not correspond to a loaded package!"))
    end
    return uuid_cache[rootm] = uuid
end

function find_first_project_with_uuid(uuid::UUID)
    # Find first element in `Base.load_path()` that contains this UUID
    # This code should look similar to the search in `Base.get_preferences()`
    for env in Base.load_path()
        project_toml = Base.env_project_file(env)
        if !isa(project_toml, String)
            continue
        end

        # Check to see if this project has a name mapping
        pkg_name = Base.get_uuid_name(project_toml, uuid)
        if pkg_name !== nothing
            return (project_toml, pkg_name)
        end
    end
    return (nothing, nothing)
end

# Drop any nested `__clear__` keys:
function drop_clears(@nospecialize(data))
    if isa(data, Dict{String,Any})
        delete!(data, "__clear__")
        for (_, v) in data
            drop_clears(v)
        end
    end
    return data
end
