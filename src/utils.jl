# Helper function to detect if we're currently compiling
currently_compiling() = ccall(:jl_generating_output, Cint, ()) != 0

# Helper function to get the UUID of a module, throwing an error if it can't.
function get_uuid(m::Module)
    uuid = Base.PkgId(m).uuid
    if uuid === nothing
        throw(ArgumentError("Module $(m) does not correspond to a loaded package!"))
    end
    return uuid
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
