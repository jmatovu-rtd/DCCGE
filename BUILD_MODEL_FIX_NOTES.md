# Build model fixes

This package was patched for the reported `build_model(data, cal)` failure.

## Fixed files

- `src/path_mapping.jl`
  - Replaced fixed range loops with `enumerate(...)` so the mapping cannot index past the available vector length.
  - Expanded `closure_vars` to 31 entries to match implemented `M-1:M-31` closure residuals.
  - This removes the `BoundsError: attempt to access 26-element Vector{String} at index [27]`.

- `src/equations_registry.jl`
  - Changed within-period closure registry from `M-1:M-39` to `M-1:M-31`, matching `closure_residuals!` and implemented equations in `closure_block!`.
  - Removed `G-1:G-12` from the within-period PATH equation registry because those are recursive dynamic update formulas, not static MCP rows.

- `src/closure.jl`
  - Added aliases for `TEMI`, Greek-capital-tau `ΤEMI`, and `EMITAX`, all mapped to `τEmi`.
  - This addresses the warning where the Excel closure variable `ΤEMI` was skipped.

- `src/initialization.jl`
  - Replaced `_excel_sum` generator reduction with an explicit accumulator loop so empty Excel slices return `0.0`.
  - Added `init=0.0` to SAM row/column sum helpers.

## Required use

Extract this zip over your active `d:\MRIO\Envisage\EnvCGE_V9` folder and restart Julia before testing.
