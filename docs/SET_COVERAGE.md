# Set coverage audit

The model now loads every set in ENVISAGE Table 3.1 and keeps later extension sets used by the power, land, water, dynamic, and climate modules.

## Table 3.1 sets now represented in `EnvSets`

- `aa`: Armington/user agents.
- `a`: activities, with subsets `acr`, `alv`, `ax`, and `elya`.
- `acr`: crop activities. Crop production equations now index over `s.acr`, not all activities.
- `alv`: livestock activities. Livestock production equations now index over `s.alv`, not all activities.
- `ax`: all other/non-crop/non-livestock activities. Default production equations and power auxiliary/T&D equations now index over `s.ax` where appropriate.
- `elya`: power generation activities/technologies.
- `etd`: optional electricity transmission/distribution activities; empty in the sample data unless a T&D activity is supplied.
- `z`: rural/urban zones.
- `i`: produced/supplied goods.
- `inum`: manufacturing sectors used in numeraire definitions.
- `fp`: factors of production. `f` remains as a backward-compatible alias for older code.
- `l`, `ul`, `sl`: labor, unskilled labor, and skilled labor subsets.
- `cap`, `lnd`, `nrs`, `wat`: capital, land, natural resource, and water factor subsets.
- `k`: consumed commodities. Household demand now indexes over `s.k` rather than all produced goods wherever the demand system refers to consumption.
- `nrg`: energy subset of consumed commodities. Energy and emissions equations now use `s.nrg` rather than all goods.
- `fd`, `fdc`, `h`, `gov`, `inv`: final demand accounts and subsets.
- `gy`, `itax`, `ptax`, `mtax`, `etax`, `vtax`, `ctax`, `dtax`: government revenue accounts and tax-account subsets.
- `r`, `rnum`, `rres`: regions, numeraire regions, and residual region.
- `em`: emission types.

## Extension sets retained

- `v`: capital vintages.
- `pb`: power bundles.
- `lb`: land bundles.
- `wbnd`: water bundles.
- `t`: recursive-dynamic periods.

## Equation-file changes

- `src/types.jl`: expanded `EnvSets` to include Table 3.1 sets, added membership helpers, and retained `f` as an alias for `fp`.
- `src/io.jl`: loader now reads all Table 3.1 set names from the Excel `sets` sheet and derives safe defaults only when a subset is absent.
- `src/production.jl`: middle production nests are separated by `acr`, `alv`, and `ax`; land factor demand uses `lnd`; natural-resource demand uses `nrs`; water-factor demand uses `wat`; energy inputs use `nrg`; non-energy intermediates exclude `nrg`.
- `src/demand.jl`: household consumption, CPI, utility, budget, government/investment aggregates, and final absorption use consumed commodities `k`; household energy uses `nrg`; other final demand uses `fdc`.
- `src/supply.jl`: electricity supply, T&D/auxiliary services, and electricity accounting are restricted to energy commodities `nrg`, auxiliary activities `ax`, power bundles `pb`, and generation technologies `elya`.
- `src/emissions.jl`: fuel/user emissions are indexed by energy commodities `nrg` and user accounts `aa`, not all produced goods.
- `src/income.jl`, `src/factors.jl`, `src/initialization.jl`: factor loops now use official `fp` while preserving the old `f` alias in the set container.

The example workbook `data/example_envcge_data.xlsx` has also been updated so the `sets` sheet includes the Table 3.1 set names and disjoint example subsets.
