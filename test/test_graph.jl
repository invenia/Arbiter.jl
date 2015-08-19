# Tests for the graph module
using Arbiter.ArbiterGraphs

facts("push!") do
    graph = ArbiterGraph()

    @fact nodes(graph) --> ImmutableNodeSet()
    @fact roots(graph) --> ImmutableNodeSet()
    @fact :foo in graph --> false

    push!(graph, :foo)

    @fact nodes(graph) --> ImmutableNodeSet((:foo,))
    @fact roots(graph) --> ImmutableNodeSet((:foo,))
    @fact :foo in graph --> true
    @fact children(graph, :foo) --> ImmutableNodeSet()
    @fact parents(graph, :foo) --> ImmutableNodeSet()
    @fact ancestor_of(graph, :foo, :foo) --> false

    push!(graph, :bar, (:foo, :baz))

    @fact nodes(graph) --> ImmutableNodeSet((:foo, :bar, :baz))
    @fact roots(graph) --> ImmutableNodeSet((:foo,))

    @fact :foo in graph --> true
    @fact :bar in graph --> true
    @fact :baz in graph --> true

    @fact children(graph, :foo) --> ImmutableNodeSet((:bar,))
    @fact children(graph, :bar) --> ImmutableNodeSet()
    @fact children(graph, :baz) --> ImmutableNodeSet((:bar,))

    @fact parents(graph, :foo) --> ImmutableNodeSet()
    @fact parents(graph, :bar) --> ImmutableNodeSet((:foo, :baz))
    @fact parents(graph, :baz) --> ImmutableNodeSet()

    @fact ancestor_of(graph, :foo, :foo) --> false
    @fact ancestor_of(graph, :foo, :bar) --> false
    @fact ancestor_of(graph, :foo, :baz) --> false

    @fact ancestor_of(graph, :bar, :foo) --> true
    @fact ancestor_of(graph, :bar, :bar) --> false
    @fact ancestor_of(graph, :bar, :baz) --> true

    @fact ancestor_of(graph, :baz, :foo) --> false
    @fact ancestor_of(graph, :baz, :bar) --> false
    @fact ancestor_of(graph, :baz, :baz) --> false

    @fact_throws ErrorException push!(graph, :baz, (:bar,))
    @fact_throws ErrorException push!(graph, :ouroboros, (:ouroboros,))
    @fact_throws ErrorException push!(graph, :foo)

    @fact nodes(graph) --> ImmutableNodeSet((:foo, :bar, :baz))
    @fact roots(graph) --> ImmutableNodeSet((:foo,))
end

facts("pop! orphan") do
    graph = ArbiterGraph()

    push!(graph, :node)
    push!(graph, :bar, (:foo,))
    push!(graph, :baz, (:bar,))
    push!(graph, :beta, (:alpha,))
    push!(graph, :bravo, (:alpha,))

    @fact nodes(graph) --> ImmutableNodeSet((:node, :foo, :bar, :baz, :alpha, :beta, :bravo))
    @fact roots(graph) --> ImmutableNodeSet((:node,))

    # node with no children/parents
    @fact pop!(graph, :node; strategy=Orphan) --> NodeSet((:node,))
    @fact nodes(graph) --> ImmutableNodeSet((:foo, :bar, :baz, :alpha, :beta, :bravo))

    # node with child, unique stub parent
    @fact pop!(graph, :bar; strategy=Orphan) --> NodeSet((:bar, :foo))
    @fact nodes(graph) --> ImmutableNodeSet((:baz, :alpha, :beta, :bravo))
    @fact roots(graph) --> ImmutableNodeSet((:baz,))

    # node with non-unique stub parent
    @fact pop!(graph, :bravo; strategy=Orphan) --> NodeSet((:bravo,))
    @fact nodes(graph) --> ImmutableNodeSet((:baz, :alpha, :beta))
    @fact roots(graph) --> ImmutableNodeSet((:baz,))

    # stub
    @fact pop!(graph, :alpha; strategy=Orphan) --> NodeSet((:alpha,))
    @fact nodes(graph) --> ImmutableNodeSet((:baz, :beta))
    @fact roots(graph) --> ImmutableNodeSet((:baz, :beta))

    @fact_throws KeyError pop!(graph, :fake; strategy=Orphan)
end

