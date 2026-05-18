# Optional climate module linked to ENVISAGE emissions.
#
# The ENVISAGE 10.01 documentation marks the climate module and climate-damage
# feedbacks as [tbd].  Therefore this file does not add numbered ENVISAGE model
# equations or new JuMP equilibrium variables.  It is a post-solve / recursive
# dynamic utility that reads the model emissions variable `EmiGbl[em]` and updates
# a compact carbon-cycle/temperature state outside the MCP system.

Base.@kwdef mutable struct ClimateState
    # Atmospheric carbon stock in GtC.  The default is close to the late-20th
    # century atmospheric stock used in simple climate models.
    MAT::Float64 = 589.0
    # Upper-ocean/shallow-biosphere carbon stock in GtC.
    MU::Float64 = 360.0
    # Deep-ocean carbon stock in GtC.
    ML::Float64 = 1720.0
    # Atmospheric temperature anomaly in degrees Celsius.
    TATM::Float64 = 0.85
    # Lower-ocean temperature anomaly in degrees Celsius.
    TOCEAN::Float64 = 0.0
    # Radiative forcing in W/m^2.
    FORC::Float64 = 0.0
    # Damage multiplier, with 1.0 meaning no climate damage.
    DAMAGE::Float64 = 1.0
end

Base.@kwdef struct ClimateParams
    # Conversion from GtCO2 to GtC.
    gtco2_to_gtc::Float64 = 12.0 / 44.0
    # Pre-industrial atmospheric carbon stock in GtC.
    mat_preindustrial::Float64 = 588.0
    # Exogenous forcing, for example non-CO2 forcing, in W/m^2.
    exogenous_forcing::Float64 = 0.0
    # Carbon transition coefficients for a compact three-box carbon cycle.
    phi11::Float64 = 0.88
    phi12::Float64 = 0.12
    phi21::Float64 = 0.196
    phi22::Float64 = 0.797
    phi23::Float64 = 0.007
    phi32::Float64 = 0.001465
    phi33::Float64 = 0.998535
    # Temperature transition coefficients.
    xi1::Float64 = 0.1005
    xi2::Float64 = 0.088
    xi3::Float64 = 0.025
    xi4::Float64 = 0.005
    # Equilibrium climate sensitivity in degrees Celsius for CO2 doubling.
    equilibrium_climate_sensitivity::Float64 = 3.0
    # Damage function coefficient: DAMAGE = 1 / (1 + damage_quad * TATM^2).
    damage_quad::Float64 = 0.00236
end

function climate_params(cal::EnvCalibration)
    c = cal.climate
    return ClimateParams(
        gtco2_to_gtc = Float64(get(c, "gtco2_to_gtc", 12.0 / 44.0)),
        mat_preindustrial = Float64(get(c, "mat_preindustrial", 588.0)),
        exogenous_forcing = Float64(get(c, "exogenous_forcing", 0.0)),
        phi11 = Float64(get(c, "phi11", 0.88)),
        phi12 = Float64(get(c, "phi12", 0.12)),
        phi21 = Float64(get(c, "phi21", 0.196)),
        phi22 = Float64(get(c, "phi22", 0.797)),
        phi23 = Float64(get(c, "phi23", 0.007)),
        phi32 = Float64(get(c, "phi32", 0.001465)),
        phi33 = Float64(get(c, "phi33", 0.998535)),
        xi1 = Float64(get(c, "xi1", 0.1005)),
        xi2 = Float64(get(c, "xi2", 0.088)),
        xi3 = Float64(get(c, "xi3", 0.025)),
        xi4 = Float64(get(c, "xi4", 0.005)),
        equilibrium_climate_sensitivity = Float64(get(c, "equilibrium_climate_sensitivity", 3.0)),
        damage_quad = Float64(get(c, "damage_quad", 0.00236)),
    )
end

function climate_state(cal::EnvCalibration)
    c = cal.climate
    return ClimateState(
        MAT = Float64(get(c, "MAT0", 589.0)),
        MU = Float64(get(c, "MU0", 360.0)),
        ML = Float64(get(c, "ML0", 1720.0)),
        TATM = Float64(get(c, "TATM0", 0.85)),
        TOCEAN = Float64(get(c, "TOCEAN0", 0.0)),
        FORC = Float64(get(c, "FORC0", 0.0)),
        DAMAGE = Float64(get(c, "DAMAGE0", 1.0)),
    )
