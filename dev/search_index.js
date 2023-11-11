var documenterSearchIndex = {"docs":
[{"location":"license/","page":"License","title":"License","text":"EditURL = \"https://github.com/JuliaPackaging/Preferences.jl/blob/master/LICENSE.md\"","category":"page"},{"location":"license/#License","page":"License","title":"License","text":"","category":"section"},{"location":"license/","page":"License","title":"License","text":"The Preferences.jl package is licensed under the MIT \"Expat\" License:","category":"page"},{"location":"license/","page":"License","title":"License","text":"Copyright (c) 2020: Elliot Saba and contributors.Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.","category":"page"},{"location":"reference/#Reference","page":"Reference","title":"Reference","text":"","category":"section"},{"location":"reference/","page":"Reference","title":"Reference","text":"CurrentModule = Preferences","category":"page"},{"location":"reference/","page":"Reference","title":"Reference","text":"Modules = [Preferences]\nPrivate = false","category":"page"},{"location":"reference/#Preferences.delete_preferences!-Tuple{Base.UUID, Vararg{String, N} where N}","page":"Reference","title":"Preferences.delete_preferences!","text":"delete_preferences!(uuid_or_module, prefs::String...; block_inheritance::Bool = false, export_prefs=false, force=false)\n\nDeletes a series of preferences for the given UUID/Module, identified by the keys passed in as prefs.\n\nSee the docstring for set_preferences!for more details.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Preferences.has_preference-Tuple{Base.UUID, String}","page":"Reference","title":"Preferences.has_preference","text":"has_preference(uuid_or_module, key)\n\nReturn true if the particular preference is found, and false otherwise.\n\nSee the has_preference docstring for more details.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Preferences.load_preference","page":"Reference","title":"Preferences.load_preference","text":"load_preference(uuid_or_module, key, default = nothing)\n\nLoad a particular preference from the Preferences.toml file, shallowly merging keys as it walks the hierarchy of load paths, loading preferences from all environments that list the given UUID as a direct dependency.\n\nMost users should use the @load_preference convenience macro which auto-determines the calling Module.\n\n\n\n\n\n","category":"function"},{"location":"reference/#Preferences.set_preferences!-Tuple{Base.UUID, Vararg{Pair{String, var\"#s2\"} where var\"#s2\", N} where N}","page":"Reference","title":"Preferences.set_preferences!","text":"set_preferences!(uuid_or_module, prefs::Pair{String,Any}...; export_prefs=false,\n                 active_project_only=true, force=false)\n\nSets a series of preferences for the given UUID/Module, identified by the pairs passed in as prefs.  Preferences are loaded from Project.toml and LocalPreferences.toml files on the load path, merging values together into a cohesive view, with preferences taking precedence in LOAD_PATH order, just as package resolution does.  Preferences stored in Project.toml files are considered \"exported\", as they are easily shared across package installs, whereas the LocalPreferences.toml file is meant to represent local preferences that are not typically shared.  LocalPreferences.toml settings override Project.toml settings where appropriate.\n\nAfter running set_preferences!(uuid, \"key\" => value), a future invocation of load_preference(uuid, \"key\") will generally result in value, with the exception of the merging performed by load_preference() due to inheritance of preferences from elements higher up in the load_path().  To control this inheritance, there are two special values that can be passed to set_preferences!(): nothing and missing.\n\nPassing missing as the value causes all mappings of the associated key to be removed from the current level of LocalPreferences.toml settings, allowing preferences set higher in the chain of preferences to pass through.  Use this value when you want to clear your settings but still inherit any higher settings for this key.\nPassing nothing as the value causes all mappings of the associated key to be removed from the current level of LocalPreferences.toml settings and blocks preferences set higher in the chain of preferences from passing through.  Internally, this adds the preference key to a __clear__ list in the LocalPreferences.toml file, that will prevent any preferences from leaking through from higher environments.\n\nNote that the behaviors of missing and nothing are both similar (they both clear the current settings) and diametrically opposed (one allows inheritance of preferences, the other does not).  They can also be composed with a normal set_preferences!() call:\n\n@set_preferences!(\"compiler_options\" => nothing)\n@set_preferences!(\"compiler_options\" => Dict(\"CXXFLAGS\" => \"-g\", LDFLAGS => \"-ljulia\"))\n\nThe above snippet first clears the \"compiler_options\" key of any inheriting influence, then sets a preference option, which guarantees that future loading of that preference will be exactly what was saved here.  If we wanted to re-enable inheritance from higher up in the chain, we could do the same but passing missing first.\n\nThe export_prefs option determines whether the preferences being set should be stored within LocalPreferences.toml or Project.toml.\n\nThe active_project_only flag ensures that the preference is set within the currently active project (as determined by Base.active_project()), and if the target package is not listed as a dependency, it is added under the extras section.  Without this flag set, if the target package is not found in the active project, set_preferences!() will search up the load path for an environment that does contain that module, setting the preference in the first one it finds.  If none are found, it falls back to setting the preference in the active project and adding it as an extra dependency.\n\n\n\n\n\n","category":"method"},{"location":"reference/#Preferences.@delete_preferences!-Tuple","page":"Reference","title":"Preferences.@delete_preferences!","text":"@delete_preferences!(prefs...)\n\nConvenience macro to call delete_preferences!() for the current package.  Defaults to setting force=true, since a package should have full control over itself, but not so for deleting the preferences in other packages, pending private dependencies.\n\n\n\n\n\n","category":"macro"},{"location":"reference/#Preferences.@has_preference-Tuple{Any}","page":"Reference","title":"Preferences.@has_preference","text":"@has_preference(key)\n\nConvenience macro to call has_preference() for the current package.\n\n\n\n\n\n","category":"macro"},{"location":"reference/#Preferences.@load_preference","page":"Reference","title":"Preferences.@load_preference","text":"@load_preference(key)\n\nConvenience macro to call load_preference() for the current package.\n\n\n\n\n\n","category":"macro"},{"location":"reference/#Preferences.@set_preferences!-Tuple","page":"Reference","title":"Preferences.@set_preferences!","text":"@set_preferences!(prefs...)\n\nConvenience macro to call set_preferences!() for the current package.  Defaults to setting force=true, since a package should have full control over itself, but not so for setting the preferences in other packages, pending private dependencies.\n\n\n\n\n\n","category":"macro"},{"location":"","page":"Home","title":"Home","text":"EditURL = \"https://github.com/JuliaPackaging/Preferences.jl/blob/master/README.md\"","category":"page"},{"location":"#Preferences.jl","page":"Home","title":"Preferences.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"(Image: Docs-stable) (Image: Docs-dev) (Image: Continuous Integration) (Image: Code Coverage) (Image: License: MIT)","category":"page"},{"location":"","page":"Home","title":"Home","text":"The Preferences package provides a convenient, integrated way for packages to store configuration switches to persistent TOML files, and use those pieces of information at both run time and compile time in Julia v1.6+. This enables the user to modify the behavior of a package, and have that choice reflected in everything from run time algorithm choice to code generation at compile time. Preferences are stored as TOML dictionaries and are, by default, stored within a (Julia)LocalPreferences.toml file next to the currently-active project. If a preference is \"exported\" (export_prefs=true), it is instead stored within the (Julia)Project.toml. The intention is to allow shared projects to contain shared preferences, while allowing for users themselves to override those preferences with their own settings in the LocalPreferences.toml file, which should be .gitignored as the name implies.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Preferences can be set with depot-wide defaults; if package Foo is installed within your global environment and it has preferences set, these preferences will apply as long as your global environment is part of your LOAD_PATH. Preferences in environments higher up in the environment stack get overridden by the more proximal entries in the load path, ending with the currently active project. This allows depot-wide preference defaults to exist, with active projects able to merge or even completely overwrite these inherited preferences. See the docstring for set_preferences!() for the full details of how to set preferences to allow or disallow merging.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Preferences that are accessed during compilation are automatically marked as compile-time preferences, and any change recorded to these preferences will cause the Julia compiler to recompile any cached precompilation .ji files for that module. This allows preferences to be used to influence code generation. When your package sets a compile-time preference, it is usually best to suggest to the user that they should restart Julia, to allow recompilation to occur.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that the package can be installed on Julia v1.0+ but is only functional on Julia v1.6+.","category":"page"},{"location":"#API","page":"Home","title":"API","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Preferences use is very simple; it is all based around four functions (which each have convenience macros): @set_preferences!(), @load_preference(), @has_preference(), and @delete_preferences!().","category":"page"},{"location":"","page":"Home","title":"Home","text":"@load_preference(key, default = nothing): This loads a preference named key for the current package.  If no such preference is found, it returns default.\n@set_preferences!(pairs...; export_prefs=false): This allows setting multiple preferences at once as pairs.\n@has_preference(key): Returns true if the preference named key is found, and false otherwise.\n@delete_preferences!(keys...): Delete one or more preferences.","category":"page"},{"location":"","page":"Home","title":"Home","text":"To illustrate the usage, we show a toy module, taken directly from this package's tests:","category":"page"},{"location":"","page":"Home","title":"Home","text":"module UsesPreferences\n\nfunction set_backend(new_backend::String)\n    if !(new_backend in (\"OpenCL\", \"CUDA\", \"jlFPGA\"))\n        throw(ArgumentError(\"Invalid backend: \\\"$(new_backend)\\\"\"))\n    end\n\n    # Set it in our runtime values, as well as saving it to disk\n    @set_preferences!(\"backend\" => new_backend)\n    @info(\"New backend set; restart your Julia session for this change to take effect!\")\nend\n\nconst backend = @load_preference(\"backend\", \"OpenCL\")\n\n# An example that helps us to prove that things are happening at compile-time\nfunction do_computation()\n    @static if backend == \"OpenCL\"\n        return \"OpenCL is the best!\"\n    elseif backend == \"CUDA\"\n        return \"CUDA; so fast, so fresh!\"\n    elseif backend == \"jlFPGA\"\n        return \"The Future is Now, jlFPGA online!\"\n    else\n        return nothing\n    end\nend\n\n\n# A non-compiletime preference\nfunction set_username(username::String)\n    @set_preferences!(\"username\" => username)\nend\nfunction get_username()\n    return @load_preference(\"username\")\nend\n\nend # module UsesPreferences","category":"page"},{"location":"#Conditional-Loading","page":"Home","title":"Conditional Loading","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"To use Preferences with Julia 1.6 and later but falling back to a default value for older Julia versions, you can conditionally load Preferences like this:","category":"page"},{"location":"","page":"Home","title":"Home","text":"@static if VERSION >= v\"1.6\"\n    using Preferences\nend\n\n@static if VERSION >= v\"1.6\"\n    preference = @load_preference(\"preference\", \"default\")\nelse\n    preference = \"default\"\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"Note that these cannot be merged into a single @static if. Loading the package with using Preferences must be done on its own.","category":"page"},{"location":"#Authors","page":"Home","title":"Authors","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This repository was initiated by Elliot Saba (@staticfloat) and continues to be maintained by him and other contributors.","category":"page"},{"location":"#License-and-contributing","page":"Home","title":"License and contributing","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Preferences.jl is licensed under the MIT license (see License). Contributions by volunteers are welcome!","category":"page"}]
}
