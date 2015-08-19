using Arbiter.ArbiterTasks
using Arbiter.ArbiterSchedulers
import Arbiter.ArbiterGraphs: NodeSet, ImmutableNodeSet

function create_task(name, dependencies=())
    ArbiterTask(name, () -> nothing, dependencies)
end

facts("empty") do
    scheduler = Scheduler()

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet()
    @fact scheduler --> isfinished
    @fact start_task!(scheduler) --> isnull

    remove_unrunnable!(scheduler)

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet()
    @fact scheduler --> isfinished
    @fact start_task!(scheduler) --> isnull

    fail_remaining!(scheduler)

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet()
    @fact scheduler --> isfinished
    @fact start_task!(scheduler) --> isnull
end

facts("add_task") do
    # add a task to Scheduler

    scheduler = Scheduler()

    # no dependencies
    add_task!(scheduler, create_task(:foo))

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    # 1 dependency
    add_task!(scheduler, create_task(:bar, (:foo,)))

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    # invalid tasks

    # circular dependencies
    add_task!(scheduler, create_task(:ouroboros, (:ouroboros,)))

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet((:ouroboros,))
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    # dependency made circular
    add_task!(scheduler, create_task(:tick, (:tock,)))

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet((:ouroboros,))
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    add_task!(scheduler, create_task(:tock, (:tick,)))

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet((:ouroboros, :tick, :tock))
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    at_init = Scheduler(
        (
            create_task(:foo),
            create_task(:bar, (:foo,)),
            create_task(:ipsum, (:lorem,)),
            create_task(:ouroboros, (:ouroboros,)),
            create_task(:tick, (:tock,)),
            create_task(:tock, (:tick,)),
        )
    )

    @fact completed(at_init) --> ImmutableNodeSet()
    @fact failed(at_init) --> ImmutableNodeSet((:ouroboros, :tick, :tock))
    @fact runnable(at_init) --> ImmutableNodeSet((:foo,))
    @fact at_init --> not(isfinished)
end

facts("remove_unrunnable!") do
    # remove unrunnable Scheduler tasks

    scheduler = Scheduler(
        (
            create_task(:foo),
            create_task(:bar, (:foo,)),
            create_task(:baz, (:bar,)),
            create_task(:ipsum, (:lorem,)),
            create_task(:dolor, (:ipsum,)),
            create_task(:sit, (:dolor, :stand)),
            create_task(:stand),
        )
    )

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo, :stand))
    @fact scheduler --> not(isfinished)

    remove_unrunnable!(scheduler)

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet((:ipsum, :dolor, :sit))
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo, :stand))
    @fact scheduler --> not(isfinished)
end

facts("start_task!") do
    # start a task

    scheduler = Scheduler(
        (
            create_task(:foo),
            create_task(:fighters, (:foo,)),
            create_task(:bar, (:foo,)),
            create_task(:baz, (:bar,)),
            create_task(:bell, (:bar,)),
            create_task(:node),
        )
    )

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo, :node))
    @fact scheduler --> not(isfinished)

    # start a specific task
    task = start_task!(scheduler, :node)
    @fact task --> not(isnull)
    @fact get(task).name --> :node

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet((:node,))
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    # start tasks invalidly
    @fact_throws ErrorException start_task!(scheduler, :node)
    @fact_throws ErrorException start_task!(scheduler, :bar)
    @fact_throws ErrorException start_task!(scheduler, :fake)

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet((:node,))
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    # is node still stoppable
    end_task!(scheduler, :node)

    @fact completed(scheduler) --> ImmutableNodeSet((:node,))
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    # start an arbitrary task
    task = start_task!(scheduler)
    @fact task --> not(isnull)
    @fact get(task).name --> :foo

    @fact completed(scheduler) --> ImmutableNodeSet((:node,))
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet((:foo,))
    @fact runnable(scheduler) --> ImmutableNodeSet()
    @fact scheduler --> not(isfinished)

    # no startable tasks
    @fact start_task!(scheduler) --> isnull

    @fact completed(scheduler) --> ImmutableNodeSet((:node,))
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet((:foo,))
    @fact runnable(scheduler) --> ImmutableNodeSet()
    @fact scheduler --> not(isfinished)

    # start an arbitrary task
    end_task!(scheduler, :foo)

    started = start_task!(scheduler)
    @fact started --> not(isnull)
    name = get(started).name
    @fact name --> anyof(:bar, :fighters)

    @fact completed(scheduler) --> ImmutableNodeSet((:node, :foo))
    @fact failed(scheduler) --> ImmutableNodeSet()

    if name === :bar
        @fact running(scheduler) --> ImmutableNodeSet((:bar,))
        @fact runnable(scheduler) --> ImmutableNodeSet((:fighters,))
    else
        @fact running(scheduler) --> ImmutableNodeSet((:fighters,))
        @fact runnable(scheduler) --> ImmutableNodeSet((:bar,))
    end

    @fact scheduler --> not(isfinished)
