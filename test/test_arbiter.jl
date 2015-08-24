# Tests for the ArbiterTask type.

facts("imports") do
    # Ensure that Arbiter is importable from the root module.
    @fact isa(ArbiterTask, DataType) --> true
end
