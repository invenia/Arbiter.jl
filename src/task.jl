# Task creation/generation

module ArbiterTasks

export ArbiterTask

import ..ArbiterGraphs: ImmutableNodeSet

immutable ArbiterTask
	name::Symbol
	func::Function
	dependencies::ImmutableNodeSet
end

"""
Create a task object

name: The name of the task.
function: The actual task function. It should take no arguments,
    and return a False-y value if it fails.
dependencies: (optional, ()) Any dependencies that this task relies
    on.
"""
function ArbiterTask(name, func::Function, dependencies::Any=())
	return ArbiterTask(symbol(name), func, ImmutableNodeSet([symbol(d) for d in dependencies]))
end

end