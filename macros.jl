using Base.Meta

# http://docs.julialang.org/en/release-0.5/manual/metaprogramming/

# expression structure
ex = :(1+1)
dump(ex)
show_sexpr(ex)



# rewriting
macro noplus(ex)
    @assert isexpr(ex, :call)
    if ex.args[1] == :+
        ex.args[1] = :-
    end
    return ex
end

@noplus 1+1

# recursively
function plustominus(ex::Expr)
    ex = copy(ex) # Don't modify the input
    if ex.head == :call && ex.args[1] == :+
        ex.args[1] = :-
    end
    for i in 1:length(ex.args)
        ex.args[i] = plustominus(ex.args[i])
    end
    return ex
end
plustominus(ex) = ex # If not expression, do nothing

plustominus(:(1+1))
plustominus(:(1+(1+1)))

macro noplus_recursive(ex)
    return plustominus(ex)
end

@noplus_recursive 2+(1+2)
macroexpand(:(@noplus_recursive 2+(1+2)))

function foo()
    x = 10
    @noplus_recursive x+5
end

@code_lowered foo()