end

facts("end_task!") do
    # end a task

    scheduler = Scheduler(
        (
            create_task(:foo),
            create_task(:fighters, (:foo,)),
            create_task(:bar, (:foo,)),
            create_task(:baz, (:bar,)),
            create_task(:qux, (:baz,)),
            create_task(:bell, (:bar,)),
        )
    )

    @fact completed(scheduler) --> ImmutableNodeSet()
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:foo,))
    @fact scheduler --> not(isfinished)

    # end a task
    start_task!(scheduler, :foo)
    end_task!(scheduler, :foo)

    @fact completed(scheduler) --> ImmutableNodeSet((:foo,))
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:bar, :fighters))
    @fact scheduler --> not(isfinished)

    # invalid ends
    @fact_throws KeyError end_task!(scheduler, :foo)
    @fact_throws KeyError end_task!(scheduler, :bar)
    @fact_throws KeyError end_task!(scheduler, :baz)

    @fact completed(scheduler) --> ImmutableNodeSet((:foo,))
    @fact failed(scheduler) --> ImmutableNodeSet()
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:bar, :fighters))
    @fact scheduler --> not(isfinished)

    # fail a task
    start_task!(scheduler, :bar)
    end_task!(scheduler, :bar, false)

    @fact completed(scheduler) --> ImmutableNodeSet((:foo,))
    @fact failed(scheduler) --> ImmutableNodeSet((:bar, :baz, :qux, :bell))
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:fighters,))
    @fact scheduler --> not(isfinished)
end

facts("fail_remaining!") do
    # stop the scheduler

    scheduler = Scheduler(
        (
            create_task(:foo),
            create_task(:fighters, (:foo,)),
            create_task(:bar, (:foo,)),
            create_task(:baz, (:bar,)),
            create_task(:qux, (:baz,)),
            create_task(:bell, (:bar,)),
            create_task(:node),
        )
    )

    start_task!(scheduler, :foo)
    end_task!(scheduler, :foo)
    start_task!(scheduler, :bar)

    fail_remaining!(scheduler)

    @fact completed(scheduler) --> ImmutableNodeSet((:foo,))
    @fact failed(scheduler) --> ImmutableNodeSet((:bar, :baz, :qux, :bell, :fighters, :node))
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet()
    @fact scheduler --> isfinished

    # did that break adding tasks
    add_task!(scheduler, create_task(:restart))

    @fact completed(scheduler) --> ImmutableNodeSet((:foo,))
    @fact failed(scheduler) --> ImmutableNodeSet((:bar, :baz, :qux, :bell, :fighters, :node))
    @fact running(scheduler) --> ImmutableNodeSet()
    @fact runnable(scheduler) --> ImmutableNodeSet((:restart,))
    @fact scheduler --> not(isfinished)
end

facts("do notation") do
    # use do notation with the scheduler

    completed_nodes = NodeSet()
    failed_nodes = NodeSet()
    tasks = (
        create_task(:foo),
        create_task(:bar, (:foo,)),
        create_task(:baz, (:bar,)),
        create_task(:bell, (:bar,)),
        create_task(:lorem, ()),
        create_task(:ipsum, (:lorem,)),
        create_task(:node),
        create_task(:failed, (:fake,)),
    )

    Scheduler(tasks, completed_nodes, failed_nodes) do scheduler
        @fact completed_nodes --> NodeSet()
        @fact failed_nodes --> NodeSet((:failed,))

        start_task!(scheduler, :foo)
        end_task!(scheduler, :foo)

        @fact completed_nodes --> NodeSet((:foo,))
        @fact failed_nodes --> NodeSet((:failed,))

        start_task!(scheduler, :lorem)
        end_task!(scheduler, :lorem, false)

        @fact completed_nodes --> NodeSet((:foo,))
        @fact failed_nodes --> NodeSet((:failed, :lorem, :ipsum))

        start_task!(scheduler, :bar)
    end

    @fact completed_nodes --> NodeSet((:foo,))
    @fact failed_nodes --> NodeSet((:failed, :lorem, :ipsum, :bar, :baz, :bell, :node))
end
