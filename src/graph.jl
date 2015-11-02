# An implementation for an acyclic directed graph.

module ArbiterGraphs

export ArbiterGraph, nodes, roots, children, parents, ancestor_of, prune!
export Strategy, Orphan, Promote, Remove
export NodeSet, ImmutableNodeSet

import Base: push!, pop!, in, ==
import FunctionalCollections: PersistentSet
import DataStructures: Stack

typealias NodeSet Set{Symbol}
typealias ImmutableNodeSet PersistentSet{Symbol}
typealias AbstractNodeSet Union{NodeSet, ImmutableNodeSet}

immutable Node{T<:AbstractNodeSet}
    name::Symbol
    children::NodeSet
    parents::T
end

function Node(name::Symbol, children::NodeSet)
    Node(name, children, ImmutableNodeSet())
end

function ==(node1::Node, node2::Node)
    return node1.name === node2.name && node1.children == node2.children && node1.parents == node2.parents
end

@enum Strategy Orphan Promote Remove

immutable ArbiterGraph
    _nodes::Dict{Symbol,Node}
    _stubs::NodeSet
    _roots::NodeSet

    """
    An acyclic directed graph.
    """
    function ArbiterGraph()
        new(Dict{Symbol,Node}(), NodeSet(), NodeSet())
    end
end

"""
The set of nodes in the graph.
"""
nodes(graph::ArbiterGraph) = ImmutableNodeSet(keys(graph._nodes))

"""
The set of nodes in the graph which have no parents.
"""
roots(graph::ArbiterGraph) = ImmutableNodeSet(graph._roots)

"""
Get the set of children a node has.

name: The name of the node.

An exception will be raised if the node doesn't exist.
"""
children(graph::ArbiterGraph, name::Symbol) = ImmutableNodeSet(graph._nodes[name].children)

"""
Get the set of parents a node has.

name: The name of the node.

An exception will be raised if the node doesn't exist.
"""
parents(graph::ArbiterGraph, name::Symbol) = ImmutableNodeSet(graph._nodes[name].parents)

"""
Check whether a node has another node as an ancestor.

name: The name of the node being checked.
ancestor: The name of the (possible) ancestor node.
visited: (optional, None) If given, a set of nodes that have
    already been traversed. NOTE: The set will be updated with
    any new nodes that are visited.

NOTE: If node doesn't exist, the method will return False.
"""
function ancestor_of(graph::ArbiterGraph, name::Symbol, ancestor::Symbol, visited::NodeSet)
    if !haskey(graph._nodes, name)
        return false
    end

    node = graph._nodes[name]

    stack = Stack(Symbol)

    # Note: append! is not available for Stack
    for parent in node.parents
        push!(stack, parent)
    end

    while !isempty(stack)
        current = pop!(stack)

        if current === ancestor
            return true
        end

        if !(current in visited)
            push!(visited, current)

            if haskey(graph._nodes, current)
                node = graph._nodes[current]

                for parent in node.parents
                    push!(stack, parent)
                end
            end
        end
    end

    return false
end

function ancestor_of(graph::ArbiterGraph, name::Symbol, ancestor::Symbol)
    return ancestor_of(graph, name, ancestor, NodeSet())
end

"""
add a node to the graph.

Raises an exception if the node cannot be added (i.e., if a node
that name already exists, or if it would create a cycle.

NOTE: A node can be added before its parents are added.

name: The name of the node to add to the graph.
parents: (optional, ()) The name of the nodes parents.
"""
function push!(graph::ArbiterGraph, name::Symbol, parents::NodeSet)
    is_stub = false

    if haskey(graph._nodes, name)
        if name in graph._stubs
            node = Node(name, graph._nodes[name].children, parents)
            is_stub = true
        else
            error(name)
        end
    else
        node = Node(name, NodeSet(), parents)
    end

    # cycle detection
    visited = NodeSet()

    for parent in parents
        if ancestor_of(graph, parent, name, visited)
            error(parent)
        elseif parent === name
            error(parent)
        end
    end

    # Node safe to add
    if is_stub
        pop!(graph._stubs, name)
    end

    if !isempty(parents)
        for parent_name in parents
            if haskey(graph._nodes, parent_name)
                parent_node = graph._nodes[parent_name]
                push!(parent_node.children, name)
            else
                graph._nodes[parent_name] = Node(parent_name, NodeSet((name,)))
                push!(graph._stubs, parent_name)
            end
        end
    else
        push!(graph._roots, name)
    end

    graph._nodes[name] = node

    return nothing
end

function push!(graph::ArbiterGraph, name, parents=())
    return push!(graph, symbol(name), NodeSet(parents))
end


"""
Remove a node from the graph. Returns the set of nodes that were
removed.

If the node doesn't exist, an exception will be raised.

name: The name of the node to remove.
strategy: (Optional, Strategy.promote) What to do with children
    or removed nodes. The options are:

    orphan: remove the node from the child's set of parents.
    promote: replace the node with the the node's parents in the
        childs set of parents.
    remove: recursively remove all children of the node.
"""
function pop!(graph::ArbiterGraph, name::Symbol; strategy::Strategy=Promote)
    removed = NodeSet()

    stack = Stack(Symbol)
    push!(stack, name)

    while !isempty(stack)
        current = pop!(stack)
        node = pop!(graph._nodes, current)

        if strategy == Remove
            for child_name in node.children
                child_node = graph._nodes[child_name]

                pop!(child_node.parents, current)

                push!(stack, child_name)
            end
        else
            for child_name in node.children
                child_node = graph._nodes[child_name]

                pop!(child_node.parents, current)

                if strategy == Promote
                    for parent_name in node.parents
                        parent_node = graph._nodes[parent_name]

                        push!(parent_node.children, child_name)
                        push!(child_node.parents, parent_name)
                    end
                end

                if isempty(child_node.parents)
                    push!(graph._roots, child_name)
                end
            end
        end

        if current in graph._stubs
            pop!(graph._stubs, current)
        elseif current in graph._roots
            pop!(graph._roots, current)
        else  # stubs and roots (by definition) don't have parents
            for parent_name in node.parents
                parent_node = graph._nodes[parent_name]

                pop!(parent_node.children, current)

                if parent_name in graph._stubs && isempty(parent_node.children)
                    push!(stack, parent_name)
                end
            end
        end

        push!(removed, current)
    end

    return removed
end

"""
Remove any tasks that have stubs as ancestors (and the stubs
themselves).

Returns the set of nodes which were removed.
"""
function prune!(graph::ArbiterGraph)
    pruned = NodeSet()
    stubs = ImmutableNodeSet(graph._stubs)

    for stub in stubs
        union!(pruned, pop!(graph, stub; strategy=Remove))
    end

    return setdiff!(pruned, stubs)
end

"""
Check whether a node is in the graph
"""
function in(node::Symbol, graph::ArbiterGraph)
    return haskey(graph._nodes, node)
end

"""
Equality checking
"""
function ==(graph1::ArbiterGraph, graph2::ArbiterGraph)
    return graph1._nodes == graph2._nodes && graph1._stubs == graph2._stubs
end

end
