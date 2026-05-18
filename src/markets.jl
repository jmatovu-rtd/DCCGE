# ENVISAGE v10.01 §3.7 Goods market equilibrium, equations E-1:E-2.
# Document-strict implementation: no extra market variables are introduced.
# E-1 determines PD/PDT by clearing domestic supply and demand; E-2 determines
# PE by clearing bilateral imports and exports with iceberg trade costs.

function markets_block!(m::JuMP.Model, data::EnvData, cal::EnvCalibration)
    PAR = parameters(data, cal)
    # Local parameter aliases generated from ParameterTables.jl.
    lambda_w = PAR[:lambda_w]
    s = data.sets
    λw = lambda_w
    @NLconstraints(m, begin
        # (E-1) Domestic market equilibrium for domestically produced goods.
        [r=s.r,i=s.i], m[:XDTd][r,i] == m[:XDTs][r,i]
        # (E-2) Bilateral trade equilibrium with iceberg trade-cost parameter.
        [r=s.r,i=s.i,d=s.r], m[:XWd][r,i,d] == λw * m[:XWs][r,i,d]
    end)
    return m
end

function markets_residuals!(res::Dict{String,Function})
    res["E-1"] = x -> error("Residual E-1 is implemented as ENVISAGE E-1 in markets_block!.")
    res["E-2"] = x -> error("Residual E-2 is implemented as ENVISAGE E-2 in markets_block!.")
    return res
end
