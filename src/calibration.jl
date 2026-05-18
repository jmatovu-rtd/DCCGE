# === Function usage ===
# Calibration routines tied to ../data/example_envcge_data.xlsx.
# Usage:
#   data = load_default_data()
#   cal  = calibrate(data)
# or:
#   data, cal = calibrate_from_excel()
#
# Main output:
#   EnvCalibration(alpha, sigma, lambda, taxes, benchmark, emissions, climate)
# ======================

# Calibration routines tied to ../data/example_envcge_data.xlsx.
# Usage:
#   data = load_default_data()
#   cal  = calibrate(data)
# or:
#   data, cal = calibrate_from_excel()

function _default_sigma()
    # Elasticity defaults used by production, supply, demand, factors, and trade.
    # Workbook values from the elasticities sheet override these defaults.
    Dict{String,Any}(
        "sigma_xp"=>0.1,
        "sigma_p"=>0.0,
        "sigma_v"=>0.8,
        "sigma_v1"=>0.4,
        "sigma_v2"=>0.5,
        "sigma_ul"=>1.0,
        "sigma_sl"=>1.0,
        "sigma_kef"=>0.5,
        "sigma_kf"=>0.5,
        "sigma_kw"=>0.5,
        "sigma_k"=>0.5,
        "sigma_n1"=>0.0,
        "sigma_n2"=>0.5,
        "sigma_wat"=>0.5,
        "sigma_erg"=>0.5,
        "sigma_nely"=>0.5,
        "sigma_olg"=>0.5,
        "sigma_nrg"=>0.5,
        "sigma_s"=>2.0,
        "sigma_power"=>2.0,
        "sigma_pb"=>3.0,
        "sigma_gen"=>5.0,
        "psi_x"=>4.0,
        "sigma_arm"=>2.0,
        "sigma_m"=>4.0,
        "psi_et"=>2.0,
        "sigma_hh"=>1.0,
        "sigma_hh_energy"=>0.5,
        "sigma_gov"=>0.0,
        "sigma_inv"=>0.0,
        "psi_land"=>0.25,
        "psi_water"=>0.25
    )
end

function _default_climate()
    Dict{String,Any}(
        "M0"=>589.0,"F2x"=>3.71,"lambda_clim"=>1.2,"c1"=>0.22,"c3"=>0.3,"c4"=>0.05,
        "slrcoef"=>0.003,"damage_a1"=>0.0,"damage_a2"=>0.002
    )
end

function _shares(keys)
    n = length(keys)
    return Dict(String(k) => 1 / max(n, 1) for k in keys)
end

function _merge_named_values!(target::Dict{String,Any}, df::DataFrame)
    isempty(df) && return target
    namecol = (:name in propertynames(df)) ? :name : ((:parameter in propertynames(df)) ? :parameter : nothing)
    valuecol = (:value in propertynames(df)) ? :value : nothing
    if namecol !== nothing && valuecol !== nothing
        for row in eachrow(df)
            ismissing(row[namecol]) && continue
            target[String(row[namecol])] = _num(row[valuecol])
        end
    end
    return target
end

