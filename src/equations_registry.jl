# === ENVISAGE equation registry ===
# This file keeps two registries:
#   1. equation_registry(): implemented within-period JuMP/PATH equation families.
#   2. envisage_document_equation_registry(): numbering from ENVISAGE v10.01 documentation.
#
# Numbering follows ENVISAGE10.01_Documentation.pdf, Chapter 3:
#   P-1:P-48 production
#   S-1:S-14 commodity supply and electricity supply
#   Y-1:Y-20 income/accounts
#   D-1:D-37 final demand
#   T-1:T-32 trade and transport margins
#   E-1:E-2 goods-market equilibrium
#   F-1:F-55 factor markets
#   EM-1:EM-8 emissions accounting and price-regime equations; these are printed as E-1:E-8 in the document
#
# The document reuses the label E for two different sections.  To keep Julia
# dictionaries unique while preserving the printed numbering, this code uses
# E-* for goods equilibrium and EM-* for emissions, with each record storing
# the original printed label.
# ===============================

const ENVISAGE_DOC_BLOCKS = OrderedDict(
    "P"  => (1, 48, "Production block"),
    "S"  => (1, 14, "Commodity supply and electricity supply"),
    "Y"  => (1, 20, "Income block"),
    "D"  => (1, 37, "Final demand block"),
    "T"  => (1, 32, "International trade block"),
    "GE" => (1, 2,  "Goods-market equilibrium; original printed labels E-1:E-2"),
    "F"  => (1, 55, "Factor markets"),
    "M"  => (1, 39, "National accounts and model closure"),
    "G"  => (1, 12, "Model dynamics"),
    "C"  => (1, 2,  "Appendix C capital-stock dynamics"),
    "EM" => (1, 5,  "Emissions accounting; original printed labels E-1:E-5"),
)

function nest_registry()
    OrderedDict(
        "P-1:P-5" => "Vintage unit costs, tax-adjusted unit cost, top XPX/GHG CES and dual unit cost.",
        "P-6:P-8" => "Top production CES: ND1 and VA demand and PXP dual price.",
        "P-9:P-17" => "Crop/livestock/default middle nests VA1, VA2, LAB1, KEF, ND2, land and their dual prices.",
        "P-18:P-29" => "KEF/KF/KSW/KS decomposition: energy, capital, skilled labor, natural resource, water and dual prices.",
        "P-30:P-37" => "Labor bundles, intermediate demand bundles and water bundle terminal demands.",
        "P-38:P-48" => "Energy nest: electricity/non-electric, coal/oil/gas and Armington energy terminal demand.",
        "S-1:S-14" => "Make matrix / CET activity supply, commodity aggregation and domestic electricity power-bundle equations.",
        "Y-1:Y-20" => "Depreciation, trust/remittances/ODA, household income, disposable income, tax revenues and investment finance.",
        "D-1:D-37" => "LES/ELES/AIDADS/CDE household demand, energy consumer nests, saving, transition matrix and other final demand.",
        "T-1:T-32" => "Armington domestic/import demand, bilateral import allocation, CET export supply, FOB/CIF prices and trade margins.",
        "E-1:E-2" => "Domestic and bilateral goods-market equilibrium.",
        "F-1:F-55" => "Labor, capital, land, natural-resource, water, factor taxes and factor price equations.",
        "M-1:M-39" => "National accounts and model closure equations from ENVISAGE §3.9.",
        "G-1:G-12" => "Recursive-dynamic update equations from ENVISAGE Chapter 4.",
        "C-1:C-2" => "Appendix C.1 investment growth factor and multi-period capital accumulation.",
        "EM-1:EM-8" => "Consumption-, factor-, process-based emissions, regional/global emissions, caps, tax mapping and quota trade; original document labels are E-1:E-8."
    )
end

function _range_registry!(eq::OrderedDict{String,String}, prefix::String, n1::Int, n2::Int, desc::String)
    for k in n1:n2
        eq["$prefix-$k"] = "$desc equation $prefix-$k"
    end
    return eq
end

