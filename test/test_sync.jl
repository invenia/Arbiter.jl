# tests for the synchronous task runner
import Arbiter.Sync: run_tasks
import Arbiter.ArbiterTasks: ArbiterTask
import Arbiter.ArbiterGraphs: NodeSet, ImmutableNodeSet

facts("empty") do
    # solve no tasks

    results = run_tasks(())

    @fact results.completed --> ImmutableNodeSet()
    @fact results.failed --> ImmutableNodeSet()
end

facts("no dependencies") do
    # run dependency-less tasks

    executed_tasks = NodeSet()

    """
    Make a task
    """
    function make_task(name, dependencies=(); succeed=true)
        ArbiterTask(name, () -> (push!(executed_tasks, name); succeed), dependencies)
    end

    results = run_tasks(
        (
            make_task(:foo),
            make_task(:bar),
            make_task(:baz),
            make_task(:fail; succeed=false)
        )
    )

    @fact executed_tasks --> NodeSet((:foo, :bar, :baz, :fail))
    @fact results.completed --> ImmutableNodeSet((:foo, :bar, :baz))
    @fact results.failed --> ImmutableNodeSet((:fail,))
end
