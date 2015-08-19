# Tests for the Arbiter package

using Arbiter
using FactCheck

include("test_arbiter.jl")
include("test_graph.jl")
include("test_scheduler.jl")
include("test_sync.jl")

FactCheck.exitstatus()
