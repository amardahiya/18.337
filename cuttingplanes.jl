using JuMP

# f_i(x) = 0.5(x-i)^2
# returns subderivative in the form 
# (a,b) -> ax + b = f'(z)*x + (f(z)-x*f'(x)) (from f(z) + f'(z)(x-z))
@everywhere function f(input)
    x,i = input
    sleep(0.2+rand()/4) # simulate computation time
    return ((x-i),0.5(x-i)^2-x*(x-i))
end


function cp(N::Integer)
    x = 1/2
    answer = (N+1)/2
    println("Solving model with n = $N, initial solution: $x")
    println("Optimal solution should be $answer")

    # storage for subgradients
    subgradients = {}

    niter = 0
    while abs(x-answer) > 1e-4 # cheating
        results = map(f,[(x,i) for i in 1:N])
        push!(subgradients, results)
        x = optimize(N,subgradients)
        println("Model minimizer: ", x)
        niter += 1
    end
    println("Converged in $niter iterations")
end

function optimize(N,subgradients)
    m = Model(:Min)

    @defVar(m, r[1:N])
    @defVar(m, 0 <= x <= 1000) # known bounds on solution

    @setObjective(m, sum{ r[i], i = 1:N } )

    for subt in subgradients
        for i in 1:N
            a,b = subt[i]
            @addConstraint(m, r[i] >=  a*x + b )
        end
    end

    status = solve(m)
    @assert status == :Optimal

    return getValue(x)
end

@time cp(int(ARGS[1]))
