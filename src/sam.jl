# === Function usage ===
# SAM construction, validation, and balance repair.
# Usage:
#   data = load_default_data()
#   sam = construct_sam(data)              # Excel-derived full SAM, balanced if needed
#   bal = check_sam_balance(sam)
#   assert_sam_balanced(sam)
#
# The package workbook includes the benchmark SAM in data/example_envcge_data.xlsx,
# sheet `sam`, with columns: row, col, value. Rows receive payments from columns.
# A balanced SAM has row_total == col_total for every account.
# ======================

function _sam_has_required_columns(sam::DataFrame)
    return all(Symbol(x) in propertynames(sam) for x in ("row", "col", "value"))
end

function _clean_sam(sam::DataFrame)
    _sam_has_required_columns(sam) || error("SAM must have columns: row, col, value")
    out = DataFrame(row=String[], col=String[], value=Float64[])
    for x in eachrow(sam)
        if !ismissing(x.row) && !ismissing(x.col) && !ismissing(x.value)
            r = strip(String(x.row)); c = strip(String(x.col)); v = _num(x.value)
            if r != "" && c != "" && abs(v) > 0.0
                push!(out, (r, c, v))
            end
        end
    end
    return out
end

function _full_sam_accounts(data::EnvData)
    s = data.sets
    accounts = String[]

    if nrow(data.sam) > 0 && all(Symbol(x) in propertynames(data.sam) for x in ("row", "col"))
        append!(accounts, [strip(String(x)) for x in data.sam.row if !ismissing(x) && strip(String(x)) != ""])
        append!(accounts, [strip(String(x)) for x in data.sam.col if !ismissing(x) && strip(String(x)) != ""])
    end

    for r in s.r
        append!(accounts, ["ACT:$r:$a" for a in s.a])
        append!(accounts, ["COM:$r:$i" for i in s.i])
        append!(accounts, ["FAC:$r:$f" for f in s.fp])
        append!(accounts, ["HH:$r:$h" for h in s.h])
        append!(accounts, ["GOV:$r:$g" for g in (isempty(s.gov) ? ["GOV"] : s.gov)])
        append!(accounts, ["INV:$r:$v" for v in (isempty(s.inv) ? ["INV"] : s.inv)])
    end

    return sort(unique(accounts))
end

function _sam_accounts_and_matrix(sam::DataFrame; accounts::Union{Nothing,Vector{String}}=nothing)
    sam = _clean_sam(sam)
    accounts = accounts === nothing ? sort(union(String.(sam.row), String.(sam.col))) : sort(unique(accounts))
    idx = Dict(a => k for (k, a) in enumerate(accounts))
    M = zeros(Float64, length(accounts), length(accounts))

    for x in eachrow(sam)
        r = String(x.row); c = String(x.col)
        if haskey(idx, r) && haskey(idx, c)
            M[idx[r], idx[c]] += Float64(x.value)
        end
    end

    return accounts, M
end

function _matrix_to_sam(accounts::Vector{String}, M::AbstractMatrix{<:Real}; drop_tol=1e-12)
    rows = String[]; cols = String[]; vals = Float64[]
    for i in eachindex(accounts), j in eachindex(accounts)
        v = Float64(M[i, j])
        if drop_tol <= 0.0 || abs(v) > drop_tol
            push!(rows, accounts[i]); push!(cols, accounts[j]); push!(vals, v)
        end
    end
    return DataFrame(row=rows, col=cols, value=vals)
end

function _complete_sam(sam::DataFrame, accounts::Vector{String}; drop_tol=0.0)
    _, M = _sam_accounts_and_matrix(sam; accounts=accounts)
    return _matrix_to_sam(accounts, M; drop_tol=drop_tol)
end

