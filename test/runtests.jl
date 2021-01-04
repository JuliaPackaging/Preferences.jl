using Base: UUID
using Preferences, Test, TOML

function activate(f::Function, env_dir::String)
    saved_active_project = Base.ACTIVE_PROJECT[]
    Base.ACTIVE_PROJECT[] = env_dir
    try
        f()
    finally
        Base.ACTIVE_PROJECT[] = saved_active_project
    end
end

function with_temp_depot(f::Function)
    mktempdir() do dir
        saved_depot_path = copy(Base.DEPOT_PATH)
        empty!(Base.DEPOT_PATH)
        push!(Base.DEPOT_PATH, dir)
        try
            f()
        finally
            empty!(Base.DEPOT_PATH)
            append!(Base.DEPOT_PATH, saved_depot_path)
        end
    end
end

function activate_and_run(project_dir::String, code::String; env::Dict = Dict())
    mktempdir() do dir
        open(joinpath(dir, "test_code.jl"), "w") do io
            write(io, code)
        end

        out = Pipe()
        cmd = setenv(`$(Base.julia_cmd()) --project=$(project_dir) $(dir)/test_code.jl`,
                     env..., "JULIA_DEPOT_PATH" => Base.DEPOT_PATH[1])
        p = run(pipeline(cmd, stdout=out, stderr=out); wait=false)
        close(out.in)
        wait(p)
        output = String(read(out))
        if !success(p)
            println(output)
        end
        @test success(p)
        return output
    end
end

# Some useful constants
up_uuid = UUID(TOML.parsefile(joinpath(@__DIR__, "UsesPreferences", "Project.toml"))["uuid"])
up_path = joinpath(@__DIR__, "UsesPreferences")

@testset "Preferences" begin
    # Ensure there is no LocalPreferences.toml file in UsesPreferences:
    local_prefs_toml = joinpath(up_path, "LocalPreferences.toml")
    rm(local_prefs_toml; force=true)
    with_temp_depot() do
        # Start with the default test of the backend being un-set, we just get the default
        activate_and_run(up_path, """
            using UsesPreferences, Test, Preferences
            using Base: UUID
            @test load_preference($(repr(up_uuid)), "backend") === nothing
            @test UsesPreferences.backend == "OpenCL"
        """)

        # Next, change a setting
        activate_and_run(up_path, """
            using UsesPreferences
            UsesPreferences.set_backend("CUDA")
        """)

        # Ensure that's showing up in LocalPreferences.toml:
        prefs = TOML.parsefile(local_prefs_toml)
        @test haskey(prefs, "UsesPreferences")
        @test prefs["UsesPreferences"]["backend"] == "CUDA"

        # Now show that it forces recompilation
        did_precompile(output) = occursin("Precompiling UsesPreferences [$(string(up_uuid))]", output)
        cuda_test = """
        using UsesPreferences, Test
        @test UsesPreferences.backend == "CUDA"
        """
        output = activate_and_run(up_path, cuda_test; env=Dict("JULIA_DEBUG" => "loading"))
        @test did_precompile(output)

        # Show that it does not force a recompile the second time
        output = activate_and_run(up_path, cuda_test; env=Dict("JULIA_DEBUG" => "loading"))
        @test !did_precompile(output)

        # Test non-compiletime preferences a bit
        activate_and_run(up_path, """
            using UsesPreferences, Test, Preferences
            using Base: UUID
            @test load_preference($(repr(up_uuid)), "username") === nothing
            @test !UsesPreferences.has_username()
            @test UsesPreferences.get_username() === nothing
            UsesPreferences.set_username("giordano")
            @test UsesPreferences.get_username() == "giordano"
        """)

        # This does not cause a recompilation, and we can also get the username back again:
        username_test = """
        using UsesPreferences, Test, Preferences
        @test UsesPreferences.get_username() == "giordano"
        """
        output = activate_and_run(up_path, username_test; env=Dict("JULIA_DEBUG" => "loading"))
        @test !did_precompile(output)

        _prefs_delete_username = "delete_preferences!($(repr(up_uuid)), \"username\"; block_inheritance = false)"
        _delete_username = "UsesPreferences.delete_username()"
        _has_username = "@test UsesPreferences.has_username()"
        _doesnt_have_username = "!@test UsesPreferences.has_username()"
        _set_username = "UsesPreferences.set_username(\"giordano\")"
        _get_username = "@test UsesPreferences.get_username() == \"giordano\""
        _doesnt_have_set_get_username = """
        $(_doesnt_have_username)
        $(_set_username)
        $(_get_username)
        """
        snippets = [
            _prefs_delete_username,
            _doesnt_have_set_get_username,
            _has_username,
            _delete_username,
            _doesnt_have_set_get_username,
            _has_username,
            _prefs_delete_username,
            _doesnt_have_set_get_username,
            _has_username,
            _prefs_delete_username,
            _doesnt_have_set_get_username,
            _has_username,
        ]
        for snippet in snippets
            code = """
            using UsesPreferences, Test, Preferences
            using Base: UUID

            $(snippet)
            """
            output = activate_and_run(up_path, username_test; env=Dict("JULIA_DEBUG" => "loading"))
            @test !did_precompile(output)
        end
    end
