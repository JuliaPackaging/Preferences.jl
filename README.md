# Preferences

`Preferences` supports embedding a simple `Dict` of metadata for a package on a per-project basis.
These preferences allow for packages to set simple, persistent pieces of data, and optionally trigger recompilation of the package when the preferences change, to allow for customization of package behavior at compile-time.

## API Overview

`Preferences` are used primarily through the `@load_preferences`, `@save_preferences` and `@modify_preferences` macros.
These macros will auto-detect the UUID of the calling package, throwing an error if the calling module does not belong to a package.
The function forms can be used to load, save or modify preferences belonging to another package.

Example usage:

```julia
using Preferences

function get_preferred_backend()
    prefs = @load_preferences()
    return get(prefs, "backend", "native")
end

function set_backend(new_backend)
    @modify_preferences!() do prefs
        prefs["backend"] = new_backend
    end
end
```

Preferences are stored within the first `Project.toml` that represents an environment that contains the given UUID, even as a transitive dependency.
If no project that contains the given UUID is found, the preference is recorded in the `Project.toml` file of the currently-active project.
The initial state for preferences is an empty dictionary, package authors that wish to have a default value set for their preferences should use the `get(prefs, key, default)` pattern as shown in the code example above.

## Compile-Time Preferences

If a preference must be known at compile-time, (and hence changing it should invalidate your package's precompiled `.ji` file) access of it should be done through the `Preferences.CompileTime` module.
The exact same API is exposed, but the preferences will be stored within a separate dictionary from normal `Preferences`, and any change made to these preferences will cause your package to be recompiled the next time it is loaded.
Packages that wish to use purely compile-time preferences can simply `using Preferences.CompileTime`, mixed usage will require compile-time usage to access functions and macros via `CompileTime.@load_preferences()`, etc...
