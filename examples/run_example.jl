# End-to-end build example. This builds and initializes the model, writes
# square diagnostics, and stops before solve unless the closure is square.
# Run with:
#   julia --project=. examples/run_example.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using .EnvCGE
using JuMP

outdir = joinpath(ENV_CGE_PROJECT_ROOT, "reports", "path_square")
data, cal = calibrate_from_excel()

diag = preflight_path_square(data, cal; outdir=outdir)
println("Preflight square for PATH: ", diag["square_using_total_variables"])
println("Preflight report directory: ", outdir)

em = build_model(data, cal; initialize=true, audit_mapping=true, require_square=false)
println("Initial value report: ", em.solution["initial_values"])
println("Variables: ", JuMP.num_variables(em.jump))
println("Constraints: ", JuMP.num_constraints(em.jump; count_variable_in_set_constraints=false))

if get(diag, "square_using_total_variables", false)
    println("Model is square. To solve, uncomment:")
    println("  sol = solve!(em; require_square=true)")
    println("  println(sol)")
else
    println("Model is not square yet. Inspect diagnostics before calling solve!.")
end
