# the dependecy scheduler
module ArbiterSchedulers

import ..ArbiterGraphs: ArbiterGraph, NodeSet, ImmutableNodeSet
import ..ArbiterGraphs: roots, nodes, prune!
import ..ArbiterGraphs: Strategy, Orphan, Promote, Remove
import ..ArbiterTasks: ArbiterTask

export  Scheduler,
        completed,
        failed,
        running,
        runnable,
        isfinished,
        add_task!,
        start_task!,
        end_task!,
        remove_unrunnable!,
        fail_remaining!

type Scheduler
    _graph::ArbiterGraph
    _tasks::Dict{Symbol, ArbiterTask}
    _running::NodeSet
    _completed::NodeSet
    _failed::NodeSet
end

"""
A dependency scheduler
"""
function Scheduler(tasks=NodeSet(), completed=NodeSet(), failed=NodeSet())
    scheduler = Scheduler(
        ArbiterGraph(),
        Dict{Symbol, ArbiterTask}(),
        NodeSet(),
        completed,
        failed,
    )

    for task in tasks
        add_task!(scheduler, task)
    end

    return scheduler
end

"""
A copy of the set of successfully completed tasks.
"""
completed(s::Scheduler) = ImmutableNodeSet(s._completed)

"""
A copy of the set of failed tasks.
"""
failed(s::Scheduler) = ImmutableNodeSet(s._failed)

"""
A copy of the set of running tasks.
"""
running(s::Scheduler) = ImmutableNodeSet(s._running)

"""
Get the set of tasks that are currently runnable.
"""
runnable(s::Scheduler) = setdiff(roots(s._graph), s._running)

"""
Have all runnable tasks completed?
"""
isfinished(s::Scheduler) = isempty(roots(s._graph)) && isempty(s._running)

"""
Add a task to the scheduler.

task: The task to add.
"""
function add_task!(scheduler::Scheduler, task::ArbiterTask)
    scheduler._tasks[task.name] = task

    incomplete_dependencies = NodeSet()
    failed = false

    for dependency in task.dependencies
        if dependency in scheduler._failed
            cascade_failure!(scheduler, task.name)
            failed = true
            break
        end

        if !(dependency in scheduler._completed)
            push!(incomplete_dependencies, dependency)
        end
    end

    if !failed
        try
            push!(scheduler._graph, task.name, incomplete_dependencies)
        catch
            cascade_failure!(scheduler, task.name)
        end
    end

    return nothing
end

"""
Start a task.

Returns the task that was started (or None if no task has been
    started).

name: (optional, None) The task to start. If a name is given,
    Scheduler will attempt to start the task (and raise an
    exception if the task doesn't exist or isn't runnable). If
    no name is given, a task will be chosen arbitrarily
"""
function start_task!(scheduler::Scheduler, name::Symbol)
    if !(name in scheduler._graph._roots) || name in scheduler._running
        error(name)
    end

    push!(scheduler._running, name)

    return Nullable(scheduler._tasks[name])
end

start_task!(scheduler::Scheduler, name) = start_task!(scheduler, symbol(name))

function start_task!(scheduler::Scheduler)
    found = false
    local name

    for possibility in scheduler._graph._roots
        if !(possibility in scheduler._running)
            name = possibility
            found = true
            break
        end
    end

    if found
        push!(scheduler._running, name)
        task = Nullable(scheduler._tasks[name])
    else
        # all tasks blocked/running/completed/failed
        task = Nullable{ArbiterTask}()
    end

    return task
end

"""
End a running task. Raises an exception if the task isn't
running.

name: The name of the task to complete.
success: (optional, True) Whether the task was successful.
"""
function end_task!(scheduler::Scheduler, name::Symbol, success=true)
    pop!(scheduler._running, name)

    if success
        push!(scheduler._completed, name)
        pop!(scheduler._graph, name; strategy=Orphan)
    else
        cascade_failure!(scheduler, name)
    end

    return nothing
end

end_task!(scheduler::Scheduler, name, success=true) = end_task(scheduler, symbol(name), success)

"""
Remove any tasks that are dependent on non-existent tasks.
"""
function remove_unrunnable!(scheduler::Scheduler)
    union!(scheduler._failed, prune!(scheduler._graph))
end

"""
Mark all unfinished tasks (including currently running ones) as
failed.
"""
function fail_remaining!(scheduler::Scheduler)
    union!(scheduler._failed, nodes(scheduler._graph))
    scheduler._graph = ArbiterGraph()
    scheduler._running = NodeSet()
end

"""
Mark a task (and anything that depends on it) as failed.

name: The name of the offending task
"""
function cascade_failure!(scheduler::Scheduler, name)
    if name in scheduler._graph
        union!(scheduler._failed, pop!(scheduler._graph, name; strategy=Remove))
    else
        push!(scheduler._failed, name)
    end

    return nothing
end

"""
Remove all unrunnable tasks and call a function. When
the function is exited, all non-complete tasks will be
failed.
"""
function Scheduler(f::Function, args...)
    scheduler = Scheduler(args...)

    remove_unrunnable!(scheduler)
    try
        f(scheduler)
    finally
        fail_remaining!(scheduler)
    end

    return nothing
end

end