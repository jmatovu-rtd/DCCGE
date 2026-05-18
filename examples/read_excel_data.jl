# Read the default Excel workbook and show basic calibration information.
# Run with:
#   julia --project=. examples/read_excel_data.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using EnvCGE

data = load_default_data()
cal = calibrate(data)

println("Loaded workbook: ", data.par["source_excel"])
println("Available sheets: ", data.par["available_sheets"])
println("Sets: r=$(length(data.sets.r)), a=$(length(data.sets.a)), i=$(length(data.sets.i))")
println("SAM balance summary: ", cal.benchmark["sam_balance"])
