# Audit that the Excel-driven model is ready for PATHSolver.
# Run from the package root:
#   julia --project=. examples/audit_path_model.jl
# Also works from any directory:
#   julia path/to/EnvCGE/examples/audit_path_model.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using .EnvCGE

data, cal = calibrate_from_excel()
em = build_model(data, cal; initialize=true, audit_mapping=true, require_square=false)
report = path_mapping_report(em)

println("Registry equations: ", report["registry_equations"])
println("Mapped equations:   ", report["mapped_equations"])
println("Variables:          ", report["variable_count"])
println("Constraints:        ", report["constraint_count_excluding_bounds"])
println("Square for PATH:    ", report["square_for_path"])
println("Missing mappings:   ", report["missing_mapping"])
println("Undeclared vars:    ", report["undeclared_mapped_variable_families"])

# For the actual solve, first make the closure square, then use:
# sol = solve!(em; require_square=true)
# println(sol)
