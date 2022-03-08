module Preferences

if VERSION < v"1.6.0-DEV"
    error("Preferences.jl can only be used on Julia v1.6+!")
end

using TOML
using Base: UUID, TOMLCache

export load_preference, @load_preference,
       has_preference, @has_preference,
       set_preferences!, @set_preferences!,
       delete_preferences!, @delete_preferences!

include("utils.jl")

"""
    load_preference(uuid_or_module, key, default = nothing)

Load a particular preference from the `Preferences.toml` file, shallowly merging keys
as it walks the hierarchy of load paths, loading preferences from all environments that
list the given UUID as a direct dependency.

Most users should use the `@load_preference` convenience macro which auto-determines the
calling `Module`.
"""
function load_preference(uuid::UUID, key::String, default = nothing)
    # Re-use definition in `base/loading.jl` so as to not repeat code.
    d = Base.get_preferences(uuid)
    if currently_compiling()
        Base.record_compiletime_preference(uuid, key)
    end
    return drop_clears(get(d, key, default))
end
function load_preference(m::Module, key::String, default = nothing)
    return load_preference(get_uuid(m), key, default)
end

"""
    @load_preference(key)

Convenience macro to call `load_preference()` for the current package.
"""
macro load_preference(key, default = nothing)
    return quote
        load_preference($(esc(get_uuid(__module__))), $(esc(key)), $(esc(default)))
    end
end

"""
    has_preference(uuid_or_module, key)

Return `true` if the particular preference is found, and `false` otherwise.

See the `has_preference` docstring for more details.
"""
function has_preference(uuid::UUID, key::String)
    value = load_preference(uuid, key, nothing)
    return !(value isa Nothing)
end
function has_preference(m::Module, key::String)
    return has_preference(get_uuid(m), key)
end

"""
    @has_preference(key)

Convenience macro to call `has_preference()` for the current package.
"""
macro has_preference(key)
    return quote
        has_preference($(esc(get_uuid(__module__))), $(esc(key)))
    end
end

"""
    process_sentinel_values!(prefs::Dict)

Recursively search for preference values that end in `nothing` or `missing` leaves,
which we handle specially, see the `set_preferences!()` docstring for more detail.
"""
function process_sentinel_values!(prefs::Dict)
    # Need to widen `prefs` so that when we try to assign to `__clear__` below,
    # we don't error due to a too-narrow type on `prefs`
    prefs = Base._typeddict(prefs, Dict{String,Vector{String}}())

    clear_keys = get(prefs, "__clear__", String[])
    for k in collect(keys(prefs))
        if prefs[k] === nothing
            # If this should add `k` to the `__clear__` list, do so, then remove `k`
            push!(clear_keys, k)
            delete!(prefs, k)
        else
            # `k` is not nothing, so drop it from `clear_keys`
            filter!(x -> x != k, clear_keys)
            if prefs[k] === missing
                # If this should clear out the mapping for `k`, do so
                delete!(prefs, k)
            elseif isa(prefs[k], Dict)
                # Recurse for nested dictionaries
                prefs[k] = process_sentinel_values!(prefs[k])
            end
        end
    end
    # Store the updated list of clear_keys
    if !isempty(clear_keys)
        prefs["__clear__"] = collect(Set(clear_keys))
    else
        delete!(prefs, "__clear__")
    end
    return prefs
end

# See the `set_preferences!()` docstring below for more details
function set_preferences!(target_toml::String, pkg_name::String, pairs::Pair{String,<:Any}...; force::Bool = false)
    # Load the old preferences in first, as we'll merge ours into whatever currently exists
    d = Dict{String,Any}()
    if isfile(target_toml)
        d = Base.parsed_toml(target_toml)
    end
    prefs = d
    if endswith(target_toml, "Project.toml")
        if !haskey(prefs, "preferences")
            prefs["preferences"] = Dict{String,Any}()
        end
        # If this is a `(Julia)Project.toml` file, we squirrel everything away under the
        # "preferences" key, while for a `Preferences.toml` file it sits at top-level.
        prefs = prefs["preferences"]
    end
    # Index into our package name
    if !haskey(prefs, pkg_name)
        prefs[pkg_name] = Dict{String,Any}()
    end
    # Set each preference, erroring unless `force` is set to `true`
    for (k, v) in pairs
        if !force && haskey(prefs[pkg_name], k) && (v === missing || prefs[pkg_name][k] != v)
            throw(ArgumentError("Cannot set preference '$(k)' to '$(v)' for $(pkg_name) in $(target_toml): preference already set to '$(prefs[pkg_name][k])'!"))
        end
        prefs[pkg_name][k] = v

        # Recursively scan for `nothing` and `missing` values that we need to handle specially
        prefs[pkg_name] = process_sentinel_values!(prefs[pkg_name])
    end
    open(target_toml, "w") do io
        TOML.print(io, d, sorted=true)
    end
    return nothing
end

