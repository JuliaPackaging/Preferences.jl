module Preferences

"""
    CompileTime

This module provides bindings for setting/getting preferences that can be used at compile
time and will cause your `.ji` file to be invalidated when they are changed.
"""
module CompileTime
const PREFS_KEY = "compile-preferences"
include("common.jl")
end # module CompileTime

# Export `CompileTime` but don't `using` it
export CompileTime

# Second copy of code for non-compiletime preferences
const PREFS_KEY = "preferences"
include("common.jl")

end # module Preferences