function equation_registry()
    eq = OrderedDict{String,String}()

    p = [
        "PX vintage-share aggregate unit cost value balance",
        "PXv tax-adjusted vintage unit cost",
        "XPX demand from top CES nest",
        "XGHG non-CO2 GHG service demand from top CES nest",
        "UC top CES dual unit cost including GHG bundle",
        "ND1 intermediate bundle demand excluding energy/special inputs",
        "VA value-added-energy-special bundle demand",
        "PXP dual price of output net of GHG bundle",
        "VA1 middle-nest demand",
        "VA2 middle-nest demand",
        "LAB1 unskilled labor bundle demand",
        "KEF capital-skilled-energy-resource-water bundle demand",
        "ND2 special intermediate bundle demand (fertilizer/feed)",
        "XFlnd land factor demand",
        "PVA dual price",
        "PVA1 dual price",
        "PVA2 dual price",
        "KF capital-energy-factor bundle demand",
        "XNRG energy bundle demand in production",
        "PKEF dual price",
        "KSW capital-skilled-water bundle demand",
        "XFnrs natural resource factor demand",
        "PKF dual price",
        "KS capital-skilled labor bundle demand",
        "XWAT water bundle demand in production",
        "PKSW dual price",
        "K capital demand by vintage",
        "LAB2 skilled labor bundle demand",
        "PKS dual price",
        "XF labor terminal demand",
        "PLAB1 dual price",
        "PLAB2 dual price",
        "XA intermediate Armington demand",
        "PND1 dual price",
        "PND2 dual price",
        "XF water terminal demand",
        "PWAT dual price",
        "XAely electricity demand in production energy nest",
        "XNELY non-electric energy demand",
        "PNRG dual price",
        "XAcoa coal demand",
        "XOLG oil-gas bundle demand",
        "PNELY dual price",
        "XAoil oil demand",
        "XAgas gas demand",
        "POLG dual price",
        "XANRG energy commodity terminal demand",
        "PANRG dual price",
    ]
    for (k,label) in enumerate(p); eq["P-$k"] = label; end

    s = [
        "CET activity output allocation to supplied commodity",
        "activity output value balance",
        "activity-commodity output tax wedge",
        "CES aggregation of commodity supply across activities",
        "commodity supply value balance / market price",
        "electricity T&D/auxiliary demand",
        "aggregate power bundle demand",
        "electricity aggregate supply price",
        "power-bundle demand",
        "power-bundle CES price index",
        "power-bundle value balance",
        "generation technology demand within power bundle",
        "generation technology/bundle price index",
        "power-bundle value balance across generation technologies",
    ]
    for (k,label) in enumerate(s); eq["S-$k"] = label; end

    y = [
        "depreciation income",
        "factor income transferred to trust or households",
        "capital income transferred to trust",
        "aggregate trust income",
        "household trust income allocation",
        "labor remittances",
        "outward ODA",
        "global ODA",
        "regional ODA receipts",
        "household income",
        "household disposable income",
        "production/output tax revenue",
        "factor tax revenue",
        "indirect/sales tax revenue",
        "import tariff revenue",
        "export tax revenue",
        "household waste-tax revenue",
        "carbon-tax revenue",
        "direct-tax revenue",
        "investment finance / savings-investment balance",
    ]
    for (k,label) in enumerate(y); eq["Y-$k"] = label; end

    _range_registry!(eq, "D", 1, 37, "final-demand/household-demand")
    _range_registry!(eq, "T", 1, 32, "trade/transport")
    eq["E-1"] = "domestic good market equilibrium"
    eq["E-2"] = "bilateral export/import market equilibrium"
    _range_registry!(eq, "F", 1, 55, "factor-market")
    _range_registry!(eq, "M", 1, 31, "national-account/model-closure")
    # G-1:G-12 are recursive state-update formulas, not within-period PATH MCP rows.
    _range_registry!(eq, "EM", 1, 8, "emissions accounting and price regimes")
    return eq
end

function envisage_document_equation_registry()
    eq = OrderedDict{String,NamedTuple}()
    for (prefix,(lo,hi,block)) in ENVISAGE_DOC_BLOCKS
        for k in lo:hi
            printed = prefix == "GE" ? "E-$k" : prefix == "EM" ? "E-$k" : "$prefix-$k"
            eq["$prefix-$k"] = (printed_label=printed, block=block, file=equation_source_file("$prefix-$k"))
        end
    end
    return eq
end

function equation_source_file(label::AbstractString)
    p = split(String(label), '-')[1]
    if p == "P"; return "src/production.jl"
    elseif p == "S"; return "src/supply.jl"
    elseif p == "Y"; return "src/income.jl"
    elseif p == "D"; return "src/demand.jl"
    elseif p == "T"; return "src/trade.jl"
    elseif p == "GE"; return "src/markets.jl"
    elseif p == "F"; return "src/factors.jl"
    elseif p == "M"; return "src/closure.jl"
    elseif p == "G"; return "src/dynamics.jl"
    elseif p == "EM"; return "src/emissions.jl"
    else; return "src/equations_registry.jl"
    end
end

function equation_coverage_report()
    doc = envisage_document_equation_registry()
    impl = equation_registry()
    return OrderedDict(
        "document_equations" => length(doc),
        "implemented_registry_equations" => length(impl),
        "document_blocks" => ENVISAGE_DOC_BLOCKS,
        "note" => "ENVISAGE documentation reuses printed E labels. This package uses E-* for goods equilibrium and EM-* for emissions while preserving printed_label in the document registry."
    )
end
