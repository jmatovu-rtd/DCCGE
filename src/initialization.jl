# === Function usage ===
# Initial value construction from the Excel/SAM benchmark.
# Usage:
#   data = load_default_data()
#   cal  = calibrate(data)
#   starts = initial_values_from_excel(data, cal)
#   model = build_model(data, cal; initialize=true)
#
# To apply starts manually to an existing JuMP model:
#   report = apply_initial_values!(jump_model, data, cal)
# ======================

# Initial values derived from data/example_envcge_data.xlsx.
#
# The initializer is deliberately data-driven: it reads the workbook through
# `EnvData`, extracts benchmark flows from the SAM and optional rectangular
# tables, and assigns JuMP start values to every variable created by the model
# blocks.  Missing observations are derived from related Excel/SAM/calibration
# totals; only benchmark prices remain normalized when the workbook has no
# explicit observed price sheet.


const MIN_START_VALUE = 1.0e-8
const BENCHMARK_PRICE_START = 1.0   # normalized benchmark price when Excel has flows but no price sheet

function _acc_parts(x)
    return split(String(x), ":")
end

function _hascols(df::DataFrame, cols::Vector{Symbol})
    return !isempty(df) && all(c -> c in propertynames(df), cols)
end

function _excel_sum(df::DataFrame; filters::Dict{Symbol,String}=Dict{Symbol,String}(), value_col::Symbol=:value)
    _hascols(df, [value_col]) || return 0.0
    total = 0.0
    for row in eachrow(df)
        keep = true
        for (col, val) in filters
            col in propertynames(df) || return 0.0
            if String(row[col]) != val
                keep = false
                break
            end
        end
        keep && (total += _num(row[value_col]))
    end
    return total
end

function _tblsum(data::EnvData, tbl::String; filters::Dict{Symbol,String}=Dict{Symbol,String}())
    return _excel_sum(get(data.tables, tbl, DataFrame()); filters=filters)
end

function _sam_value(sam::DataFrame, row::AbstractString, col::AbstractString; default=0.0)
    _hascols(sam, [:row, :col, :value]) || return default
    vals = sam.value[(String.(sam.row) .== row) .& (String.(sam.col) .== col)]
    isempty(vals) && return default
    return sum(_num(v) for v in vals)
end

function _sam_sum_rows(sam::DataFrame, prefix::AbstractString, r::String, key::String)
    _hascols(sam, [:row, :value]) || return 0.0
    target = string(prefix, ":", r, ":", key)
    return sum((_num(sam.value[k]) for k in eachindex(sam.row) if String(sam.row[k]) == target); init=0.0)
end

function _sam_sum_cols(sam::DataFrame, prefix::AbstractString, r::String, key::String)
    _hascols(sam, [:col, :value]) || return 0.0
    target = string(prefix, ":", r, ":", key)
    return sum((_num(sam.value[k]) for k in eachindex(sam.col) if String(sam.col[k]) == target); init=0.0)
end

function _make(data::EnvData, r::String; a::Union{Nothing,String}=nothing, i::Union{Nothing,String}=nothing)
    f = Dict{Symbol,String}(:region=>r)
    a === nothing || (f[:activity] = a)
    i === nothing || (f[:product] = i)
    return _tblsum(data, "make"; filters=f)
end

function _use(data::EnvData, r::String; a::Union{Nothing,String}=nothing, i::Union{Nothing,String}=nothing)
    f = Dict{Symbol,String}(:region=>r)
    a === nothing || (f[:activity] = a)
    i === nothing || (f[:product] = i)
    return _tblsum(data, "use"; filters=f)
end

function _fdemand(data::EnvData, r::String; fd::Union{Nothing,String}=nothing, i::Union{Nothing,String}=nothing)
    f = Dict{Symbol,String}(:region=>r)
    fd === nothing || (f[:fd] = fd)
    i === nothing || (f[:product] = i)
    return _tblsum(data, "final_demand"; filters=f)
end

function _factor_demand(data::EnvData, r::String; a::Union{Nothing,String}=nothing, fct::Union{Nothing,String}=nothing)
    f = Dict{Symbol,String}(:region=>r)
    a === nothing || (f[:activity] = a)
    fct === nothing || (f[:factor] = fct)
    return _tblsum(data, "factor_demand"; filters=f)
end