"""
    check_sam_balance(sam; atol=1e-9, accounts=nothing)

Return account-level SAM balance diagnostics. Rows are receipts and columns are
payments/expenditures. A SAM is balanced when each account's row total equals
its column total.
"""
function check_sam_balance(sam::DataFrame; atol=1e-9, accounts::Union{Nothing,Vector{String}}=nothing)
    accounts, M = _sam_accounts_and_matrix(sam; accounts=accounts)
    row_total = vec(sum(M; dims=2))
    col_total = vec(sum(M; dims=1))
    gap = row_total .- col_total
    return DataFrame(
        account = accounts,
        row_total = row_total,
        col_total = col_total,
        gap = gap,
        abs_gap = abs.(gap),
        ok = abs.(gap) .<= atol,
    )
end

"""
    balance_sam(sam; atol=1e-9, max_iter=10_000, tol=1e-10, support_epsilon=1e-12,
                accounts=nothing, keep_full_square=false)

Balance the full Excel-derived SAM using an RAS/IPF cross-entropy update.
For each account, the target benchmark total is the midpoint of the original
row and column totals. No synthetic SAM is created and no partial account subset
is balanced.
"""
function balance_sam(sam::DataFrame; atol=1e-9, max_iter::Int=10_000, tol=1e-10,
                     support_epsilon=1e-12, accounts::Union{Nothing,Vector{String}}=nothing,
                     keep_full_square::Bool=false)
    accounts, M = _sam_accounts_and_matrix(sam; accounts=accounts)
    bal0 = check_sam_balance(sam; atol=atol, accounts=accounts)
    all(bal0.ok) && return keep_full_square ? _matrix_to_sam(accounts, M; drop_tol=0.0) : _matrix_to_sam(accounts, M)

    row_tot = vec(sum(M; dims=2))
    col_tot = vec(sum(M; dims=1))
    target = 0.5 .* (row_tot .+ col_tot)
    sum(target) > 0.0 || error("Cannot balance an empty SAM.")

    for k in eachindex(accounts)
        if target[k] > 0.0 && M[k, k] == 0.0
            M[k, k] = support_epsilon
        end
    end

    for _ in 1:max_iter
        rs = vec(sum(M; dims=2))
        for i in eachindex(accounts)
            if target[i] > 0.0 && rs[i] > 0.0
                M[i, :] .*= target[i] / rs[i]
            end
        end

        cs = vec(sum(M; dims=1))
        for j in eachindex(accounts)
            if target[j] > 0.0 && cs[j] > 0.0
                M[:, j] .*= target[j] / cs[j]
            end
        end

        max_gap = max(maximum(abs.(vec(sum(M; dims=2)) .- target)),
                      maximum(abs.(vec(sum(M; dims=1)) .- target)))
        if max_gap <= max(tol, atol / 10)
            out = _matrix_to_sam(accounts, M; drop_tol=keep_full_square ? 0.0 : 1e-12)
            final = check_sam_balance(out; atol=atol, accounts=accounts)
            all(final.ok) || error("SAM balancing failed; maximum gap = $(maximum(abs.(final.gap)))")
            return out
        end
    end

    error("SAM balancing did not converge after $(max_iter) iterations.")
end

function construct_sam(data::EnvData; repair::Bool=true, atol=1e-9, complete::Bool=true)
    if nrow(data.sam) == 0
        src = get(data.par, "source_excel", "<unknown workbook>")
        error("No SAM rows were loaded from the Excel `sam` worksheet in $(src). Please provide columns row, col, value.")
    end

    accounts = _full_sam_accounts(data)
    sam = complete ? _complete_sam(data.sam, accounts; drop_tol=0.0) : _clean_sam(data.sam)

    if repair && !all(check_sam_balance(sam; atol=atol, accounts=accounts).ok)
        sam = balance_sam(sam; atol=atol, accounts=accounts, keep_full_square=complete)
    end

    data.sam = sam
    data.par["sam_accounts"] = accounts
    data.par["sam_source"] = get(data.par, "source_excel", "example_envcge_data.xlsx")
    return sam
end

function assert_sam_balanced(sam::DataFrame; atol=1e-9)
    bal = check_sam_balance(sam; atol=atol)
    if !all(bal.ok)
        bad = bal[.!bal.ok, :]
        error("SAM is not balanced. Maximum absolute gap = $(maximum(abs.(bad.gap))). Inspect check_sam_balance(sam).")
    end
    return true
end
