using Test, PTest, Preferences

uuid = Base.UUID("8789f892-390a-4776-818f-b9c2b248add9")
set_preferences!(uuid, "set_by_runtests" => "This was set by runtests.jl")
PTest.do_test()
