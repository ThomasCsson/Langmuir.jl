#nlsolve functionality
"""
    function nlsolve(f!,x0,method=TrustRegion(Newton(), Dogleg()), options=NEqOptions(),chunk = ForwardDiff.Chunk{2}())


Given a function `f!(result,x)` that returns a system of equations,
`nlsolve(f!,x0)` returns a `NLSolvers.ConvergenceInfo` struct that contains the results of the non-linear solving procedure.

Uses `NLSolvers.jl` as backend, the jacobian is calculated with `ForwardDiff.jl`, with the specified `chunk` size

To obtain the underlying solution vector, use [`x_sol`](@ref)

To see available solvers and options, check `NLSolvers.jl`
"""
function nlsolve(f!,x0,method=TrustRegion(Newton(), Dogleg()),options=NEqOptions(),chunk = ForwardDiff.Chunk{2}())
    vector_objective = autoVectorObjective(f!,x0,chunk)
    nl_problem = NEqProblem(vector_objective; inplace = _inplace(x0))
    return nlsolve(nl_problem, x0,method, options)
end

function nlsolve(nl_problem::NEqProblem,x0,method =TrustRegion(Newton(), NWI()),options=NEqOptions())
    return NLSolvers.solve(nl_problem, x0,method, options)
end

function autoVectorObjective(f!,x0,chunk)
    Fcache = x0 .* false
    jconfig = ForwardDiff.JacobianConfig(f!,x0,x0,chunk)
    function j!(J,x)
        ForwardDiff.jacobian!(J,f!,Fcache,x,jconfig)
        J
    end
    function fj!(F,J,x)
        ForwardDiff.jacobian!(J,f!,F,x,jconfig)
        F,J
    end
    function jv!(x)
        return nothing
    end
    return NLSolvers.VectorObjective(f!,j!,fj!,jv!)
end

_inplace(x0) = true
_inplace(x0::SVector) = false

function autoVectorObjective(f!,x0::StaticArrays.SVector{2,T},chunk) where T
    f(x) = f!(nothing,x) #we assume that the F argument is unused in static arrays
    j(J,x) = ForwardDiff.jacobian(f,x)
    fj(F,J,x) = FJ_ad(f,x)
    return NLSolvers.VectorObjective(f!,j,fj,nothing)
end

function autoVectorObjective(f!,x0::StaticArrays.SVector{3,T},chunk) where T
    f(x) = f!(nothing,x) #we assume that the F argument is unused in static arrays
    j(J,x) = ForwardDiff.jacobian(f,x)
    fj(F,J,x) = FJ_ad(f,x)
    return NLSolvers.VectorObjective(f!,j,fj,nothing)
end

function autoVectorObjective(f!,x0::StaticArrays.SVector,chunk)
    f(x) = f!(nothing,x) #we assume that the F argument is unused in static arrays
    j(J,x) = ForwardDiff.jacobian(f,x)
    fj(F,J,x) = FJ_ad(f,x)
    return NLSolvers.VectorObjective(f,j,fj,nothing)
end

#= only_fj!: NLsolve.jl legacy form:

function only_fj!(F, J, x)
    # shared calculations begin
    # ...
    # shared calculation end
    if !(F == nothing)
        # mutating calculations specific to f! goes here
    end
    if !(J == nothing)
        # mutating calculations specific to j! goes
    end
end
=#
function only_fj!(fj!::T) where T
    function _f!(F,x)
        fj!(F,nothing,x)
        F
    end

    function _fj!(F,J,x)
        fj!(F,J,x)
        F,J
    end

    function _j!(J,x)
        fj!(nothing,J,x)
        J
    end
    return NLSolvers.VectorObjective(_f!,_j!,_fj!,nothing) |> NEqProblem
end