end

# Load UsesPreferences, as we need it loaded for some set/get trickery below
activate(up_path) do
    eval(:(using UsesPreferences))
end
@testset "Inheritance" begin
    # Ensure there is no LocalPreferences.toml file in UsesPreferences:
    local_prefs_toml = joinpath(up_path, "LocalPreferences.toml")
    rm(local_prefs_toml; force=true)
    with_temp_depot() do
        mktempdir() do env_dir
            # We're going to create a higher environment
            push!(Base.LOAD_PATH, env_dir)

            # We're going to add `UsesPreferences` to this environment
            open(joinpath(env_dir, "Project.toml"), "w") do io
                TOML.print(io, Dict(
                    "deps" => Dict(
                        "UsesPreferences" => string(up_uuid),
                    )
                ))
            end

            # We're going to write out some Preferences for UP in the higher environment
            activate(env_dir) do
                set_preferences!(up_uuid, "location" => "outer_public"; export_prefs=true)
                # Verify that this is stored in the environment's Project.toml file
                proj = Base.parsed_toml(joinpath(env_dir, "Project.toml"))
                @test haskey(proj, "preferences")
                @test haskey(proj["preferences"], "UsesPreferences")
                @test proj["preferences"]["UsesPreferences"]["location"] == "outer_public"
                @test load_preference(up_uuid, "location") == "outer_public"

                # Add preferences to the outer env's `LocalPreferences.toml`
                set_preferences!(up_uuid, "location" => "outer_local")
                prefs = Base.parsed_toml(joinpath(env_dir, "LocalPreferences.toml"))
                @test haskey(prefs, "UsesPreferences")
                @test prefs["UsesPreferences"]["location"] == "outer_local"
                @test load_preference(up_uuid, "location") == "outer_local"
            end

            # Ensure that we can load the preferences the same even if we exit the `activate()`
            @test load_preference(up_uuid, "location") == "outer_local"

            # Next, we're going to create a lower environment, add some preferences there, and ensure
            # the inheritance works properly.
            activate(up_path) do
                # Ensure that activating this other path doesn't change anything
                @test load_preference(up_uuid, "location") == "outer_local"

                # Set a local preference in this location, which should be the first location on the load path
                set_preferences!(up_uuid, "location" => "inner_local")
                prefs = Base.parsed_toml(joinpath(up_path, "LocalPreferences.toml"))
                @test haskey(prefs, "UsesPreferences")
                @test prefs["UsesPreferences"]["location"] == "inner_local"
                @test load_preference(up_uuid, "location") == "inner_local"
            end

            # Let's add some complex objects, test that recursive merging works, and that
            # the special meaning of `nothing` and `missing` works
            activate(env_dir) do
                set_preferences!(up_uuid, "nested" => Dict(
                    "nested2" => Dict("a" => 1, "b" => 2),
                    "leaf" => "hello",
                ); export_prefs=true)
                set_preferences!(up_uuid, "nested" => Dict(
                    "nested2" => Dict("b" => 3)),
                )

                nested = load_preference(up_uuid, "nested")
                @test isa(nested, Dict) && haskey(nested, "nested2")
                @test nested["nested2"]["a"] == 1
                @test nested["nested2"]["b"] == 3
                @test nested["leaf"] == "hello"
            end

            # Add another layer in the inner environment
            activate(up_path) do
                set_preferences!(up_uuid, "nested" => Dict(
                    "nested2" => Dict("a" => "foo"),
                    "leaf" => "world",
                ))
                nested = load_preference(up_uuid, "nested")
                @test isa(nested, Dict) && haskey(nested, "nested2")
                @test nested["nested2"]["a"] == "foo"
                @test nested["nested2"]["b"] == 3
                @test nested["leaf"] == "world"
            end

            # Set the local setting of the upper environment to `missing`; this causes it to
            # pass through and `b` will suddenly equal `2`:
            activate(env_dir) do
                # Test that trying to over-set a preference in another package fails unless we force it
                @test_throws ArgumentError set_preferences!(up_uuid, "nested" => nothing)
                set_preferences!(up_uuid, "nested" => Dict(
                    "nested2" => missing,
                    "leaf" => nothing,
                ); force=true)
                nested = load_preference(up_uuid, "nested")
                @test isa(nested, Dict) && haskey(nested, "nested2")
                @test nested["nested2"]["a"] == 1
                @test nested["nested2"]["b"] == 2

                # Let's check that the `__clear__` keys are what we expect:
                prefs = Base.parsed_toml(joinpath(env_dir, "LocalPreferences.toml"))
                @test prefs["UsesPreferences"]["nested"]["__clear__"] == ["leaf"]
                @test !haskey(prefs["UsesPreferences"]["nested"], "leaf")
                @test !haskey(nested, "leaf")
            end

            # Show that it cascades down to the lower levels as well
            activate(up_path) do
                nested = load_preference(up_uuid, "nested")
                @test isa(nested, Dict) && haskey(nested, "nested2")
                @test nested["nested2"]["a"] == "foo"
                @test nested["nested2"]["b"] == 2
                @test nested["leaf"] == "world"
            end
        end
    end
end
