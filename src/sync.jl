module Sync
# synchronous task runner

import ..ArbiterBase: task_loop, TaskResult

export run_tasks

"""
Run an iterable of tasks.

tasks: The iterable of tasks
"""
function run_tasks(tasks)
    return task_loop(tasks, execute)
end

"""
Execute a task, returning a Nullable{TaskResult}
"""
function execute(task)
    return Nullable(TaskResult(task.name, task.func()))
end

end