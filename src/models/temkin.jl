struct TemkinApprox{T} <: IsothermModel{T}
    M::T
    K₀::T
    theta::T
    E::T
end

function sp_res(model::TemkinApprox, p, T)
    M, K₀, θ, E = model.M, model.K₀, model.theta, model.E
    K = K₀*exp(-E/(Rgas(model)*T))
    Kp = K*p
    return M*(log1p(Kp) + θ*(2*Kp + 1)/(2*(Kp + 1)*(Kp + 1)))
end

export TemkinApprox