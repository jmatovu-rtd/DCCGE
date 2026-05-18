# Function Usage Guide

This guide shows how to call the functions in each source file. The usual workflow is:

```julia
using EnvCGE
data = load_default_data()
cal  = calibrate(data)
model = build_model(data, cal; initialize=true, audit_mapping=true)
report = path_mapping_report(model)
sol = solve!(model; require_square=true)
```

During development, use `require_square=false` to inspect mapping and closure issues before enforcing the square MCP condition.

## `src/EnvCGE.jl`

- `using EnvCGE` — Load the package and all exported functions.
- `include("src/EnvCGE.jl"); using .EnvCGE` — Use source directly without installing the package.

## `src/io.jl`

- `package_root()` — Return the root folder of the package.
- `data_dir()` — Return the data folder path.
- `default_excel_path()` — Return data/example_envcge_data.xlsx.
- `load_excel_data(path=default_excel_path())` — Read Excel sheets and construct EnvData.
- `load_default_data()` — Convenience wrapper around load_excel_data(default_excel_path()).

## `src/types.jl`

- `EnvSets(...) / EnvData(...) / EnvCalibration(...) / EnvModel(...)` — Core containers.
- `safeget(d,k,default)` — Safe dictionary lookup.
- `sigma/tau/lambda/alpha plus Unicode aliases σ/τ/λ/α` — Coefficient helpers.
- `is_crop/is_livestock/is_energy` — Set membership helpers used inside equations.

## `src/sam.jl`

- `construct_sam(data)` — Use workbook SAM if present; otherwise build a small default SAM.
- `check_sam_balance(sam; atol=1e-6)` — Return row/column balance diagnostics.

## `src/calibration.jl`

- `calibrate(data, sam=construct_sam(data))` — Build EnvCalibration from Excel/SAM tables.
- `calibrate_from_excel(path=default_excel_path())` — Return (data, cal) in one call.

## `src/initialization.jl`

- `initial_values_from_excel(data, cal)` — Build a Dict of variable starts from SAM/workbook tables.
- `apply_initial_values!(m, data, cal; strict=false)` — Apply start values to all variables in an existing JuMP model.

## `src/nests.jl`

- `ces_price(alpha,p,sigma; A=1.0, λ=nothing)` — CES unit-cost/price aggregator.
- `ces_demand(q,pc,pi,αi,sigma; A=1.0, λi=1.0)` — CES conditional demand.
- `leontief_demand(q,acoef)` — Fixed-coefficient demand.
- `cet_price(theta,p,psi; A=1.0)` — CET revenue/price aggregator.
- `cet_supply(q,px,pi,θi,psi; A=1.0)` — CET conditional supply.
- `logistic_supply(price,p0,qmax,η)` — Bounded sigmoid supply curve.
- `isoelastic_supply(price,p0,q0,η)` — Isoelastic supply curve.

## `src/production.jl`

- `production_block!(m,data,cal)` — Declare production variables and equations P-*.

## `src/supply.jl`

- `supply_block!(m,data,cal)` — Declare supply/make/electricity equations S-*.

## `src/income.jl`

- `income_block!(m,data,cal)` — Declare income, taxes, savings, investment equations Y-*.

## `src/demand.jl`

- `demand_block!(m,data,cal)` — Declare household/final demand equations D-*.

## `src/trade.jl`

- `trade_block!(m,data,cal)` — Declare Armington/CET/bilateral trade equations T-*.

## `src/markets.jl`

- `markets_block!(m,data,cal)` — Declare commodity and trade market-clearing equations M-*.

## `src/factors.jl`

- `factors_block!(m,data,cal)` — Declare labor/capital/land/NRS/water market equations F-*.

## `src/closure.jl`

- `closure_block!(m,data,cal)` — Declare national accounts, closure, numeraire, welfare equations C-*.

## `src/emissions.jl`

- `emissions_block!(m,data,cal)` — Declare emissions, permit, tax, and abatement equations E-*.

## `src/climate.jl`

- `ClimateState(...) ` — Create mutable climate state.
- `climate_step!(st, emissions_co2e, cal; dt=1.0)` — Advance climate state one period.
- `climate_damage_factor(st)` — Compute productivity/damage factor from current state.

## `src/dynamics.jl`

- `dynamics_update!(state,data,cal,tprev,tnext)` — Update recursive state variables.
- `run_recursive_dynamic!(model,state)` — Solve and update state over model.data.sets.t.

## `src/equations_registry.jl`

- `equation_registry()` — Return OrderedDict equation number => description.
- `nest_registry()` — Return OrderedDict nest name => description.

## `src/path_mapping.jl`

- `equation_variable_map(data)` — Return equation number => variable family mapping.
- `path_mapping_report(model)` — Return mapping, undeclared variables, and square diagnostics.
- `assert_path_ready!(model; require_square=true)` — Throw if the model is not ready for PATH.

## `src/model.jl`

- `build_model(data,cal; backend=:jump_path, initialize=true, audit_mapping=true)` — Build PATHSolver JuMP model and return EnvModel.
- `solve!(model; require_square=true)` — Audit, call optimize!, and return solution dictionary.

## Full source workflow

```julia
include("src/EnvCGE.jl")
using .EnvCGE
data, cal = calibrate_from_excel()
starts = initial_values_from_excel(data, cal)
model = build_model(data, cal; initialize=true, audit_mapping=true, require_square=false)
println(path_mapping_report(model))
# solve!(model; require_square=true)  # enforce square MCP after closure is finalized
```

### SAM construction

`construct_sam(data)` reads the Excel `sam` worksheet loaded into `data.sam`; it no longer falls back to a synthetic SAM. If the worksheet is missing or empty, it errors so calibration cannot accidentally use toy benchmark data. Use `check_sam_balance(sam)` and `assert_sam_balanced(sam)` to inspect the result.
