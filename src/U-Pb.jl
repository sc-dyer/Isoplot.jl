# Decay constants:
const λ238U = log(2)/(4.4683e3 ± 0.0024e3) # Jaffey, 1/Myr
const λ235U = 9.8569E-4 ± 0.0110E-4/2 # Schoene, 1/Myr
const λ235U_internal = 9.8569E-4 ± 0.0017E-4/2 # Schoene, 1/Myr, including only internal uncertainty [U-238 years]
export λ238U, λ235U

const λ235U_jaffey = log(2)/(7.0381e2 ± 0.0048e2) # Jaffey, 1/Myr
export λ235U_jaffey

const R238_235 = 137.818 ± 0.0225 #U238/U235 from Hiess et al 2012
"""
```
struct UPbAnalysis{T} <: Analysis{T}
```
Core type for U-Pb analyses.
Has fields
```
μ :: Vector{T<:AbstractFloat}
σ :: Vector{T<:AbstractFloat}
Σ :: Matrix{T<:AbstractFloat}
```
where `μ` contains the means
```
μ = [r²⁰⁷Pb²³⁵U, r²⁰⁶Pb²³⁸U]
```
where `σ` contains the standard deviations
```
σ = [σ²⁰⁷Pb²³⁵U, σ²⁰⁶Pb²³⁸U]
```
and Σ contains the covariance matrix
```
Σ = [σ₇_₅^2 σ₇_₅*σ₃_₈
     σ₇_₅*σ₃_₈ σ₃_₈^2]
```
If `σ` is not provided, it will be automatically calculated from `Σ`,
given that `σ.^2 = diag(Σ)`.
"""
struct UPbAnalysis{T} <: Analysis{T}
    μ::Vector{T}
    σ::Vector{T}
    Σ::Matrix{T}
end


"""
```julia
UPbAnalysis(r²⁰⁷Pb²³⁵U, σ²⁰⁷Pb²³⁵U, r²⁰⁶Pb²³⁸U, σ²⁰⁶Pb²³⁸U, correlation; T=Float64)
```
Construct a `UPbAnalysis` object from individual isotope ratios and (1-sigma!) uncertainties.

### Examples
```
julia> UPbAnalysis(22.6602, 0.0175, 0.40864, 0.00017, 0.83183)
UPbAnalysis{Float64}([22.6602, 0.40864], [0.00030625000000000004 2.4746942500000003e-6; 2.4746942500000003e-6 2.8900000000000004e-8])
```
"""
function UPbAnalysis(r²⁰⁷Pb²³⁵U::Number, σ²⁰⁷Pb²³⁵U::Number, r²⁰⁶Pb²³⁸U::Number, σ²⁰⁶Pb²³⁸U::Number, correlation::Number; T=Float64)
    cov = σ²⁰⁷Pb²³⁵U * σ²⁰⁶Pb²³⁸U * correlation
    Σ = T[σ²⁰⁷Pb²³⁵U^2  cov
          cov  σ²⁰⁶Pb²³⁸U^2]
    σ = T[σ²⁰⁷Pb²³⁵U, σ²⁰⁶Pb²³⁸U]
    μ = T[r²⁰⁷Pb²³⁵U, r²⁰⁶Pb²³⁸U]
    UPbAnalysis(μ, σ, Σ)
end
UPbAnalysis(μ::Vector{T}, Σ::Matrix{T}) where {T} = UPbAnalysis{T}(μ, sqrt.(diag(Σ)), Σ)

# 75 and 68 ages
function age(d::UPbAnalysis;decayconstant235 = :schoene, decayconstant238 =:jaffey)
    a75 = age75(d,decayconstant = decayconstant235)
    a68 = age68(d,decayconstant = decayconstant238)
    return a75, a68
end

function age68(d::UPbAnalysis;decayconstant = :jaffey)
    λ = 0
    if decayconstant == :jaffey
        λ = λ238U
    elseif typeof(decayconstant) <: Number
        λ = decayconstant
    else
        throw(ArgumentError("$decayconstant is not a valid argument for decayconstant, please refer to documentation for options"))
    end
    
    log(1 + d.μ[2] ± d.σ[2])/λ