function _emissions(data::EnvData, r::String; em::Union{Nothing,String}=nothing, a::Union{Nothing,String}=nothing, i::Union{Nothing,String}=nothing)
    df = get(data.tables, "emissions", DataFrame())
    isempty(df) && return 0.0
    f = Dict{Symbol,String}()
    (:region in propertynames(df)) && (f[:region] = r)
    (em !== nothing && :em in propertynames(df)) && (f[:em] = em)
    (a !== nothing && :activity in propertynames(df)) && (f[:activity] = a)
    (i !== nothing && :product in propertynames(df)) && (f[:product] = i)
    return _excel_sum(df; filters=f)
end

function _activity_output(data::EnvData, sam::DataFrame, r::String, a::String)
    x = _make(data, r; a=a)
    x > 0 && return x
    return _sam_sum_cols(sam, "ACT", r, a)
end

function _commodity_supply(data::EnvData, sam::DataFrame, r::String, i::String)
    x = _make(data, r; i=i)
    x > 0 && return x
    return _sam_sum_rows(sam, "COM", r, i)
end

function _commodity_demand(data::EnvData, sam::DataFrame, r::String, i::String)
    x = _use(data, r; i=i) + _fdemand(data, r; i=i)
    x > 0 && return x
    return _sam_sum_cols(sam, "COM", r, i)
end

function _factor_supply(data::EnvData, sam::DataFrame, r::String, f::String)
    x = _factor_demand(data, r; fct=f)
    x > 0 && return x
    return _sam_sum_rows(sam, "FAC", r, f)
end

function _factor_use(data::EnvData, sam::DataFrame, r::String, f::String, a::String)
    x = _factor_demand(data, r; a=a, fct=f)
    x > 0 && return x
    return _sam_value(sam, "FAC:$r:$f", "ACT:$r:$a")
end

function _flow_start(x; floor=MIN_START_VALUE)
    y = _num(x; default=0.0)
    return (isfinite(y) && y > 0.0) ? y : floor
end

function _maybe_flow(x)
    y = _num(x; default=0.0)
    return (isfinite(y) && y > 0.0) ? y : MIN_START_VALUE
end

function _price_name(vname::String)
    return startswith(vname, "P") || startswith(vname, "WF") || startswith(vname, "W") || startswith(vname, "RENT") ||
        startswith(vname, "ROR") || startswith(vname, "RR") || startswith(vname, "τ") || startswith(vname, "emiTax") ||
        startswith(vname, "NumPrice") || startswith(vname, "PNUM") || startswith(vname, "ER")
end

function _split_varname(vname::String)
    m = match(r"^([^\[]+)(?:\[(.*)\])?$", vname)
    m === nothing && return vname, String[]
    base = String(m.captures[1])
    idx = m.captures[2] === nothing ? String[] : String.(split(String(m.captures[2]), ","))
    return base, idx
end

function _regional_absorption(data::EnvData, sam::DataFrame, r::String)
    x = _use(data, r) + _fdemand(data, r)
    x > 0 && return x
    return sum(_commodity_demand(data, sam, r, i) for i in data.sets.i)
end

function _regional_output(data::EnvData, sam::DataFrame, r::String)
    x = _make(data, r)
    x > 0 && return x
    return sum(_activity_output(data, sam, r, a) for a in data.sets.a)
end

function _regional_factor_income(data::EnvData, sam::DataFrame, r::String)
    x = _factor_demand(data, r)
    x > 0 && return x
    return sum(_factor_supply(data, sam, r, f) for f in data.sets.fp)
end

function _regional_household_income(data::EnvData, sam::DataFrame, r::String)
    hhfds = isempty(data.sets.h) ? ["HH"] : data.sets.h
    x = sum(_fdemand(data, r; fd=h) for h in hhfds)
    x > 0 && return x
    y = sum(_sam_sum_cols(sam, "HH", r, h) for h in hhfds)
    return y > 0 ? y : _regional_factor_income(data, sam, r)
end

function _price_start_from_calibration(data::EnvData, cal::EnvCalibration, base::String, idx::Vector{String})
    # The current workbook contains benchmark flows, not observed prices. In CGE
    # benchmark calibration those prices are normalized to one unless the workbook
    # provides an explicit price/benchmark record. Keep the numeraire normalization,
    # but do not use it for quantities.
    bench = cal.benchmark
    if bench isa Dict && haskey(bench, base)
        v = _num(bench[base]; default=NaN)
        isfinite(v) && v > 0 && return v
    end
    return BENCHMARK_PRICE_START
end