function _calibrate_alpha(data::EnvData)
    s = data.sets
    alpha = Dict{String,Any}()

    # Production nests
    alpha["xp"]              = _shares(["XPX", "XGHG"])
    alpha["top"]             = _shares(["ND1", "VA"])
    alpha["crop_va"]         = _shares(["LAB1", "VA1"])
    alpha["crop_va1"]        = _shares(["ND2", "VA2"])
    alpha["crop_va2"]        = _shares(["LAND", "KEF"])
    alpha["livestock_va"]    = _shares(["LAB1", "VA1", "VA2"])
    alpha["livestock_va1"]   = _shares(["VA2", "KEF"])
    alpha["livestock_va2"]   = _shares(["LAND", "FEED"])
    alpha["def_va"]          = _shares(["LAB1", "VA1"])
    alpha["def_va1"]         = _shares(["KEF", "VA2"])
    alpha["lab1"]            = _shares(s.ul)
    alpha["lab2"]            = _shares(s.sl)
    alpha["kef"]             = _shares(["KF", "ENERGY", "KSW", "NRS"])
    alpha["ksw"]             = _shares(["KS", "WAT"])
    alpha["ks"]              = _shares(["CAP", "LAB2"])
    alpha["io"]              = _shares(setdiff(s.i, s.nrg))
    alpha["io2"]             = _shares(setdiff(s.i, s.nrg))
    alpha["water"]           = merge(_shares(s.wbnd), Dict("WAT"=>1.0))
    alpha["energy_top"]      = _shares(["ELY", "NELY"])
    alpha["nely"]            = _shares(["COA", "OLG"])
    alpha["olg"]             = _shares(["OIL", "GAS"])
    alpha["energy"]          = _shares(s.nrg)

    # Supply and power nests
    alpha["make"]             = _shares(s.i)
    alpha["supply"]           = _shares(s.a)
    alpha["power_aux"]        = _shares(s.ax)
    alpha["electricity_top"]  = _shares(["ETD", "POWER"])
    alpha["power"]            = _shares(s.pb)
    alpha["generation"]       = _shares(s.elya)
    alpha["generation_energy"] = _shares(s.nrg)

    # Demand nests
    alpha["hh"]        = _shares(s.k)
    alpha["hh_energy"] = _shares(s.nrg)
    alpha["gov"]       = _shares(s.k)
    alpha["inv"]       = _shares(s.k)
    alpha["household"] = _shares(s.i)

    # Factor nests
    alpha["land"]         = _shares(s.lnd)
    alpha["land_bundle"]  = _shares(s.lb)
    alpha["water_bundle"] = _shares(s.wbnd)

    # Trade nests
    alpha["armington"] = _shares(["D", "M"])
    alpha["imports"]   = _shares(s.r)
    alpha["exports"]   = _shares(s.r)
    alpha["margins"]   = _shares(s.i)

    # Backward-compatible aliases for older equation files or saved workbooks.
    alpha["liv_va"]  = alpha["livestock_va"]
    alpha["liv_va1"] = alpha["livestock_va1"]
    alpha["liv_va2"] = alpha["livestock_va2"]

    # User/workbook-provided shares override defaults. Expected columns:
    #   nest, item, value
    shares = get(data.tables, "shares", DataFrame())
    if !isempty(shares) && all(x -> x in propertynames(shares), [:nest, :item, :value])
        for row in eachrow(shares)
            nest = String(row[:nest]); item = String(row[:item])
            haskey(alpha, nest) || (alpha[nest] = Dict{String,Any}())
            alpha[nest][item] = _num(row[:value])
        end
    end
    return alpha
end

function _calibrate_sigmas(data::EnvData)
    sigma = _default_sigma()
    _merge_named_values!(sigma, get(data.tables, "elasticities", DataFrame()))
    return sigma
end

function _calibrate_lambda(data::EnvData)
    lambda = Dict{String,Any}(
        "lambda_f"=>1.0,
        "lambda_ep"=>1.0,
        "lambda_io"=>1.0,
        "lambda_xp"=>1.0,
        "lambda_ghg"=>1.0,
        "table"=>get(data.tables, "parameters", DataFrame())
    )
    _merge_named_values!(lambda, lambda["table"])
    return lambda
end

function _calibrate_taxes(data::EnvData)
    taxes = Dict{String,Any}(
        "tau_uc"=>0.0,
        "tau_x"=>0.0,
        "tau_a"=>0.0,
        "tau_m"=>0.0,
        "tau_e"=>0.0,
        "tau_ntm"=>0.0,
        "tau_f"=>0.0,
        "tau_c"=>0.0,
        "tau_d"=>0.0,
        "tau_waste"=>0.0,
        "waste_rate"=>0.0,
        "subsistence_share"=>0.0,
        "inventory_share"=>0.0,
        "sav_h"=>0.0,
        "sav_g"=>0.0,
        "transfer_share"=>0.0,
        "migration_rate"=>0.0,
        "sectoral_inv_share"=>0.0,
        "table"=>get(data.tables, "taxes", DataFrame())
    )
    _merge_named_values!(taxes, taxes["table"])
    _merge_named_values!(taxes, get(data.tables, "parameters", DataFrame()))
    return taxes
