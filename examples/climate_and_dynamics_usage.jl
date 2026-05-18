# Climate linkage utility usage.
# Run with:
#   julia --project=. examples/climate_and_dynamics_usage.jl

include(joinpath(@__DIR__, "_example_preamble.jl"))
using EnvCGE

data = load_default_data()
cal = calibrate(data)
model = build_model(data, cal; initialize=true, audit_mapping=false, require_square=false)

# After solving, climate_step!(model, st) reads EmiGbl from the model.
# This example also works before solve by using the JuMP start values.
st = climate_state(cal)
climate_step!(model, st; dt=1.0)

println("Atmospheric carbon MAT: ", st.MAT)
println("Temperature anomaly TATM: ", st.TATM)
println("Damage factor: ", climate_damage_factor(st))
