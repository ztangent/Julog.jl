"""
    Term

Represents a term or expression in first-order logic, including variables,
constants, or compound terms.
"""
abstract type Term end

"""
    Const

Represents a named constant term with no arguments.
"""
struct Const <: Term
    name::Any
end

"""
    Var

Represents a variable in a first-order expression.
"""
struct Var <: Term
    name::Union{Symbol,UInt}
end

"""
    Compound

A `Compound` represents a term with zero or more arguments. When a `Compound`
has zero arguments, it is functionally equivalent to a `Const.`
"""
struct Compound <: Term
    name::Symbol
    args::Vector{Term}
end

"""
    AbstractClause

Abstract type for clauses in a logic program.
"""
abstract type AbstractClause end

"""
    Clause

A definite Horn clause of the form `[head] <<= [body]`.
"""
struct Clause <: AbstractClause
    head::Term
    body::Vector{Term}
end

"""
    Subst

Substitution mapping from variables to terms. Alias for `Dict{Var,Term}`.
"""
const Subst = Dict{Var,Term}

Base.:(==)(t1::Term, t2::Term) = false
Base.:(==)(t1::Const, t2::Const) = t1.name == t2.name
Base.:(==)(t1::Var, t2::Var) = t1.name == t2.name
Base.:(==)(t1::Const, t2::Compound) = t1.name == t2.name && isempty(t2.args)
Base.:(==)(t1::Compound, t2::Const) = t1.name == t2.name && isempty(t1.args)
Base.:(==)(t1::Compound, t2::Compound) =
    (t1.name == t2.name && length(t1.args) == length(t2.args) &&
            all(a1 == a2 for (a1, a2) in zip(t1.args, t2.args)))

Base.hash(t::Term, h::UInt) = error("Not implemented.")
Base.hash(t::Const, h::UInt) = hash(t.name, h)
Base.hash(t::Var, h::UInt) = hash(t.name, h)
Base.hash(t::Compound, h::UInt) = isempty(t.args) ?
    hash(t.name, h) : hash(t.name, hash(Tuple(t.args), h))

Base.:(==)(c1::Clause, c2::Clause) =
    (c1.head == c2.head && length(c1.body) == length(c2.body) &&
     all(t1 == t2 for (t1, t2) in zip(c1.body, c2.body)))

Base.hash(c::Clause, h::UInt) = hash(c.head, hash(Tuple(c.body), h))

Base.convert(::Type{Clause}, term::Term) = Clause(term, [])

function Base.convert(::Type{Term}, clause::Clause)
    if length(clause.body) == 0 return clause.head end
    return Compound(:(=>), Term[Compound(:and, copy(clause.body)), clause.head])
end

function Base.show(io::IO, t::Term)
    print(io, t.name)
end

function Base.show(io::IO, t::Var)
    (t.name isa UInt) ? print(io, "#", t.name) : print(io, t.name)
end

function Base.show(io::IO, t::Compound)
    if t.name == :cons && length(t.args) == 2
        # Handle lists separately
        head, tail = t.args[1], t.args[2]
        if isa(tail, Var)
            print(io, "[", repr(head), " | ", repr(tail), "]")
        elseif isa(tail, Compound) && tail.name == :cend
            print(io, "[", repr(head), "]")
        else
            print(io, "[", repr(head), ", ", repr(tail)[2:end-1], "]")
        end
    elseif isempty(t.args)
        # Print zero-arity compounds as constants
        t.name == :cend ? print(io, "[]") : print(io, t.name)
    else
        # Print compound term as "name(args...)"
        print(io, t.name, "(", join([repr(a) for a in t.args], ", ")..., ")")
    end
end

function Base.show(io::IO, c::Clause)
    if length(c.body) == 0
        print(io, c.head)
    else
        print(io, c.head, " <<= ", join([repr(t) for t in c.body], " & ")...)
    end
end

function Base.show(io::IO, subst::Subst)
    print(io, "{", join(["$k => $v" for (k, v) in subst], ", ")..., "}")
end

"Get arguments of a term."
get_args(term::Term) = Term[]
get_args(term::Compound) = term.args

Base.getproperty(t::Const, f::Symbol) = f == :args ? Term[] : getfield(t, f)
Base.getproperty(t::Var, f::Symbol) = f == :args ? Term[] : getfield(t, f)

Base.propertynames(t::Const) = (:name, :args)
Base.propertynames(t::Var) = (:name, :args)
