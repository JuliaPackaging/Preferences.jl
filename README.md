# Preferences

[![Continuous Integration][ci-img]][ci-url]
[![Code Coverage][codecov-img]][codecov-url]

[ci-url]:               https://github.com/JuliaPackaging/Preferences.jl/actions?query=workflow%3ACI
[codecov-url]:          https://codecov.io/gh/JuliaPackaging/Preferences.jl

[ci-img]:               https://github.com/JuliaPackaging/Preferences.jl/workflows/CI/badge.svg                     "Continuous Integration"
[codecov-img]:          https://codecov.io/gh/JuliaPackaging/Preferences.jl/branch/master/graph/badge.svg           "Code Coverage"

The `Preferences` package provides a convenient, integrated way for packages to store configuration switches to persistent TOML files, and use those pieces of information at both run time and compile time in Julia v1.6+.
This enables the user to modify the behavior of a package, and have that choice reflected in everything from run time algorithm choice to code generation at compile time.

Note that the package can be installed on Julia v1.0+ but is only functional on Julia v1.6+.

## Project-specific vs package-wide preferences

Preferences are stored as TOML dictionaries and are, by default, stored within a `(Julia)LocalPreferences.toml` file next to the currently-active project. This results in *project-specific*
preferences, meaning that different projects making use of the same package can set up
different, non-conflicting preferences.

Preferences can be set with depot-wide defaults; if package `Foo` is installed within your global environment and it has preferences set, these preferences will apply as long as your global environment is part of your [`LOAD_PATH`](https://docs.julialang.org/en/v1/manual/code-loading/#Environment-stacks).
Preferences in environments higher up in the environment stack get overridden by the more proximal entries in the load path, ending with the currently active project.
This allows depot-wide preference defaults to exist, with active projects able to merge or even completely overwrite these inherited preferences.
See the docstring for `set_preferences!()` for the full details of how to set preferences to allow or disallow merging.

In contrast, *package-wide* preferences are stored within within the package's own `(Julia)Project.toml` file. Such preferences apply to all users of the package, regardless of the active project.

You can control which kind of preference you create; this is discussed in the API subsections below.

## Run-time vs compile-time preferences

Preferences that are accessed during compilation are automatically marked as compile-time preferences, and any change recorded to these preferences will cause the Julia compiler to recompile any cached precompilation `.ji` files for that module.
This allows preferences to be used to influence code generation.
When your package sets a compile-time preference, it is usually best to suggest to the user that they should restart Julia, to allow recompilation to occur.

If you call `load_preference` (or its macro variant `@load_preference`) from "top-level" in the package,
this is a compile-time preference. Otherwise (e.g., if it is "buried" inside a function, and that
function doesn't get executed at top-level), it is a run-time preference. See examples in the first API section below.

## API: Project-specific preferences

Preferences use is very simple; it is all based around four functions (which each have convenience macros): `@set_preferences!()`, `@load_preference()`, `@has_preference()`, and `@delete_preferences!()`.

* `@load_preference(key, default = nothing)`: This loads a preference named `key` for the current package.  If no such preference is found, it returns `default`.

* `@set_preferences!(pairs...)`: This allows setting multiple preferences at once as pairs.

* `@has_preference(key)`: Returns true if the preference named `key` is found, and `false` otherwise.

* `@delete_preferences!(keys...)`: Delete one or more preferences.

To illustrate the usage, we show a toy module, taken directly from this package's tests:

```julia
module UsesPreferences

function set_backend(new_backend::String)
    if !(new_backend in ("OpenCL", "CUDA", "jlFPGA"))
        throw(ArgumentError("Invalid backend: \"$(new_backend)\""))
    end

    # Set it in our runtime values, as well as saving it to disk
    @set_preferences!("backend" => new_backend)
    @info("New backend set; restart your Julia session for this change to take effect!")
end

const backend = @load_preference("backend", "OpenCL")

# An example that helps us to prove that things are happening at compile-time
function do_computation()
    @static if backend == "OpenCL"
        return "OpenCL is the best!"
    elseif backend == "CUDA"
        return "CUDA; so fast, so fresh!"
    elseif backend == "jlFPGA"
        return "The Future is Now, jlFPGA online!"
    else
        return nothing
    end
end


# A non-compiletime preference
# These can change dynamically, and no Julia restart is needed.
function set_username(username::String)
    @set_preferences!("username" => username)
end
function get_username()
    return @load_preference("username")
end

end # module UsesPreferences
```

With the macros, all preferences are project-specific.

## API: package-wide preferences

To set preferences for *all* users of a package (across many different projects), use the functional form

```julia
set_preferences!(module, prefs...; export_prefs=true)
```

To use this approach, the example above might become

```julia
module AlsoUsesPreferences

function set_backend(new_backend::String)
    if !(new_backend in ("OpenCL", "CUDA", "jlFPGA"))
        throw(ArgumentError("Invalid backend: \"$(new_backend)\""))
    end

    # Set it in our runtime values, as well as saving it to disk
    # Export it for all users of the package (export_prefs=true):
    set_preferences!(@__MODULE__, "backend" => new_backend; export_prefs=true)
    @info("New backend set; restart your Julia session for this change to take effect!")
end

⋮

end
```

You can use the explicit module name, `AlsoUsesPreferences`, as the first argument to `set_preferences!`, but consider using `@__MODULE__` instead, as it continues to work even if you decide to rename your package.

You can set preferences for another, unloaded package, using the package `UUID` in place of the module.

## Conditional Loading

To use `Preferences` with Julia 1.6 and later but falling back to a
default value for older Julia versions, you can conditionally load
`Preferences` like this:
```
@static if VERSION >= v"1.6"
    using Preferences
end

@static if VERSION >= v"1.6"
    preference = @load_preference("preference", "default")
else
    preference = "default"
end
```
Note that these cannot be merged into a single `@static if`. Loading
the package with `using Preferences` must be done on its own.
