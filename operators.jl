using Base.Meta
using BenchmarkTools

struct Variable
    index::Int
end

# Represents sum(coefficients[i]*variables[i] for i in ...) + offset
mutable struct AffineExpression
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


@enum NodeClass CONST VAR MUL ADD

struct OperationNode
    nc::NodeClass
    children::Vector{OperationNode}
    metadata::Float64
end

OperationNode(v::Variable) = OperationNode(VAR, [], v.index)
OperationNode(n::Float64) = OperationNode(CONST, [], n)

Base.:*(o1::OperationNode,o2::OperationNode) = OperationNode(MUL, [o1,o2], 0.0)
Base.:+(o1::OperationNode,o2::OperationNode) = OperationNode(ADD, [o1,o2], 0.0)


# special structure:
#          ADD
#         /   \
#       MUL    ADD
#      /   \     \
#  CONST   VAR   ...

function graph_to_aff(g::OperationNode, aff::AffineExpression = zero(AffineExpression))
    if g.nc == ADD
        for c in g.children
            graph_to_aff(c, aff)
        end
    elseif g.nc == MUL
        # we know it is CONST*VAR
        coef = 0.0
        varidx = 0
        @assert length(g.children) == 2
        for c in g.children
            if c.nc == CONST
                coef = c.metadata
            elseif c.nc == VAR
                varidx = Int(c.metadata)
            end
        end
        push!(aff.variables, Variable(varidx))
        push!(aff.coefficients, coef)
    else
        error()
    end
    return aff
end

function build_graph(n)

    g = sum(OperationNode(i^1.5)*OperationNode(Variable(i)) for i in 1:n)

    return graph_to_aff(g)
end

@benchmark build_generator(100)
@benchmark build_loop(100)
@benchmark build_manual(100)
@benchmark build_graph(100)

@benchmark build_generator(1000)
@benchmark build_loop(1000)
@benchmark build_manual(1000)
@benchmark build_graph(1000)


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


@benchmark build_macro(100)
@benchmark build_macro(1000)
