using Base.Meta

immutable Variable
    index::Int
end

# Represents sum(coefficients[i]*variables[i] for i in ...) + offset
type AffineExpression
    variables::Vector{Variable}
    coefficients::Vector{Float64}
    offset::Float64
end

Base.zero(::Type{AffineExpression}) = AffineExpression(Variable[],Float64[],0.0)
Base.:*(c::Float64,v::Variable) = AffineExpression([v],[c],0.0)
function Base.:+(aff1::AffineExpression,aff2::AffineExpression)
    return AffineExpression([aff1.variables;aff2.variables],[aff1.coefficients;aff2.coefficients],aff1.offset+aff2.offset)
end

function build_generator(n)
    return sum(i^1.5*Variable(i) for i in 1:n)
end

function build_loop(n)
    aff = zero(AffineExpression)
    for i in 1:n
        aff += i^1.5*Variable(i)
    end
    return aff
end

function build_manual(n)
    aff = zero(AffineExpression)
    sizehint!(aff.variables, n)
    sizehint!(aff.coefficients, n)
    for i in 1:n
        push!(aff.variables, Variable(i))
        push!(aff.coefficients, i^1.5)
    end
    return aff
end

ex = :(sum(i^1.5*Variable(i) for i in 1:n))
dump(ex)
ex.args[2]
ex.args[2].args

function rewrite_generator(ex)
    @assert isexpr(ex,:call)
    @assert ex.args[1] == :sum
    @assert isexpr(ex.args[2], :generator)
    return quote
        aff = zero(AffineExpression)
        len = length($(ex.args[2].args[2].args[2]))
        sizehint!(aff.variables, len)
        sizehint!(aff.coefficients, len)
        for $(ex.args[2].args[2].args[1]) in $(ex.args[2].args[2].args[2])
            push!(aff.variables, $(ex.args[2].args[1].args[3]))
            push!(aff.coefficients, $(ex.args[2].args[1].args[2]))
        end
        aff
    end
end

rewrite_generator(:(sum(i^1.5*Variable(i) for i in 1:n)))

macro build_expression(ex)
    return rewrite_generator(ex)
end

function build_macro(n)
    return @build_expression sum(i^1.5*Variable(i) for i in 1:n)
end