end

function climate_damage_factor(st::ClimateState)
    return st.DAMAGE
end

function _emission_is_co2(em::String)
    e = lowercase(strip(em))
    return e in ("co2", "co2e", "carbon", "c") || occursin("co2", e)
end

function _value_or_start(v)
    try
        return Float64(value(v))
    catch
        try
            return Float64(start_value(v))
        catch
            return 0.0
        end
    end
end

function model_global_emissions(em::EnvModel; emission::Union{Nothing,String}=nothing)
    m = em.jump
    m === nothing && error("Model has not been built; call build_model first.")
    haskey(JuMP.object_dictionary(m), :EmiGbl) || error("Model does not contain EmiGbl. Run emissions_block! before climate linkage.")
    EmiGbl = m[:EmiGbl]
    ems = em.data.sets.em
    selected = emission === nothing ? filter(_emission_is_co2, ems) : [emission]
    isempty(selected) && (selected = ems)
    return sum(_value_or_start(EmiGbl[e]) for e in selected)
end

function climate_step!(st::ClimateState, emissions_gtco2::Real, cal::EnvCalibration; dt::Real=1.0)
    return climate_step!(st, Float64(emissions_gtco2), climate_params(cal); dt=Float64(dt))
end

function climate_step!(st::ClimateState, emissions_gtco2::Float64, p::ClimateParams; dt::Float64=1.0)
    emissions_gtc = emissions_gtco2 * p.gtco2_to_gtc

    mat0 = st.MAT
    mu0 = st.MU
    ml0 = st.ML
    tatm0 = st.TATM
    tocean0 = st.TOCEAN

    # Three-box carbon transition with emissions injected into the atmosphere.
    st.MAT = p.phi11 * mat0 + p.phi21 * mu0 + emissions_gtc * dt
    st.MU = p.phi12 * mat0 + p.phi22 * mu0 + p.phi32 * ml0
    st.ML = p.phi23 * mu0 + p.phi33 * ml0

    ratio = max(st.MAT / p.mat_preindustrial, eps(Float64))
    st.FORC = 3.6813 * log(ratio) / log(2.0) + p.exogenous_forcing

    feedback = 3.6813 / p.equilibrium_climate_sensitivity
    st.TATM = tatm0 + dt * p.xi1 * (st.FORC - feedback * tatm0 - p.xi2 * (tatm0 - tocean0))
    st.TOCEAN = tocean0 + dt * p.xi3 * (tatm0 - tocean0)
    st.DAMAGE = 1.0 / (1.0 + p.damage_quad * st.TATM^2)
    return st
end

function climate_step!(em::EnvModel, st::ClimateState; emission::Union{Nothing,String}=nothing, dt::Real=1.0)
    emissions_gtco2 = model_global_emissions(em; emission=emission)
    return climate_step!(st, emissions_gtco2, em.calib; dt=dt)
end

function run_climate_path!(em::EnvModel, st::ClimateState; emission::Union{Nothing,String}=nothing, dt::Real=1.0)
    out = DataFrame(period=String[], emissions_gtco2=Float64[], MAT=Float64[], MU=Float64[], ML=Float64[], TATM=Float64[], TOCEAN=Float64[], FORC=Float64[], DAMAGE=Float64[])
    periods = isempty(em.data.sets.t) ? ["benchmark"] : em.data.sets.t
    for t in periods
        e = model_global_emissions(em; emission=emission)
        climate_step!(st, e, em.calib; dt=dt)
        push!(out, (String(t), e, st.MAT, st.MU, st.ML, st.TATM, st.TOCEAN, st.FORC, st.DAMAGE))
    end
    return out
end

function climate_block!(m::JuMP.Model, data::EnvData, cal::EnvCalibration)
    # No JuMP equations are added here because the ENVISAGE 10.01 climate module
    # is not specified in numbered model equations.  Use climate_step! after a
    # solve to link aggregate model emissions to climate states.
    return m
end

function climate_residuals!(res::Dict{String,Function})
    res["CLIMATE"] = x -> error("The ENVISAGE 10.01 climate module is TBD; climate_step! is a post-solve linkage utility, not an MCP residual.")
    return res
end
