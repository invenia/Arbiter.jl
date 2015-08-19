# Arbiter.jl

Arbiter is a task-scheduler that resolves task dependencies. Given a set of 
tasks and their dependencies, Arbiter will run the tasks such that no task is 
run before a dependency has already successfully run.

This package is a Julia port of [Arbiter](https://github.com/invenia/Arbiter).

## Installation

Arbiter.jl is not yet available in METADATA. To install:  
```julia
Pkg.clone("https://github.com/invenia/Arbiter.jl.git")
```

## Usage

To create a task:  
```julia
import Arbiter: ArbiterTask

task = ArbiterTask(name, func)

# A task with dependencies
dependent_task = ArbiterTask(name, func, (dependency1, dependency2))
```

To run tasks:  
```julia
import Arbiter.Sync: run_tasks

results = run_tasks(tasks)
```

Tasks cannot currently be run asynchronously. That feature is waiting on the 
WIP unified Channel interface for threaded and parallel Julia.

## Differences From Python Arbiter

Names are all casted to `Symbol`s. Any value can be used as a name, but the 
value returned in the results will be a `Symbol`.

`Nullable`s are used where Python may have had None, for type stability.

Various names have changed to become more Julian or avoid conflicts with 
existing functions or keywords. 

## License

Arbiter is provided under an MIT License.
