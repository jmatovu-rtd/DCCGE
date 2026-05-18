# Read initial values from Excel/SAM and apply them to a JuMP/PATH model.
# Run with:
#   julia --project=. examples/read_initial_values.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using .EnvCGE

data, cal = calibrate_from_excel()
starts = initial_values_from_excel(data, cal)
println("Excel workbook: ", data.par["source_excel"])
println("Number of explicit initial values: ", length(starts))
println("Sample starts:")
for k in first(sort(collect(keys(starts))), min(20, length(starts)))
    println("  ", k, " = ", starts[k])
end

model = build_model(data, cal; initialize=true, audit_mapping=true, require_square=false)
println("Applied start values: ", model.solution["initial_values"])
