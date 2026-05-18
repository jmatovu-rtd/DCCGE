# Advanced: build model blocks one at a time for debugging.
# Run with:
#   julia --project=. examples/block_by_block_build.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using .EnvCGE
using JuMP
using PATHSolver

data = load_default_data()
cal = calibrate(data)

m = Model(PATHSolver.Optimizer)
set_silent(m)
production_block!(m, data, cal)
supply_block!(m, data, cal)
income_block!(m, data, cal)
demand_block!(m, data, cal)
trade_block!(m, data, cal)
markets_block!(m, data, cal)
factors_block!(m, data, cal)
closure_block!(m, data, cal)
emissions_block!(m, data, cal)

report = apply_initial_values!(m, data, cal)
closure_report = apply_excel_closures!(m, data)
println("Initial values applied: ", report)
println("Excel closures applied: ", closure_report)
println("Variables: ", JuMP.num_variables(m))
println("Constraints excluding bounds: ", JuMP.num_constraints(m; count_variable_in_set_constraints=false))