function _calibrated_start_for_var(base::String, idx::Vector{String}, data::EnvData, cal::EnvCalibration, sam::DataFrame)
    s = data.sets
    if _price_name(base)
        return _price_start_from_calibration(data, cal, base, idx)
    end
    r = isempty(idx) ? (isempty(s.r) ? "" : first(s.r)) : idx[1]
    scale_r = r in s.r ? _regional_absorption(data, sam, r) : sum(_regional_absorption(data, sam, rr) for rr in s.r)

    # Activity-level quantities.
    if length(idx) >= 2 && idx[1] in s.r && idx[2] in s.a
        r, a = idx[1], idx[2]
        xpa = _activity_output(data, sam, r, a)
        if base in ["XP","ND1","ND2","LAB1","LAB2","LANDD","NRSD","NRSSUP","WATD","Klo","Khi","K0","Lands","XNRSs","XNRFs","H2Os"]
            return _flow_start(xpa)
        elseif base in ["KDOF","KDNEW"]
            cap = sum(_factor_use(data, sam, r, f, a) for f in s.cap)
            return _flow_start(cap > 0 ? cap/2 : xpa/2)
        end
    end

    # Activity-vintage quantities.
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.a && idx[3] in s.v
        r, a, v = idx[1], idx[2], idx[3]
        xpa = _activity_output(data, sam, r, a)
        fv = max(length(s.v), 1)
        if base in ["XPv","XPX","VA","VA1","VA2","KEF","KF","KSW","KS","K","XNRG","XNELY","XOLG","XAely","XAcoa","XAoil","XAgas","XANRG","Kv"]
            return _flow_start(xpa / fv)
        elseif base in ["XGHG"]
            return _flow_start(_emissions(data, r; a=a) / fv)
        end
    end

    # Factor and intermediate input demand.
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.fp && idx[3] in s.a && base in ["XF"]
        return _flow_start(_factor_use(data, sam, idx[1], idx[2], idx[3]))
    end
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.i && idx[3] in union(s.a, s.aa)
        r, i, aa = idx[1], idx[2], idx[3]
        if base in ["XA","XAw","XAc"]
            return _flow_start(_use(data, r; a=aa, i=i))
        end
    end
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.a && idx[3] in s.i && base in ["X"]
        return _flow_start(_make(data, idx[1]; a=idx[2], i=idx[3]))
    end

    # Commodity totals and final demand.
    if length(idx) >= 2 && idx[1] in s.r && idx[2] in s.i
        r, i = idx[1], idx[2]
        qs = _commodity_supply(data, sam, r, i)
        qd = _commodity_demand(data, sam, r, i)
        if base in ["XS","XD","XDTs","XET","PET"]
            return _flow_start(qs)
        elseif base in ["XAT","XDTd","XMT","XM","XTT"]
            return _flow_start(qd)
        elseif base in ["XPOW"]
            return _flow_start(qs > 0 ? qs : qd)
        end
    end
    if length(idx) >= 2 && idx[1] in s.r && idx[2] in s.fd && base in ["XFD","QXFD","QFD","YFD"]
        return _flow_start(_fdemand(data, idx[1]; fd=idx[2]))
    end
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.k && idx[3] in s.h && startswith(base, "XC")
        return _flow_start(_fdemand(data, idx[1]; fd=idx[3], i=idx[2]))
    end
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.i && idx[3] in s.h && base in ["XAh"]
        return _flow_start(_fdemand(data, idx[1]; fd=idx[3], i=idx[2]))
    end

    # Factor, household, government and macro totals.
    if length(idx) >= 2 && idx[1] in s.r && idx[2] in s.fp && base in ["FS","F","YF"]
        return _flow_start(_factor_supply(data, sam, idx[1], idx[2]))
    end
    if length(idx) >= 2 && idx[1] in s.r && idx[2] in s.h && base in ["YH","YD","YC","Ysup","u"]
        return _flow_start(_regional_household_income(data, sam, idx[1]))
    end
    if length(idx) >= 2 && idx[1] in s.r && idx[2] in s.gy && base == "YGOV"
        return _flow_start(_fdemand(data, idx[1]; fd="GOV"))
    end
    if length(idx) >= 1 && idx[1] in s.r
        r = idx[1]
        if base in ["GDPMP","GDPFC","GDPVA","RGDPMP","YH","YD"]
            return _flow_start(_regional_absorption(data, sam, r))
        elseif base in ["Sh","Sg","Sf","PWsav","Ks","TKs","TKe","TLaNd","TLand","TH2O","WAT"]
            return _flow_start(0.10 * _regional_absorption(data, sam, r))
        elseif base in ["YGOV"]
            return _flow_start(_fdemand(data, r; fd="GOV"))
        elseif base in ["EV","CV","Welf","SWF","GLOBAL_Welf"]
            return _flow_start(_regional_household_income(data, sam, r))
        end
    end

    # Bilateral trade: workbook has no bilateral records in the example file, so
    # use observed import/export/absorption totals allocated by region counts.
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.i && idx[3] in s.r && base in ["XWs","XWd","XWa","XWMG","PWE","PWM","PWMG","PDM","PE"]
        q = _commodity_demand(data, sam, idx[3], idx[2]) / max(length(s.r), 1)
        return _flow_start(q)
    end
    if length(idx) >= 3 && idx[1] in s.r && idx[2] in s.r && idx[3] in s.i && base in ["XMT","IMDEM"]
        q = _commodity_demand(data, sam, idx[2], idx[3]) / max(length(s.r), 1)
        return _flow_start(q)
    end

    # Emissions.
    if startswith(base, "Emi") && !isempty(idx)
        rr = idx[1] in s.r ? idx[1] : (isempty(s.r) ? "" : first(s.r))
        em = length(idx) >= 2 && idx[2] in s.em ? idx[2] : nothing
        a = length(idx) >= 3 && idx[3] in s.a ? idx[3] : nothing
        return _flow_start(_emissions(data, rr; em=em, a=a))
    end

    return _flow_start(scale_r / 1000)
