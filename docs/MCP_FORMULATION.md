# MCP presentation for PATHSolver

This package now carries an explicit mixed-complementarity presentation of the ENV-CGE equations.  Each documented equation number is mapped to a complementarity variable family and a Table 3.1 domain.

The intended PATHSolver row form is:

```julia
@constraint(model, [residual_expression, variable_reference] in MOI.Complements(2))
```

For example, a crop-specific production row must be indexed only over crop activities:

```julia
# P-14 crop/livestock land demand, not all activities
@constraint(m, [r=s.r, a=vcat(s.acr, s.alv), f=s.lnd],
    [land_demand_residual(r,a,f), XF[r,a,f]] in MOI.Complements(2))
```

Likewise, household consumption rows use consumed commodities `k`, not the entire product set `i`:

```julia
@constraint(m, [r=s.r, h=s.h, k=s.k],
    [household_demand_residual(r,h,k), HHDEM[r,h,k]] in MOI.Complements(2))
```

Energy rows use `nrg` only:

```julia
@constraint(m, [r=s.r, a=s.aa, n=s.nrg],
    [energy_input_residual(r,a,n), XANRG[r,a,n]] in MOI.Complements(2))
```

## Programmatic registry

Use:

```julia
using EnvCGE

data = load_default_data()
cal = calibrate(data)
em = build_model(data, cal; audit_mapping=true, require_square=false)
pairs = mcp_pair_registry(data)
report = mcp_formulation_report(em)
```

`mcp_pair_registry(data)` returns, for every equation number, the equation label, complementarity variable family, and the Table 3.1 domain.  This is the authoritative presentation layer for converting the remaining equality prototype rows into PATH MCP rows.

## Set discipline

The registry and equation comments enforce these subset rules:

- Crop-specific rows: `acr` only.
- Livestock-specific rows: `alv` only.
- Default non-crop/non-livestock activities: `ax` only.
- Electricity technologies: `elya` only.
- Household consumed commodities: `k` only.
- Energy commodities: `nrg` only.
- Land factors: `lnd` only.
- Natural-resource factors: `nrs` only.
- Water factors: `wat` only.
- Primary factors: `fp`, not the full account set.
- Non-household final demand: `fdc`, with government `gov` and investment `inv` where narrower.

## Important implementation note

Some equation files still contain equality prototype constraints because they are useful for static checking and accounting diagnostics.  The new MCP registry states how each row should be paired when moving the full model into native PATH complementarity constraints.  Do not broaden any row to `aa`, `i`, or `fp` unless the Table 3.1 domain in the MCP registry says so.
