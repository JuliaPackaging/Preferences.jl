using Base: UUID
using Preferences, Test, TOML, Pkg

function activate(f::Function, project::String)
    saved_active_project = Base.ACTIVE_PROJECT[]
    Base.ACTIVE_PROJECT[] = project
    try
        f()
    finally
        Base.ACTIVE_PROJECT[] = saved_active_project
    end
end

function with_temp_project(f::Function)
    mktempdir() do dir
        activate(dir) do
            f(dir)
        end
    end
end

function with_temp_depot_and_project(f::Function)
    mktempdir() do dir
        saved_depot_path = copy(Base.DEPOT_PATH)
        empty!(Base.DEPOT_PATH)
        push!(Base.DEPOT_PATH, dir)
        try
            with_temp_project(f)
        finally
            empty!(Base.DEPOT_PATH)
            append!(Base.DEPOT_PATH, saved_depot_path)
        end
    end
end

# Some useful constants
up_uuid = UUID(TOML.parsefile(joinpath(@__DIR__, "UsesPreferences", "Project.toml"))["uuid"])
up_path = joinpath(@__DIR__, "UsesPreferences")

@testset "Preferences" begin
    # Create a temporary package, store some preferences within it.
    with_temp_project() do project_dir
        Pkg.develop(path=up_path)
        @test isempty(load_preferences(up_uuid))
        modify_preferences!(up_uuid) do prefs
            prefs["foo"] = "bar"
            prefs["baz"] = Dict("qux" => "spoon")
        end

        prefs = load_preferences(up_uuid)
        run(`cat $(project_dir)/Project.toml`)
        @test haskey(prefs, "foo")
        @test prefs["foo"] == "bar"
        @test prefs["baz"]["qux"] == "spoon"

        project_path = joinpath(project_dir, "Project.toml")
        @test isfile(project_path)
        proj = TOML.parsefile(project_path)
        @test haskey(proj, "preferences")
        @test isa(proj["preferences"], Dict)
        @test haskey(proj["preferences"], string(up_uuid))
        @test isa(proj["preferences"][string(up_uuid)], Dict)
        @test proj["preferences"][string(up_uuid)]["foo"] == "bar"
        @test isa(proj["preferences"][string(up_uuid)]["baz"], Dict)
        @test proj["preferences"][string(up_uuid)]["baz"]["qux"] == "spoon"

        clear_preferences!(up_uuid)
        proj = TOML.parsefile(project_path)
        @test !haskey(proj, "preferences")
        @test isempty(load_preferences(up_uuid))
    end
end

@testset "CompileTime" begin
    # Create a temporary package, store some preferences within it.
    with_temp_project() do project_dir
        # Add UsesPreferences as a package to this project so that the preferences are visible
        Pkg.develop(path=up_path)
        CompileTime.save_preferences!(up_uuid, Dict("foo" => "bar"))

        project_path = joinpath(project_dir, "Project.toml")
        @test isfile(project_path)
        proj = TOML.parsefile(project_path)
        @test haskey(proj, "compile-preferences")
        @test isa(proj["compile-preferences"], Dict)
        @test haskey(proj["compile-preferences"], string(up_uuid))
        @test isa(proj["compile-preferences"][string(up_uuid)], Dict)
        @test proj["compile-preferences"][string(up_uuid)]["foo"] == "bar"

        prefs = CompileTime.modify_preferences!(up_uuid) do prefs
            prefs["foo"] = "baz"
            prefs["spoon"] = [Dict("qux" => "idk")]
        end
        @test prefs == CompileTime.load_preferences(up_uuid)

        CompileTime.clear_preferences!(up_uuid)
        proj = TOML.parsefile(project_path)
        @test !haskey(proj, "compile-preferences")
    end

    # Do a test with stacked environments
    mktempdir() do outer_env
        # Set preferences for the package within the outer env
        activate(outer_env) do
            CompileTime.save_preferences!(up_uuid, Dict("foo" => "outer"))
        end

        OLD_LOAD_PATH = deepcopy(Base.LOAD_PATH)
        try
            empty!(Base.LOAD_PATH)
            append!(Base.LOAD_PATH, ["@", outer_env, "@stdlib"])

            with_temp_project() do project_dir
                CompileTime.save_preferences!(up_uuid, Dict("foo" => "inner"))

                # Ensure that an initial load finds none of these, since the Package is not added anywhere:
                @test isempty(CompileTime.load_preferences(up_uuid))

                # add it to the inner project, ensure that we get "inner" as the "foo" value:
                Pkg.develop(path=up_path)
                prefs = CompileTime.load_preferences(up_uuid)
                @test haskey(prefs, "foo")
                @test prefs["foo"] == "inner"

                # Remove it from the inner project, add it to the outer project, ensure we get "outer"
                Pkg.rm("UsesPreferences")
                activate(outer_env) do
                    Pkg.develop(path=up_path)
                end
                prefs = CompileTime.load_preferences(up_uuid)
                @test haskey(prefs, "foo")
                @test prefs["foo"] == "outer"
            end
        finally
            empty!(Base.LOAD_PATH)
            append!(Base.LOAD_PATH, OLD_LOAD_PATH)
        end
    end

    # Do a test within a package to ensure that we can use the macros
    with_temp_project() do project_dir
        Pkg.develop(path=up_path)

        # Run UsesPreferences tests manually, so that they can run in the explicitly-given project
        test_script = joinpath(@__DIR__, "UsesPreferences", "test", "runtests.jl")
        run(`$(Base.julia_cmd()) --project=$(project_dir) $(test_script)`)

        # Load the preferences, ensure we see the `jlFPGA` backend:
        prefs = CompileTime.load_preferences(up_uuid)
        @test haskey(prefs, "backend")
        @test prefs["backend"] == "jlFPGA"
    end

    # Run another test, this time setting up a whole new depot so that compilation caching can be checked:
    with_temp_depot_and_project() do project_dir
        Pkg.develop(path=up_path)

        # Helper function to run a sub-julia process and ensure that it either does or does not precompile.
        function did_precompile()
            out = Pipe()
            cmd = setenv(`$(Base.julia_cmd()) -i --project=$(project_dir) -e 'using UsesPreferences; exit(0)'`, "JULIA_DEPOT_PATH" => Base.DEPOT_PATH[1], "JULIA_DEBUG" => "loading")
            run(pipeline(cmd, stdout=out, stderr=out))
            close(out.in)
            output = String(read(out))
            return occursin("Precompiling UsesPreferences [$(string(up_uuid))]", output)
        end

        # Initially, we must precompile, of course, because no preferences are set.
        @test did_precompile()
        # Next, we recompile, because the preferences have been altered
        @test did_precompile()
        # Finally, we no longer have to recompile.
        @test !did_precompile()

        # Modify the preferences, ensure that causes precompilation and then that too shall pass.
        prefs = CompileTime.modify_preferences!(up_uuid) do prefs
            prefs["backend"] = "something new"
        end
        @test did_precompile()
        @test !did_precompile()

        # Finally, switch it back, and ensure that this does not cause precompilation
        prefs = CompileTime.modify_preferences!(up_uuid) do prefs
            prefs["backend"] = "OpenCL"
        end
        @test !did_precompile()
    end
end