end

function initial_values_from_excel(data::EnvData, cal::EnvCalibration=calibrate(data))
    s = data.sets
    sam = construct_sam(data)
    starts = Dict{String,Float64}()

    # Activity and production starts from make/use/factor-demand tables.
    for r in s.r
        reg_abs = _regional_absorption(data, sam, r)
        for a in s.a
            xpa = _flow_start(_activity_output(data, sam, r, a))
            for nm in ["XP","ND1","ND2","LAB1","LAB2","LANDD","NRSSUP","NRSD","WATD"]
                starts["$nm[$r,$a]"] = xpa
            end
            capuse = sum(_factor_use(data, sam, r, f, a) for f in s.cap)
            starts["KDOF[$r,$a]"] = _flow_start(capuse > 0 ? capuse/2 : xpa/2)
            starts["KDNEW[$r,$a]"] = starts["KDOF[$r,$a]"]
            for pnm in ["PX","PND1","PND2","PLAB1","PLAB2","PNRS","RENT"]
                starts["$pnm[$r,$a]"] = BENCHMARK_PRICE_START
            end
            for v in s.v
                xv = xpa / max(length(s.v), 1)
                for nm in ["XPv","XPX","VA","VA1","VA2","KEF","KF","KSW","KS","K","XNRG","XNELY","XOLG","XAely","XAcoa","XAoil","XAgas","XANRG"]
                    starts["$nm[$r,$a,$v]"] = _flow_start(xv)
                end
                starts["XGHG[$r,$a,$v]"] = _flow_start(_emissions(data, r; a=a) / max(length(s.v),1))
                for pnm in ["PXv","UC","PXP","PXGHG","PVA","PVA1","PVA2","PKEF","PKF","PKSW","PKS","PKp","PNRG","PNELY","POLG","PAely","PAcoa","PAoil","PAgas","PANRG"]
                    starts["$pnm[$r,$a,$v]"] = BENCHMARK_PRICE_START
                end
            end
            for f in s.fp
                starts["XF[$r,$f,$a]"] = _flow_start(_factor_use(data, sam, r, f, a))
                starts["PFp[$r,$f,$a]"] = BENCHMARK_PRICE_START
            end
            for i in s.i
                makeval = _make(data, r; a=a, i=i)
                useval = _use(data, r; a=a, i=i)
                starts["X[$r,$a,$i]"] = _flow_start(makeval)
                starts["XA[$r,$i,$a]"] = _flow_start(useval)
                for pnm in ["P","PP","PAa","PA"]
                    starts["$pnm[$r,$a,$i]"] = BENCHMARK_PRICE_START
                    starts["$pnm[$r,$i,$a]"] = BENCHMARK_PRICE_START
                end
            end
        end

        for i in s.i
            qs = _flow_start(_commodity_supply(data, sam, r, i))
            qd = _flow_start(_commodity_demand(data, sam, r, i))
            for nm in ["XS","XD","XDTs","XET","XPOW"]
                starts["$nm[$r,$i]"] = qs
            end
            for nm in ["XAT","XDTd","XMT","XM","XTT"]
                starts["$nm[$r,$i]"] = qd
            end
            for pnm in ["PS","PM","PD","PDT","PMT","PAa","PE","PET","PAT","PPOW","PPOWN","PTT"]
                starts["$pnm[$r,$i]"] = BENCHMARK_PRICE_START
            end
            for h in s.h
                c = _fdemand(data, r; fd=h, i=i)
                c <= 0 && (c = _sam_value(sam, "COM:$r:$i", "HH:$r:$h"))
                for nm in ["XC","XAh","XAc","ZC","XCnnrg","XCnrg","XCely","XCnely","XCcoa","XColg","XCoil","XCgas"]
                    starts["$nm[$r,$i,$h]"] = _flow_start(c)
                end
                for pnm in ["PC","PXC","PAh","PACC","PAc","PAw","PCnnrg","PCnrg","PCely","PCnely","PCcoa","PColg","PCoil","PCgas"]
                    starts["$pnm[$r,$i,$h]"] = BENCHMARK_PRICE_START
                end
                starts["μc[$r,$i,$h]"] = _flow_start(c / max(_regional_household_income(data, sam, r), MIN_START_VALUE))
                starts["shr[$r,$i,$h]"] = starts["μc[$r,$i,$h]"]
            end
            for fd in s.fd
                fdv = _fdemand(data, r; fd=fd, i=i)
                starts["XFD[$r,$fd,$i]"] = _flow_start(fdv)
                starts["QXFD[$r,$fd,$i]"] = _flow_start(fdv)
            end
        end
        for fd in s.fd
            fdv = _fdemand(data, r; fd=fd)
            starts["XFD[$r,$fd]"] = _flow_start(fdv)
            starts["QXFD[$r,$fd]"] = _flow_start(fdv)
            starts["YFD[$r,$fd]"] = _flow_start(fdv)
            starts["PFD[$r,$fd]"] = BENCHMARK_PRICE_START
            starts["PXFD[$r,$fd]"] = BENCHMARK_PRICE_START
        end

        # Factor, household, government and macro accounts.
        for f in s.fp
            fs = _flow_start(_factor_supply(data, sam, r, f))
            starts["FS[$r,$f]"] = fs
            starts["F[$r,$f]"] = fs
            starts["YF[$r,$f]"] = fs
            starts["PF[$r,$f]"] = BENCHMARK_PRICE_START
        end
        for l in s.l
            ls = sum(_factor_supply(data, sam, r, f) for f in s.fp if f == l)
            starts["LS[$r,$l]"] = _flow_start(ls)
            starts["F[$r,$l]"] = _flow_start(ls)
            starts["WF[$r,$l]"] = BENCHMARK_PRICE_START
            starts["UE[$r,$l]"] = MIN_START_VALUE
        end
        yh = _flow_start(_regional_household_income(data, sam, r))
        for h in s.h
            starts["YH[$r,$h]"] = yh
            starts["YD[$r,$h]"] = yh
            starts["YC[$r,$h]"] = yh
            starts["Ysup[$r,$h]"] = yh
            starts["Sh[$r,$h]"] = _flow_start(0.10*yh)
            starts["u[$r,$h]"] = yh
            starts["HEN[$r,$h]"] = _flow_start(_fdemand(data, r; fd=h))
            starts["PHEN[$r,$h]"] = BENCHMARK_PRICE_START
        end
        gov = _flow_start(_fdemand(data, r; fd="GOV"))
        for gy in s.gy
            starts["YGOV[$r,$gy]"] = gov / max(length(s.gy),1)
        end
        starts["YGOV[$r]"] = gov
        starts["YH[$r]"] = yh
        starts["YD[$r]"] = yh
        starts["Sh[$r]"] = _flow_start(0.10*yh)
        starts["Sg[$r]"] = _flow_start(0.10*gov)
        starts["Sf[$r]"] = _flow_start(0.02*reg_abs)
        starts["YFD[$r]"] = _flow_start(_fdemand(data, r))
        for nm in ["GDPMP","GDPFC","GDPVA","RGDPMP","RGDPpc","EV","CV","Welf"]
            starts["$nm[$r]"] = _flow_start(reg_abs)
        end
        for pnm in ["PGDPMP","PGDPFC","PNUM","ROR","PT","PWAT"]
            starts["$pnm[$r]"] = BENCHMARK_PRICE_START
        end
        capsum = sum(_factor_supply(data, sam, r, f) for f in s.cap)
        landsum = sum(_factor_supply(data, sam, r, f) for f in s.lnd)
        watersum = sum(_factor_supply(data, sam, r, f) for f in s.wat)
        starts["Ks[$r]"] = _flow_start(capsum)
        starts["TKs[$r]"] = _flow_start(capsum)
        starts["TLand[$r]"] = _flow_start(landsum)
        starts["WAT[$r]"] = _flow_start(watersum)
        starts["TH2O[$r]"] = _flow_start(watersum)
        for lb in s.lb
            starts["LANDB[$r,$lb]"] = _flow_start(landsum / max(length(s.lb), 1))
            starts["XLB[$r,$lb]"] = _flow_start(landsum / max(length(s.lb), 1))
            starts["PLB[$r,$lb]"] = BENCHMARK_PRICE_START
        end
        for wb in s.wbnd
            starts["WATB[$r,$wb]"] = _flow_start(watersum / max(length(s.wbnd), 1))
            starts["H2OBnd[$r,$wb]"] = _flow_start(watersum / max(length(s.wbnd), 1))
            starts["H2OBndd[$r,$wb]"] = _flow_start(watersum / max(length(s.wbnd), 1))
            starts["PH2OBnd[$r,$wb]"] = BENCHMARK_PRICE_START
        end
        for em in s.em
            ev = _emissions(data, r; em=em)
            starts["EmiOth[$r,$em]"] = _flow_start(ev)
            starts["EmiTot[$r,$em]"] = _flow_start(ev)
            starts["EmiQ[$r,$em]"] = _flow_start(ev)
            starts["τEmi[$r,$em]"] = BENCHMARK_PRICE_START
            for a in s.a
                ea = _emissions(data, r; em=em, a=a)
                starts["EmiTotA[$r,$em,$a]"] = _flow_start(ea)
                starts["Emi[$r,$em,$a]"] = _flow_start(ea)
                starts["τEmi[$r,$em,$a]"] = BENCHMARK_PRICE_START
            end
        end
    end

    # Bilateral trade and world-price starts from commodity absorption/supply.
    for sr in s.r, d in s.r, i in s.i
        qd = _flow_start(_commodity_demand(data, sam, d, i) / max(length(s.r),1))
        qs = _flow_start(_commodity_supply(data, sam, sr, i) / max(length(s.r),1))
        for nm in ["XMT","IMDEM"]
            starts["$nm[$sr,$d,$i]"] = qd
        end
        for nm in ["XWs","XWd"]
            starts["$nm[$sr,$i,$d]"] = qs
        end
        for pnm in ["PMT","PWE","PWM","PDM","PWMG"]
            starts["$pnm[$sr,$i,$d]"] = BENCHMARK_PRICE_START
        end
    end

    starts["GLOBAL_Welf"] = _flow_start(sum(_regional_household_income(data, sam, r) for r in s.r))
    starts["EVG"] = starts["GLOBAL_Welf"]
    starts["CVG"] = starts["GLOBAL_Welf"]
    starts["SWF"] = starts["GLOBAL_Welf"]
    starts["NumPrice"] = BENCHMARK_PRICE_START
    starts["PNUM"] = BENCHMARK_PRICE_START
    return starts
end

function apply_initial_values!(m::JuMP.Model, data::EnvData, cal::EnvCalibration=calibrate(data); strict::Bool=false)
    starts = initial_values_from_excel(data, cal)
    sam = construct_sam(data)
    applied = 0
    derived = String[]
    missing = String[]
    for v in all_variables(m)
        n = name(v)
        val = get(starts, n, NaN)
        if isnan(val)
            base, idx = _split_varname(n)
            val = _calibrated_start_for_var(base, idx, data, cal, sam)
            push!(derived, n)
        end
        if isnan(val) || !isfinite(val)
            push!(missing, n)
            val = MIN_START_VALUE
        end
        set_start_value(v, _flow_start(val; floor=(_price_name(first(_split_varname(n))) ? 1.0e-6 : MIN_START_VALUE)))
        applied += 1
    end
    if strict && !isempty(missing)
        error("Missing finite Excel/SAM/calibration-derived start values for $(length(missing)) variables. First missing variable: $(first(missing))")
    end
    return Dict{String,Any}(
        "applied" => applied,
        "explicit_excel_sam" => length(starts),
        "derived_from_excel_sam_calibration" => length(derived),
        "unresolved" => length(missing),
        "derived_variables" => derived,
        "unresolved_variables" => missing,
    )
end
