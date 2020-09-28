using TOML
using Base: UUID, TOMLCache

export load_preferences, @load_preferences,
       save_preferences!, @save_preferences!,
       modify_preferences!, @modify_preferences!,
       clear_preferences!, @clear_preferences!

# Helper function to get the UUID of a module, throwing an error if it can't.
function get_uuid(m::Module)
    uuid = Base.PkgId(m).uuid
    if uuid === nothing
        throw(ArgumentError("Module does not correspond to a loaded package!"))
    end
    return uuid
end


"""
    load_preferences(uuid_or_module)

Load the preferences for the given package, returning them as a `Dict`.  Most users
should use the `@load_preferences()` macro which auto-determines the calling `Module`.

Preferences can be stored in `Project.toml` files that are higher up in the chain of
environments in the LOAD_PATH, the first environment that contains the given UUID (even
as a transitive dependency) will be the one that is searched in for preferences.
"""
function load_preferences(uuid::UUID, toml_cache::TOMLCache = TOMLCache())
    # Re-use definition in `base/loading.jl` so as to not repeat code.
    return Base.get_preferences(uuid, toml_cache; prefs_key=PREFS_KEY)
end
load_preferences(m::Module) = load_preferences(get_uuid(m))


"""
    save_preferences!(uuid_or_module, prefs::Dict)

Save the preferences for the given package.  Most users should use the
`@save_preferences!()` macro which auto-determines the calling `Module`.  See also the
`modify_preferences!()` function (and the associated `@modifiy_preferences!()` macro) for
easy load/modify/save workflows.  The same `Project.toml` file that is loaded from in
`load_preferences()` will be the one that these preferences are stored to, falling back
to the currently-active project if no previous mapping is found.
"""
function save_preferences!(uuid::UUID, prefs::Dict)
    # Save to Project.toml
    proj_path = something(Base.get_preferences_project_path(uuid), Base.active_project())
    mkpath(dirname(proj_path))
    project = Dict{String,Any}()
    if isfile(proj_path)
        project = TOML.parsefile(proj_path)
    end
    if !haskey(project, PREFS_KEY)
        project[PREFS_KEY] = Dict{String,Any}()
    end
    if !isa(project[PREFS_KEY], Dict)
        error("$(proj_path) has conflicting `$(PREFS_KEY)` entry type: Not a Dict!")
    end
    project[PREFS_KEY][string(uuid)] = prefs
    open(proj_path, "w") do io
        TOML.print(io, project, sorted=true)
    end
    return nothing
end
function save_preferences!(m::Module, prefs::Dict)
    return save_preferences!(get_uuid(m), prefs)
end


"""
    modify_preferences!(f::Function, uuid::UUID)
    modify_preferences!(f::Function, m::Module)

Supports `do`-block modification of preferences.  Loads the preferences, passes them to a
user function, then writes the modified `Dict` back to the preferences file.  Example:

```julia
modify_preferences!(@__MODULE__) do prefs
    prefs["key"] = "value"
end
```

This function returns the full preferences object.  Most users should use the
`@modify_preferences!()` macro which auto-determines the calling `Module`.
"""
function modify_preferences!(f::Function, uuid::UUID)
    prefs = load_preferences(uuid)
    f(prefs)
    save_preferences!(uuid, prefs)
    return prefs
end
modify_preferences!(f::Function, m::Module) = modify_preferences!(f, get_uuid(m))


"""
    clear_preferences!(uuid::UUID)
    clear_preferences!(m::Module)

Convenience method to remove all preferences for the given package.  Most users should
use the `@clear_preferences!()` macro, which auto-determines the calling `Module`.
"""
function clear_preferences!(uuid::UUID)
    # Clear the project preferences key, if it exists
    proj_path = Base.get_preferences_project_path(uuid)
    if proj_path !== nothing && isfile(proj_path)
        project = TOML.parsefile(proj_path)
        if haskey(project, PREFS_KEY) && isa(project[PREFS_KEY], Dict)
            delete!(project[PREFS_KEY], string(uuid))
            open(proj_path, "w") do io
                TOML.print(io, project, sorted=true)
            end
        end
    end
end


"""
    @load_preferences()

Convenience macro to call `load_preferences()` for the current package.
"""
macro load_preferences()
    return quote
        load_preferences($(esc(get_uuid(__module__))))
    end
end


"""
    @save_preferences!(prefs)

Convenience macro to call `save_preferences!()` for the current package.
"""
macro save_preferences!(prefs)
    return quote
        save_preferences!($(esc(get_uuid(__module__))), $(esc(prefs)))
    end
end


"""
    @modify_preferences!(func)

Convenience macro to call `modify_preferences!()` for the current package.
"""
macro modify_preferences!(func)
    return quote
        modify_preferences!($(esc(func)), $(esc(get_uuid(__module__))))
    end
end


"""
    @clear_preferences!()

Convenience macro to call `clear_preferences!()` for the current package.
"""
macro clear_preferences!()
    return quote
        preferences!($(esc(get_uuid(__module__))))
    end
end