"""
    set_preferences!(uuid_or_module, prefs::Pair{String,Any}...; export_prefs=false, force=false)

Sets a series of preferences for the given UUID/Module, identified by the pairs passed in
as `prefs`.  Preferences are loaded from `Project.toml` and `LocalPreferences.toml` files
on the load path, merging values together into a cohesive view, with preferences taking
precedence in `LOAD_PATH` order, just as package resolution does.  Preferences stored in
`Project.toml` files are considered "exported", as they are easily shared across package
installs, whereas the `LocalPreferences.toml` file is meant to represent local
preferences that are not typically shared.  `LocalPreferences.toml` settings override
`Project.toml` settings where appropriate.

After running `set_preferences!(uuid, "key" => value)`, a future invocation of
`load_preference(uuid, "key")` will generally result in `value`, with the exception of
the merging performed by `load_preference()` due to inheritance of preferences from
elements higher up in the `load_path()`.  To control this inheritance, there are two
special values that can be passed to `set_preferences!()`: `nothing` and `missing`.

* Passing `missing` as the value causes all mappings of the associated key to be removed
  from the current level of `LocalPreferences.toml` settings, allowing preferences set
  higher in the chain of preferences to pass through.  Use this value when you want to
  clear your settings but still inherit any higher settings for this key.

* Passing `nothing` as the value causes all mappings of the associated key to be removed
  from the current level of `LocalPreferences.toml` settings and blocks preferences set
  higher in the chain of preferences from passing through.  Internally, this adds the
  preference key to a `__clear__` list in the `LocalPreferences.toml` file, that will
  prevent any preferences from leaking through from higher environments.

Note that the behavior of `missing` and `nothing` is both similar (they both clear the
current settings) and diametrically opposed (one allows inheritance of preferences, the
other does not).  They can also be composed with a normal `set_preferences!()` call:

```julia
@set_preferences!("compiler_options" => nothing)
@set_preferences!("compiler_options" => Dict("CXXFLAGS" => "-g", LDFLAGS => "-ljulia"))
```

The above snippet first clears the `"compiler_options"` key of any inheriting influence,
then sets a preference option, which guarantees that future loading of that preference
will be exactly what was saved here.  If we wanted to re-enable inheritance from higher
up in the chain, we could do the same but passing `missing` first.

The `export_prefs` option determines whether the preferences being set should be stored
within `LocalPreferences.toml` or `Project.toml`.
"""
function set_preferences!(u::UUID, prefs::Pair{String,<:Any}...; export_prefs=false, kwargs...)
    # Find the first `Project.toml` that has this UUID as a direct dependency
    project_toml, pkg_name = find_first_project_with_uuid(u)
    if project_toml === nothing && pkg_name === nothing
        # If we couldn't find one, we're going to use `active_project()`
        project_toml = Base.active_project()

        # And we're going to need to add this UUID as an "extras" dependency:
        # We're going to assume you want to name this this dependency in the
        # same way as it's been loaded:
        pkg_uuid_matches = filter(d -> d.uuid == u, keys(Base.loaded_modules))
        if isempty(pkg_uuid_matches)
            error("Cannot set preferences of an unknown package that is not loaded!")
        end
        pkg_name = first(pkg_uuid_matches).name

        # Read in the project, add the deps, write it back out!
        project = Base.parsed_toml(project_toml)
        if !haskey(project, "extras")
            project["extras"] = Dict{String,Any}()
        end
        project["extras"][pkg_name] = string(u)
        open(project_toml, "w") do io
            TOML.print(io, project; sorted=true)
        end
    end

    # Finally, save the preferences out to either `Project.toml` or
    # `(Julia)LocalPreferences.toml` keyed under that `pkg_name`:
    target_toml = project_toml
    if !export_prefs
        # We'll default to calling it `LocalPreferneces.toml`
        target_toml = joinpath(dirname(project_toml), "LocalPreferences.toml")

        # But if there's already a `JuliaLocalPreferneces.toml`, use that.
        for pref_name in Base.preferences_names
            maybe_file = joinpath(dirname(project_toml), pref_name)
            if isfile(maybe_file)
                target_toml = maybe_file
            end
        end
    end
    return set_preferences!(target_toml, pkg_name, prefs...; kwargs...)
end
function set_preferences!(m::Module, prefs::Pair{String,<:Any}...; kwargs...)
    return set_preferences!(get_uuid(m), prefs...; kwargs...)
end

"""
    @set_preferences!(prefs...)

Convenience macro to call `set_preferences!()` for the current package.  Defaults to
setting `force=true`, since a package should have full control over itself, but not
so for setting the preferences in other packages, pending private dependencies.
"""
macro set_preferences!(prefs...)
    return quote
        set_preferences!($(esc(get_uuid(__module__))), $(map(esc,prefs)...), force=true)
    end
end

"""
    delete_preferences!(uuid_or_module, prefs::String...; block_inheritance::Bool = false, export_prefs=false, force=false)

Deletes a series of preferences for the given UUID/Module, identified by the
keys passed in as `prefs`.


See the docstring for `set_preferences!`for more details.
"""
function delete_preferences!(u::UUID, pref_keys::String...; block_inheritance::Bool = false, kwargs...)
    if block_inheritance
        return set_preferences!(u::UUID, [k => nothing for k in pref_keys]...; kwargs...)
    else
        return set_preferences!(u::UUID, [k => missing for k in pref_keys]...; kwargs...)
    end
end
function delete_preferences!(m::Module, pref_keys::String...; kwargs...)
    return delete_preferences!(get_uuid(m), pref_keys...; kwargs...)
end

"""
    @delete_preferences!(prefs...)

Convenience macro to call `delete_preferences!()` for the current package.  Defaults to
setting `force=true`, since a package should have full control over itself, but not
so for deleting the preferences in other packages, pending private dependencies.
"""
macro delete_preferences!(prefs...)
    return quote
        delete_preferences!($(esc(get_uuid(__module__))), $(map(esc,prefs)...), force=true)
    end
end

# Precompilation to reduce latency (https://github.com/JuliaLang/julia/pull/43990#issuecomment-1025692379)
get_uuid(Preferences)
currently_compiling()
precompile(Tuple{typeof(drop_clears), Any})
if hasmethod(Base.BinaryPlatforms.Platform, (String, String, Dict{String}))
    precompile(load_preference, (Base.UUID, String, Nothing))
end

end # module Preferences
