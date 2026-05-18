# === Function usage ===
# CES, CET, Leontief, and supply-curve helper functions.
# Usage:
#   p = ces_price([0.4,0.6], [1.0,1.2], 0.8)
#   x = ces_demand(100.0, p, 1.2, 0.6, 0.8)
#   q = leontief_demand(100.0, 0.25)
#   px = cet_price([0.5,0.5], [1.0,1.1], 2.0)
#   s = logistic_supply(1.1, 1.0, 100.0, 5.0)
# ======================

function ces_price(alpha, p, sigma; A=1.0, lambda=nothing)
    n = length(alpha); lambdav = lambda === nothing ? ones(n) : lambda
    if abs(sigma - 1.0) < 1e-10
        return prod((p[j]/lambdav[j])^alpha[j] for j in 1:n) / A
    elseif abs(sigma) < 1e-10
        return sum(alpha[j] * p[j] / lambdav[j] for j in 1:n) / A
    else
        return (sum(alpha[j]*(p[j]/lambdav[j])^(1-sigma) for j in 1:n))^(1/(1-sigma)) / A
    end
end

function ces_demand(q, pc, pi, alphai, sigma; A=1.0, lambdai=1.0)
    return alphai * (A*lambdai)^(sigma-1) * (pc/pi)^sigma * q
end

function leontief_demand(q, acoef)
    return acoef*q
end

function cet_price(theta, p, psi; A=1.0)
    if abs(psi + 1.0) < 1e-10
        return prod(p[j]^theta[j] for j in eachindex(theta)) / A
    else
        return (sum(theta[j]*p[j]^(1+psi) for j in eachindex(theta)))^(1/(1+psi)) / A
    end
end

function cet_supply(q, px, pi, θi, psi; A=1.0)
    return θi * A^(psi+1) * (pi/px)^psi * q
end

function logistic_supply(price, p0, qmax, η)
    return qmax / (1 + exp(-η*(price/p0 - 1)))
end

function isoelastic_supply(price, p0, q0, η)
    return q0 * (price/p0)^η
end
