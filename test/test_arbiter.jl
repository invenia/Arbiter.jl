# Tests for the ArbiterTask type.

"""
Ensure that Arbiter is importable from the root module.
"""
facts("imports") do
	@fact isa(ArbiterTask, DataType) --> true
end