end

function _calibrate_emissions(data::EnvData)
    df = get(data.tables, "emissions", DataFrame())
    emissions = Dict{String,Any}(
        "co2coef"=>0.0,
        "nonco2coef"=>0.0,
        "gwp"=>Dict("CO2"=>1.0,"CH4"=>28.0,"N2O"=>265.0,"FGAS"=>1000.0),
        "table"=>df
    )
    _merge_named_values!(emissions, df)
    if !isempty(df) && (:em in propertynames(df)) && (:gwp in propertynames(df))
        emissions["gwp"] = Dict(String(row[:em]) => _num(row[:gwp]; default=1.0) for row in eachrow(df))
    end
    return emissions
end

function _calibrate_climate(data::EnvData)
    climate = _default_climate()
    _merge_named_values!(climate, get(data.tables, "climate", DataFrame()))
    return climate
end

function _benchmark_from_excel(data::EnvData, sam::DataFrame)
    Dict{String,Any}(
        "source_excel" => get(data.par, "source_excel", default_excel_path()),
        "sam_balance" => check_sam_balance(sam),
        "sam" => sam,
        "io" => get(data.tables, "io", DataFrame()),
        "make" => get(data.tables, "make", DataFrame()),
        "use" => get(data.tables, "use", DataFrame()),
        "final_demand" => get(data.tables, "final_demand", DataFrame()),
        "trade" => get(data.tables, "trade", DataFrame()),
        "closures" => get(data.tables, "closures", DataFrame()),
        "dynamics" => get(data.tables, "dynamics", DataFrame()),
        "initial_values_source" => "Derived from SAM and workbook tables in data/example_envcge_data.xlsx"
    )
end


function _validate_calibration_coverage(cal::EnvCalibration)
    required_alpha = Dict(
        "xp"=>["XPX","XGHG"], "top"=>["ND1","VA"],
        "crop_va"=>["LAB1","VA1"], "crop_va1"=>["ND2","VA2"], "crop_va2"=>["LAND","KEF"],
        "livestock_va"=>["LAB1","VA1","VA2"], "livestock_va1"=>["VA2","KEF"], "livestock_va2"=>["LAND","FEED"],
        "def_va"=>["LAB1","VA1"], "def_va1"=>["KEF","VA2"],
        "kef"=>["KF","ENERGY","KSW","NRS"], "ksw"=>["KS","WAT"], "ks"=>["CAP","LAB2"],
        "water"=>["WAT"], "energy_top"=>["ELY","NELY"], "nely"=>["COA","OLG"], "olg"=>["OIL","GAS"],
        "electricity_top"=>["ETD","POWER"], "armington"=>["D","M"]
    )
    for (nest, keys) in required_alpha
        haskey(cal.alpha, nest) || error("Missing calibrated alpha nest: $nest")
        for key in keys
            haskey(cal.alpha[nest], key) || error("Missing calibrated alpha[$nest][$key]")
        end
    end
    return cal
end

function calibrate(data::EnvData, sam::DataFrame=construct_sam(data))
    alpha = _calibrate_alpha(data)
    sigma = _calibrate_sigmas(data)
    lambda = _calibrate_lambda(data)
    taxes = _calibrate_taxes(data)
    benchmark = _benchmark_from_excel(data, sam)
    emissions = _calibrate_emissions(data)
    climate = _calibrate_climate(data)
    cal = EnvCalibration(alpha, sigma, lambda, taxes, benchmark, emissions, climate)
    _validate_calibration_coverage(cal)
    return cal
end

function calibrate_from_excel(path::AbstractString=default_excel_path())
    data = load_excel_data(path)
    cal = calibrate(data)
    return data, cal
end
