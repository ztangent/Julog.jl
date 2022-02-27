# TODO for all users, may need to distinguish between `atom` and `atomic`
# TODO predicate `var` is needed for general
isvar(t) = false
isvar(::Var) = true
atomic(t) = true
atomic(::Compound) = false

bothvar(a, b) = false
bothvar(a::Var, b::Var) = true
hasvar(v::Vector{<:Term}) = reduce(&, isvar.(v))

"""
functor(Term, Functor, Arity)
functor(f(a, b), f, 2)
"""
function functor(term; options...)
    length(term.args) == 3 || return false
    term, func, arity = term.args 
    functor(term, func, arity; options...)
end

function functor(term::Var, func, arity; options...)
    hasvar([func, arity]) && return false
    ins = Compound(func.name, [Var(gensym()) for i in 1:arity.name])
    unifies(term, ins; options...)
end

function functor(term::Const, func, arity; options...)
    if bothvar(func, arity)
        unified = unifies(func, arity; options...)
        unified && return unifies(Const(0), arity; options...)
        return false
    elseif func isa Var
        arity.name == 0 || return false
        return unifies(term, func; options...)
    elseif arity isa Var
        return unifies(Const(0), arity; options...)
    else
        (term == func && arity.name == 0) || return false
        return true
    end
    false
end

function functor(term::Compound, func, arity; options...)
    if bothvar(func, arity)
        if is_term_list(term)
            li = to_term_list(term)
            unified = unifies(Const(:cons), func; options...)
            unified && return unified(Const(length(li)), arity; options...)
            return false
        else
            unified = unifies(Const(term.name), func; options...)
            unified || return false
            return unifies(Const(length(term.args)), arity; options...)
        end
    elseif func isa Var
        length(term.args) == arity.name || return false
        return unifies(Const(term.name), func; options...)
    elseif arity isa Var
        (func isa Const && term.name == func.name) || return false
        return unifies(Const(length(term.args)), arity; options...)
    else
        (func isa Const && term.name == func.name) || return false
        arity.name == length(term.args) || return false
        return true
    end
    false
end

"""
arg(N, Term, Arg)
arg(2, foo(a, b), b).
"""
function arg(term; options...)
    length(term.args) == 3 || return false
    n, vterm, varg = term.args
    hasvar([n, vterm]) && return false
    (n isa Const && n.name isa Integer) || return false
    arg(n.name, vterm, varg; options...)
end

arg(a, b, c; options...) = false
function arg(n::Int, vterm::Compound, varg; options...)
    if is_term_list(vterm)
        li = to_julia_list(vterm)
        n > 0 || return false
        res = n > length(li) ? Compound(:cend, []) : to_term_list(li[n:end])
        isvar(varg) && return unifies(res, varg; options...)
        return varg == res
    else
        0 < n <= length(vterm.args) || return false
        res = @inbounds vterm.args[n]
        isvar(varg) && return unifies(res, varg; options)
        return res == varg
    end
    false
end