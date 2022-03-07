module PTest

using Test, Preferences

function do_test()
    @set_preferences!("dynamic" => "Local preference set just now")
    @test @load_preference("dynamic", default = nothing) == "Local preference set just now"

    set_preferences!(@__MODULE__, "dynamic_exported" => "Local preference just exported"; export_prefs = true)
    @test @load_preference("dynamic_exported", default = nothing) == "Local preference just exported"

    @test @load_preference("pkg_copied_exported", default = nothing) == "Exported preference copied over by Pkg.jl"
    @test @load_preference("pkg_copied", default = nothing) == "Local preference copied over by Pkg.jl"
    @test @load_preference("set_by_runtests", default = nothing) == "This was set by runtests.jl"
end

end # module PTest
