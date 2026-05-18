# Function usage walkthrough for EnvCGE.
# Run with:
#   julia --project=. examples/function_usage_walkthrough.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using .EnvCGE

println("1. Load default Excel workbook")
data = load_default_data()
println("Regions: ", data.sets.r)
println("Activities: ", data.sets.a)
println("Commodities: ", data.sets.i)

println("\n2. Construct/check SAM")
sam = construct_sam(data)
println(check_sam_balance(sam))

println("\n3. Calibrate")
cal = calibrate(data, sam)
println("Sigma keys: ", sort(collect(keys(cal.sigma))))

println("\n4. Build initial values")
starts = initial_values_from_excel(data, cal)
println("Number of start values: ", length(starts))

println("\n5. Build PATH/JuMP model")
model = build_model(data, cal; initialize=true, audit_mapping=true, require_square=false)

println("\n6. Audit PATH mapping")
report = path_mapping_report(model)
println("Mapped equations: ", report["mapped_equations"])
println("Undeclared mapped variable families: ", report["undeclared_mapped_variable_families"])
println("Square for PATH: ", report["square_for_path"])

println("\n7. Inspect equation and nest registries")
eq = equation_registry()
nests = nest_registry()
println("P-24: ", get(eq, "P-24", "not found"))
println("Available nest descriptions: ", collect(keys(nests)))

println("\n8. Optional solve")
println("Uncomment after closure produces a square MCP:")
println("  sol = solve!(model; require_square=true)")