facts("pop! promote") do
    # promote is the default
    graph = ArbiterGraph()

    push!(graph, :aye)
    push!(graph, :insect)
    push!(graph, :bee, (:aye, :insect))
    push!(graph, :cee, (:bee,))
    push!(graph, :child, (:stub, :stub2))
    push!(graph, :grandchild, (:child,))

    @fact nodes(graph) --> (
        ImmutableNodeSet((:aye, :insect, :bee, :cee, :child, :stub, :stub2, :grandchild))
    )
    @fact roots(graph) --> ImmutableNodeSet((:aye, :insect))

    # two new parents
    @fact pop!(graph, :bee) --> NodeSet((:bee,))
    @fact nodes(graph) --> (
        ImmutableNodeSet((:aye, :insect, :cee, :child, :stub, :stub2, :grandchild))
    )
    @fact roots(graph) --> ImmutableNodeSet((:aye, :insect))
    @fact children(graph, :aye) --> ImmutableNodeSet((:cee,))
    @fact children(graph, :insect) --> ImmutableNodeSet((:cee,))
    @fact parents(graph, :cee) --> ImmutableNodeSet((:aye, :insect))

    # now with stubs
    @fact pop!(graph, :child) --> NodeSet((:child,))
    @fact nodes(graph) --> ImmutableNodeSet((:aye, :insect, :cee, :stub, :stub2, :grandchild))
    @fact roots(graph) --> ImmutableNodeSet((:aye, :insect))
    @fact children(graph, :stub) --> ImmutableNodeSet((:grandchild,))
    @fact children(graph, :stub2) --> ImmutableNodeSet((:grandchild,))
    @fact parents(graph, :grandchild) --> ImmutableNodeSet((:stub, :stub2))

    # delete a stub
    @fact pop!(graph, :stub2) --> NodeSet((:stub2,))
    @fact nodes(graph) --> ImmutableNodeSet((:aye, :insect, :cee, :stub, :grandchild))
    @fact roots(graph) --> ImmutableNodeSet((:aye, :insect))
    @fact children(graph, :stub) --> ImmutableNodeSet((:grandchild,))
    @fact parents(graph, :grandchild) --> ImmutableNodeSet((:stub,))
end

facts("pop! remove") do
    # remove a node (and its children) from a graph
    graph = ArbiterGraph()

    push!(graph, :node)
    push!(graph, :bar, (:foo,))
    push!(graph, :baz, (:bar,))
    push!(graph, :beta, (:alpha,))
    push!(graph, :bravo, (:alpha,))

    @fact nodes(graph) --> ImmutableNodeSet((:node, :foo, :bar, :baz, :alpha, :beta, :bravo))
    @fact roots(graph) --> ImmutableNodeSet((:node,))

    # node with no children/parents
    @fact pop!(graph, :node; strategy=Remove) --> NodeSet((:node,))
    @fact nodes(graph) --> ImmutableNodeSet((:foo, :bar, :baz, :alpha, :beta, :bravo))
    @fact roots(graph) --> ImmutableNodeSet()

    # node with child, unique stub parent
    @fact pop!(graph, :bar; strategy=Remove) --> NodeSet((:bar, :foo, :baz))
    @fact nodes(graph) --> ImmutableNodeSet((:alpha, :beta, :bravo))
    @fact roots(graph) --> ImmutableNodeSet()

    # node with non-unique stub parent
    @fact pop!(graph, :bravo; strategy=Remove) --> NodeSet((:bravo,))
    @fact nodes(graph) --> ImmutableNodeSet((:alpha, :beta))
    @fact roots(graph) --> ImmutableNodeSet()

    # stub
    @fact pop!(graph, :alpha; strategy=Remove) --> NodeSet((:alpha, :beta))
    @fact nodes(graph) --> ImmutableNodeSet()

    @fact_throws KeyError pop!(graph, :fake; strategy=Remove)
end

facts("prune!") do
    # prune a graph
    graph = ArbiterGraph()

    push!(graph, :node)
    push!(graph, :bar, (:foo,))
    push!(graph, :baz, (:bar,))
    push!(graph, :beta, (:alpha,))
    push!(graph, :bravo, (:alpha,))

    @fact nodes(graph) --> ImmutableNodeSet((:node, :foo, :bar, :baz, :alpha, :beta, :bravo))
    @fact roots(graph) --> ImmutableNodeSet((:node,))

    @fact prune!(graph) --> NodeSet((:bar, :baz, :beta, :bravo))
    @fact nodes(graph) --> ImmutableNodeSet((:node,))
    @fact roots(graph) --> ImmutableNodeSet((:node,))

    @fact prune!(graph) --> NodeSet()
    @fact nodes(graph) --> ImmutableNodeSet((:node,))
    @fact roots(graph) --> ImmutableNodeSet((:node,))
end

facts("equality") do
    graph = ArbiterGraph()

    @fact graph == 1 --> false
    @fact graph != 0 --> true

    other = ArbiterGraph()

    @fact graph --> other
    @fact graph != other --> false

    push!(graph, :foo)

    @fact graph --> not(other)
    @fact graph != other --> true

    push!(graph, :bar, (:foo,))
    push!(other, :bar, (:foo,))

    # still shouldn't match graph['foo'] is a stub
    @fact graph --> not(other)
    @fact graph != other --> true

    push!(other, :foo)

    @fact graph --> other
    @fact graph != other --> false
end