end
function age75(d::UPbAnalysis;decayconstant = :schoene)
    λ = 0
    if decayconstant == :jaffey
        λ = λ235U_jaffey
    elseif decayconstant == :schoene
        λ = λ235U
    elseif decayconstant == :schoene_internal
        λ = λ235U_internal
    elseif typeof(decayconstant) <: Number
        λ = decayconstant
    else
        throw(ArgumentError("$decayconstant is not a valid argument for decayconstant, please refer to documentation for options"))
    end
    log(1 + d.μ[1] ± d.σ[1])/λ
end
# Percent discordance
function discordance(d::UPbAnalysis;decayconstant235 = :schoene, decayconstant238 =:jaffey)
    μ75 = val(age75(d,decayconstant=decayconstant235))
    μ68 = val(age68(d,decayconstant=decayconstant238))
    return (μ75 - μ68) / μ75 * 100
end

# Add custom methods to Base.rand to sample from a UPbAnalysis
Base.rand(d::UPbAnalysis) = rand(MvNormal(d.μ, d.Σ))
Base.rand(d::UPbAnalysis, n::Integer) = rand(MvNormal(d.μ, d.Σ), n)
Base.rand(d::UPbAnalysis, dims::Dims) = rand(MvNormal(d.μ, d.Σ), dims)

function stacey_kramers(t)
    if 3700 <= t < 4570
        t0 = 3700
        r64 = 11.152
        r74 = 12.998
        U_Pb = 7.19
    elseif t < 3700
        t0 = 0
        r64 = 18.700
        r74 = 15.628
        U_Pb = 9.74
    else
        t0 = NaN
        r64 = NaN
        r74 = NaN
        U_Pb = NaN
    end

    r64 -= ((exp(val(λ238U)*t)-1) - (exp(val(λ238U)*t0)-1)) * U_Pb
    r74 -= ((exp(val(λ238U)*t)-1) - (exp(val(λ238U)*t0)-1)) * U_Pb/137.818

    return r64, r74
end

struct UPbPbAnalysis{T} <: Analysis{T}
    μ::Vector{T}
    σ::Vector{T}
    Σ::Matrix{T}
end

function UPbPbAnalysis( r²⁰⁶Pb²³⁸U::Number, σ²⁰⁶Pb²³⁸U::Number, r²⁰⁷Pb²⁰⁶Pb::Number, σ²⁰⁷Pb²⁰⁶Pb::Number, correlation::Number; T=Float64)
    cov = σ²⁰⁶Pb²³⁸U *  σ²⁰⁷Pb²⁰⁶Pb * correlation
    Σ = T[σ²⁰⁶Pb²³⁸U^2  cov
          cov   σ²⁰⁷Pb²⁰⁶Pb^2]
    σ = T[σ²⁰⁶Pb²³⁸U,  σ²⁰⁷Pb²⁰⁶Pb]
    μ = T[r²⁰⁶Pb²³⁸U, r²⁰⁷Pb²⁰⁶Pb]
    UPbPbAnalysis(μ, σ, Σ)
end
UPbPbAnalysis(μ::Vector{T}, Σ::Matrix{T}) where {T} = UPbPbAnalysis{T}(μ, sqrt.(diag(Σ)), Σ)

ratioPbPb(age,λ235,λ238) = 1/R238_235.val*(exp(λ235*age)-1)/(exp(λ238*age)-1)



function age68(d::UPbPbAnalysis)
    log(1 + d.μ[1] ± d.σ[1])/λ238U
end


function age76(d::UPbPbAnalysis,tmin,tmax)
    
    agefun(ages) = ratioPbPb.(ages,λ235U_jaffey.val,λ238U.val) .- d.μ[2]
    sol = nlsolve(agefun,[tmin,tmax])
    return sol.zero[1]
    # r238_235*(d.μ[2]±d.σ[2])
end