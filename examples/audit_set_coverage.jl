# Audit loaded sets and PATH mapping coverage.
# Run with:
#   julia --project=. examples/audit_set_coverage.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using EnvCGE

data = load_default_data()
cal = calibrate(data)
model = build_model(data, cal; initialize=true, audit_mapping=true, require_square=false)

println("Sets loaded from Excel:")
for field in fieldnames(typeof(data.sets))
    vals = getfield(data.sets, field)
    println(rpad(String(field), 8), length(vals), " => ", vals)
end

println("\nPATH mapping report:")
report = path_mapping_report(model)
for k in sort(collect(keys(report)))
    k == "mapping" && continue
    println(k, " => ", report[k])
end
