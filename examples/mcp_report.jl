# MCP mapping/report example.
# Run with:
#   julia --project=. examples/mcp_report.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using EnvCGE

data = load_default_data()
cal = calibrate(data)
em = build_model(data, cal; initialize=true, audit_mapping=true, require_square=false)

pairs = mcp_pair_registry(data)
println("MCP pairs: ", length(pairs))
for key in first(collect(keys(pairs)), min(12, length(pairs)))
    row = pairs[key]
    println(row.equation, " :: ", row.mcp, " over ", row.domain)
end

rep = mcp_formulation_report(em)
println(rep["mcp_syntax"])
