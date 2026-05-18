# === Function usage ===
# Excel and package-path input routines.
# Usage:
#   path = default_excel_path()
#   data = load_excel_data(path)
#   data = load_default_data()
#
# Expected workbook location in this package:
#   data/example_envcge_data.xlsx
#
# The reader loads workbook sheets into data.tables and constructs EnvSets from
# the `sets` sheet.  Use data.tables["sheet_name"] to inspect raw sheets.
# ======================

# Excel input utilities for EnvCGE.
# The default workbook is expected at: <package root>/data/example_envcge_data.xlsx

const DEFAULT_EXCEL_FILE = "example_envcge_data.xlsx"

function package_root()
    return normpath(joinpath(@__DIR__, ".."))
end

function data_dir()
    return normpath(joinpath(package_root(), "data"))
end

function default_excel_path()
    return normpath(joinpath(data_dir(), DEFAULT_EXCEL_FILE))
end

function _normalise_name(x)
    return lowercase(strip(String(x)))
end

function _find_sheet(workbook, desired::AbstractString)
    wanted = _normalise_name(desired)
    for name in XLSX.sheetnames(workbook)
        if _normalise_name(name) == wanted
            return name
        end
    end
    return nothing
end

function _readsheet(path::AbstractString, sheet::AbstractString)
    if !isfile(path)
        error("Excel data file not found: $(path)")
    end
    xf = XLSX.readxlsx(path)
    actual = _find_sheet(xf, sheet)
    actual === nothing && return DataFrame()
    table = XLSX.gettable(xf[actual]; first_row=1, infer_eltypes=true)
    return DataFrame(table)
end

function _stringcol(df::DataFrame, name::AbstractString; default=String[])
    s = Symbol(name)
    if s ∉ propertynames(df)
        return default
    end
    return [strip(String(x)) for x in df[!, s] if !ismissing(x) && strip(String(x)) != ""]
end

function _num(x; default=0.0)
    if x === nothing || ismissing(x)
        return default
    elseif x isa Number
        return Float64(x)
    else
        y = tryparse(Float64, strip(String(x)))
        return y === nothing ? default : y
    end
end

function _sets_from_sheet(setsdf::DataFrame)
    function getset(name)
        isempty(setsdf) && return String[]
        if (:set in propertynames(setsdf)) && (:value in propertynames(setsdf))
            return [strip(String(v)) for v in setsdf.value[setsdf.set .== name] if !ismissing(v) && strip(String(v)) != ""]
        elseif Symbol(name) in propertynames(setsdf)
            return _stringcol(setsdf, name)
        else
            return String[]
        end
    end
    aa = getset("aa")
    a = getset("a")
    acr = getset("acr")
    alv = getset("alv")
    ax = getset("ax")
    elya = getset("elya")
    ely = getset("ely")
    etd = getset("etd")
    z = getset("z")
    i = getset("i")
    inum = getset("inum")
    k = isempty(getset("k")) ? i : getset("k")
    nrg = getset("nrg")
    fp = !isempty(getset("fp")) ? getset("fp") : getset("f")
    f = fp
    l = getset("l")
    ul = getset("ul")
    sl = getset("sl")
    cap = getset("cap")
    lnd = getset("lnd")
    nrs = getset("nrs")
    wat = getset("wat")
    fd = getset("fd")
    h = getset("h")
    gov = getset("gov")
    inv = getset("inv")
    fdc = !isempty(getset("fdc")) ? getset("fdc") : setdiff(fd, h)
    gy = getset("gy")
    itax = getset("itax"); ptax = getset("ptax"); mtax = getset("mtax"); etax = getset("etax")
    vtax = getset("vtax"); ctax = getset("ctax"); dtax = getset("dtax")
    r = getset("r")
    rnum = getset("rnum")
    rres = getset("rres")
    em = getset("em")
    v = getset("v")
    pb = getset("pb")
    lb = getset("lb")
    wbnd = getset("wbnd")
    t = getset("t")
    return EnvSets(aa,a,acr,alv,ax,elya,ely,etd,z,i,inum,k,nrg,fp,f,l,ul,sl,cap,lnd,nrs,wat,fd,fdc,h,gov,inv,gy,itax,ptax,mtax,etax,vtax,ctax,dtax,r,rnum,rres,em,v,pb,lb,wbnd,t)
end



function _truthy(x)
    if x === nothing || ismissing(x)
        return false
    elseif x isa Bool
        return x
    elseif x isa Number
        return x != 0
    else
        y = lowercase(strip(String(x)))
        return y in ["true", "t", "yes", "y", "1", "active"]
    end
end

function _cellstr(row, name::Symbol; default="")
    if name ∉ propertynames(row) || row[name] === nothing || ismissing(row[name])
        return default
    end
    return strip(String(row[name]))
end

function _closure_rules(df::DataFrame)
    rules = Vector{Dict{String,Any}}()
    isempty(df) && return rules
    for row in eachrow(df)
        if _truthy(row[:active])
            area = _cellstr(row, :closure_area)
            opt  = _cellstr(row, :option)
            var  = uppercase(strip(_cellstr(row, :variable)))
            # CAP is a SAM/factor member, not a JuMP closure variable.
            # Preserve CAP in the `factor` selector, but never leave CAP in the
            # `variable` field because m[:CAP] is not declared.
            if var == "CAP"
                larea = lowercase(area); lopt = lowercase(opt)
                var = (occursin("emission", larea) || occursin("cap", lopt)) ? "EMICAP" : "K"
            end
            push!(rules, Dict{String,Any}(
                "closure_area" => area,
                "option"       => opt,
                "variable"     => var,
                "status"       => lowercase(_cellstr(row, :status; default="fixed")),
                "region"       => uppercase(strip(_cellstr(row, :region; default="ALL"))),
                "household"    => _cellstr(row, :household; default="ALL"),
                "factor"       => uppercase(strip(_cellstr(row, :factor; default="ALL"))),
                "activity"     => _cellstr(row, :activity; default="ALL"),
                "emission"     => uppercase(strip(_cellstr(row, :emission; default="ALL"))),
                "value"        => (:value in propertynames(df) && !ismissing(row[:value])) ? _num(row[:value]; default=NaN) : NaN,
                "description"  => _cellstr(row, :description)
            ))
        end
    end
    return rules
end

function load_excel_data(path::AbstractString=default_excel_path())
    wanted = [
        "sets", "sam", "io", "make", "use", "final_demand", "factor_demand", "trade",
        "elasticities", "shares", "taxes", "emissions", "climate", "dynamics",
        "nests", "closures", "parameters", "benchmark"
    ]
    tables = Dict{String,DataFrame}(sheet => _readsheet(path, sheet) for sheet in wanted)
    sets = _sets_from_sheet(tables["sets"])
    par = Dict{String,Any}(
        "source_excel" => normpath(path),
        "data_dir" => dirname(normpath(path)),
        "available_sheets" => XLSX.sheetnames(XLSX.readxlsx(path)),
        "closure_rules" => _closure_rules(tables["closures"])
    )
    return EnvData(sets, tables, par, tables["sam"])
end

function load_default_data()
    return load_excel_data(default_excel_path())
end
