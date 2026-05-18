# Run with:
#   julia --project=. examples/identify_path_square_issues.jl
# Optional arguments:
#   julia --project=. examples/identify_path_square_issues.jl data/example_envcge_data.xlsx reports/path_square

include(joinpath(@__DIR__, "_example_preamble.jl"))
using .EnvCGE

xlsx = length(ARGS) >= 1 ? example_path(ARGS[1]) : default_excel_path()
outdir = length(ARGS) >= 2 ? example_path(ARGS[2]) : joinpath(ENV_CGE_PROJECT_ROOT, "reports", "path_square")

println("Loading data: ", xlsx)
data = load_excel_data(xlsx)
cal = calibrate(data)

println("Building diagnostic model inside path_square_diagnostics.jl and checking square status...")
diag = path_square_diagnostics(data, cal; initialize=true, audit_mapping=true, outdir=outdir)

println("Variables: ", diag["variable_count_total"])
println("Non-bound equations: ", diag["constraint_count_excluding_bounds"])
println("Gap variables - equations: ", diag["square_gap_total_variables"])
println("Square for PATH: ", diag["square_using_total_variables"])
println("Mapped but undeclared: ", diag["mapped_but_undeclared"])
println("Closure not declared: ", diag["closure_not_declared"])
println("Reports written to: ", outdir)
