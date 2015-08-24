module ArbiterBase

import ..ArbiterGraphs: ArbiterGraph, NodeSet, ImmutableNodeSet
import ..ArbiterSchedulers: Scheduler, start_task!, end_task!, isfinished

export task_loop

immutable Results
    completed::ImmutableNodeSet
    failed::ImmutableNodeSet
end

Results(completed, failed) = Results(ImmutableNodeSet(completed), ImmutableNodeSet(failed))

immutable TaskResult
    name::Symbol
    successful::Bool
end

"""
The inner task loop for a task runner.

tasks: An iterable of tasks to run
execute: A function that runs a task. It should take a task as its
    sole argument, and returns a Nullable{TaskResult} which may be null.
wait: (optional, None) A function to run whenever there aren't any
    runnable tasks (but there are still tasks listed as running).
    If given, this function should take no arguments, and should
    return an iterable of TaskResults.
"""
function task_loop(tasks, execute::Function, wait::Nullable{Function})
    completed_tasks = NodeSet()
    failed_tasks = NodeSet()

    Scheduler(tasks, completed_tasks, failed_tasks) do scheduler
        while !isfinished(scheduler)
            task = start_task!(scheduler)

            while !isnull(task)
                let result = execute(get(task))

                    # result exists iff execute is synchronous
                    if !isnull(result)
                        let task_result = get(result)
                            end_task!(scheduler, task_result.name, task_result.successful)
                        end
                    end
                end

                task = start_task!(scheduler)
            end

            if !isnull(wait)
                for task_result in wait()
                    end_task!(scheduler, task_result.name, task_result.successful)
                end
            end
        end
    end

    return Results(completed_tasks, failed_tasks)
end

task_loop(tasks, execute::Function, wait::Function) = task_loop(tasks, execute, Nullable(wait))

task_loop(tasks, execute::Function) = task_loop(tasks, execute, Nullable{Function}())

end
