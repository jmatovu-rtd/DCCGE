# === Function usage ===
# Main module entry point.
# Usage:
#   using EnvCGE
#   data = load_default_data()
#   cal  = calibrate(data)
#   model = build_model(data, cal; initialize=true, audit_mapping=true)
#   report = path_mapping_report(model)
#   sol = solve!(model; require_square=true)
#
# Typical include-from-source workflow:
#   include("src/EnvCGE.jl")
#   using .EnvCGE
# ======================

module EnvCGE

using DataFrames, CSV, XLSX, JuMP, PATHSolver, OrderedCollections

include("types.jl")
include("nests.jl")
include("envisage_equation_forms.jl")
include("io.jl")
include("sam.jl")
include("calibration.jl")
include("ParameterTables.jl")
include("initialization.jl")
include("production.jl")
include("supply.jl")
include("income.jl")
include("demand.jl")
include("trade.jl")
include("markets.jl")
include("factors.jl")
include("closure.jl")
include("emissions.jl")
include("climate.jl")
include("dynamics.jl")
include("equations_registry.jl")
include("path_mapping.jl")
include("mcp.jl")
include("path_square_diagnostics.jl")
include("model.jl")

export EnvSets, EnvData, EnvCalibration, EnvParameters, EnvModel
export package_root, data_dir, default_excel_path, load_excel_data, load_default_data
export construct_sam, check_sam_balance, balance_sam, calibrate, calibrate_from_excel, initial_values_from_excel, apply_initial_values!
export precompute_parameters, parameters, equation_formula, ENVISAGE_FORMULAS
export apply_excel_closures!, build_model, solve!, path_square_diagnostics, write_path_square_report, assert_path_square_preflight!, preflight_path_square, path_square_block_diagnostics, write_path_square_block_report, equation_registry, envisage_document_equation_registry, equation_coverage_report, nest_registry, equation_source_file, equation_variable_map, path_mapping_report, assert_path_ready!, mcp_pair_registry, mcp_formulation_report, assert_mcp_pairs_ready!, ClimateState, ClimateParams, climate_state, climate_params, climate_step!, climate_damage_factor, model_global_emissions, run_climate_path!, run_recursive_dynamic!

end
