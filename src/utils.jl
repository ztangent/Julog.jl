@static if VERSION < v"1.1"
    isnothing(::Any) = false
    isnothing(::Nothing) = true
end

@static if VERSION < v"1.2"
    function map!(f, iter::Base.ValueIterator)
        dict = iter.dict
        for (key, val) in pairs(dict)
            dict[key] = f(val)
        end
        return iter
    end
end

"Return all vars in a term."
get_vars(t::Term) = error("Not implemented.")
get_vars(t::Const) = Set{Var}()
get_vars(t::Var) = Set{Var}([t])
get_vars(t::Compound) =
    length(t.args) > 0 ? union((get_vars(a) for a in t.args)...) : Set{Var}()

"Check if a term is ground (contains no variables)."
is_ground(t::Term) = error("Not implemented.")
is_ground(t::Const) = true
is_ground(t::Var) = false
is_ground(t::Compound) = all(is_ground(a) for a in t.args)

"Check whether a variable appears in a term."
occurs_in(v::Var, t::Term) = error("Not implemented.")
occurs_in(v::Var, t::Const) = false
occurs_in(v::Var, t::Var) = (v.name == t.name)
occurs_in(v::Var, t::Compound) = any(occurs_in(v, a) for a in t.args)

"Performs variable substitution of var by val in a term."
substitute(term::Term, var::Var, val::Term) = error("Not implemented.")
substitute(term::Const, var::Var, val::Term) = term
substitute(term::Var, var::Var, val::Term) = term.name == var.name ? val : term
function substitute(term::Compound, var::Var, val::Term)
    args, ident = nothing, true
    for (i, a) in enumerate(term.args)
        b = substitute(a, var, val)
        if ident && a !== b
            args, ident = collect(term.args[1:i-1]), false
        end
        if !ident push!(args, b) end
    end
    return ident ? term : Compound(term.name, args)
end

"Apply substitution to a term."
substitute(term::Term, subst::Subst) = error("Not implemented.")
substitute(term::Const, subst::Subst) = term
substitute(term::Var, subst::Subst) = get(subst, term, term)
function substitute(term::Compound, subst::Subst)
    args, ident = nothing, true
    for (i, a) in enumerate(term.args)
        b = substitute(a, subst)
        if ident && a !== b
            args, ident = collect(term.args[1:i-1]), false
        end
        if !ident push!(args, b) end
    end
    return ident ? term : Compound(term.name, args)
end

"Compose two substitutions (s2 after s1)."
function compose(s1::Subst, s2::Subst)
    subst = Subst(var => substitute(val, s2) for (var, val) in s1)
    return merge(s2, subst)
end

"Compose two substitutions (s2 after s1), modifying s1 in place."
function compose!(s1::Subst, s2::Subst)
    map!(v -> substitute(v, s2), values(s1))
    for (var, val) in s2 get!(s1, var, val) end
    return s1
end

"Replace variables in a term or clause with fresh names."
function freshen(term::Term, vars::Set{Var})
    vmap = Subst(v => Var(gensym(v.name)) for v in vars)
    term = substitute(term, vmap)
    return term, vmap
end

function freshen(clause::Clause, vars::Set{Var})
    vmap = Subst(v => Var(gensym(v.name)) for v in vars)
    clause = Clause(substitute(clause.head, vmap),
                    Term[substitute(t, vmap) for t in clause.body])
    return clause, vmap
end

freshen(t::Term) = freshen!(t, Subst())
freshen(c::Clause) = freshen!(c, Subst())

freshen!(t::Const, vmap::Subst) = t
freshen!(t::Var, vmap::Subst) = get!(vmap, t, Var(gensym(t.name)))
freshen!(t::Compound, vmap::Subst) =
    Compound(t.name, Term[freshen!(a, vmap) for a in t.args])
freshen!(c::Clause, vmap::Subst) =
    Clause(freshen!(c.head, vmap), Term[freshen!(t, vmap) for t in c.body])

freshen!(t::Const, vmap::Subst, vcount::Ref{UInt}) = t
freshen!(t::Var, vmap::Subst, vcount::Ref{UInt}) =
    get!(vmap, t, Var(vcount[] += 1))
freshen!(t::Compound, vmap::Subst, vcount::Ref{UInt}) =
    Compound(t.name, Term[freshen!(a, vmap, vcount) for a in t.args])
freshen!(c::Clause, vmap::Subst, vcount::Ref{UInt}) =
    Clause(freshen!(c.head, vmap, vcount),
           Term[freshen!(t, vmap, vcount) for t in c.body])

"Check whether a term has a matching subterm."
function has_subterm(term::Term, subterm::Term)
    if !isnothing(unify(term, subterm)) return true end
    return any(has_subterm(arg, subterm) for arg in get_args(term))
end

"Find all matching subterms in a term."
function find_subterms(term::Term, subterm::Term)
    init = !isnothing(unify(term, subterm)) ? Term[term] : Term[]
    subterms = (find_subterms(a, subterm) for a in get_args(term))
    return reduce(vcat, subterms; init=init)
end

"Convert a vector of Julia objects to a Julog list of constants."
to_const_list(v::Vector) =
    foldr((i, j) -> Compound(:cons, [Const(i), j]), v; init=Compound(:cend, []))

"Convert a vector of Julog terms to a Julog list."
to_term_list(v::Vector{<:Term}) =
    foldr((i, j) -> Compound(:cons, [i, j]), v; init=Compound(:cend, []))

"Convert a list of Julog terms to a vector of Julog terms.."
to_julia_list(list::Term) =
    list.name == :cons ? [list.args[1]; to_julia_list(list.args[2])] : []

"Simplify by rewriting implications, flattening conjuctions and disjunctions."
function simplify(term::Compound)
    if !(term.name in logicals) return term end
    args = simplify.(term.args)
    if term.name in (:imply, :(=>))
        cond, body = args
        return simplify(@julog or(not(:cond), and(:cond, :body)))
    elseif term.name == :and
        if length(args) == 1 return args[1]
        elseif any(a -> a.name == false, args) return Const(false)
        elseif all(a -> a.name == true, args) return Const(true)
        else
            args = flatten_conjs(filter!(a -> a.name != true, args))
            term = Compound(term.name, unique!(args))
        end
    elseif term.name == :or
        if length(args) == 1 return args[1]
        elseif any(a -> a.name == true, args) return Const(true)
        elseif all(a -> a.name == false, args) return Const(false)
        else
            args = flatten_disjs(filter!(a -> a.name != false, args))
            term = Compound(term.name, unique!(args))
        end
    elseif term.name in (:not, :!)
        if args[1].name == true return Const(false)
        elseif args[1].name == false return Const(true)
        else return Compound(:not, args) end
    end
    return length(term.args) == 1 ? term.args[1] : term
end
simplify(term::Const) = term
simplify(term::Var) = term

"Convert a term to negation normal form."
function to_nnf(term::Compound)
    term = simplify(term)
    if term.name in (:not, :!)
        inner = term.args[1]
        if inner.name in (:not, :!)
            term = inner.args[1]
        elseif inner.name in (true, false)
            term = Const(!inner.name)
        elseif inner.name in (:and, :or)
            args = to_nnf.(@julog(not(:a)) for a in inner.args)
            term = Compound(inner.name == :and ? :or : :and, args)
        elseif inner.name in (:forall, :exists)
            query, body = inner.args
            query = to_nnf(query)
            body = to_nnf(@julog(not(:body)))
            name = inner.name == :forall ? :exists : :forall
            term = Compound(name, Term[query, body])
        end
    elseif term.name in (true, false)
        return term
    elseif term.name in logicals
        term = Compound(term.name, to_nnf.(term.args))
    end
    return term
end
to_nnf(term::Const) = term
to_nnf(term::Var) = term

"Convert a term to conjunctive normal form."
function to_cnf(term::Compound)
    term = to_nnf(term)
    if !(term.name in (:and, :or)) return @julog and(or(:term)) end
    subterms = to_cnf.(term.args)
    if term.name == :and
        args = foldl(vcat, [a.args for a in subterms]; init=Compound[])
        term = Compound(:and, args)
    elseif term.name == :or
        stack = Compound[@julog(or())]
        for subterm in subterms
            new_stack = Compound[]
            for disj_i in stack
                for disj_j in subterm.args
                    new_disj = Compound(:or, [disj_i.args; disj_j.args])
                    push!(new_stack, new_disj)
                end
            end
            stack = new_stack
        end
        term = Compound(:and, stack)
    end
    return term
end
to_cnf(term::Const) = @julog and(or(:term))
to_cnf(term::Var) = @julog and(or(:term))

"Convert a term to disjunctive normal form."
function to_dnf(term::Compound)
    term = to_nnf(term)
    if !(term.name in (:and, :or)) return @julog or(and(:term)) end
    subterms = to_dnf.(term.args)
    if term.name == :or
        args = foldl(vcat, (a.args for a in subterms); init=Compound[])
        term = Compound(:or, args)
    elseif term.name == :and
        stack = Compound[@julog(and())]
        for subterm in subterms
            new_stack = Compound[]
            for conj_i in stack
                for conj_j in subterm.args
                    new_conj = Compound(:and, [conj_i.args; conj_j.args])
                    push!(new_stack, new_conj)
                end
            end
            stack = new_stack
        end
        term = Compound(:or, stack)
    end
    return term
end
to_dnf(term::Const) = @julog or(and(:term))
to_dnf(term::Var) = @julog or(and(:term))

"Recursively flatten conjunctions in a term to a list."
flatten_conjs(t::Term) = t.name == :and ? flatten_conjs(get_args(t)) : Term[t]
flatten_conjs(t::Vector{<:Term}) = reduce(vcat, flatten_conjs.(t); init=Term[])

"Recursively flatten disjunctions in term to a list."
flatten_disjs(t::Term) = t.name == :or ? flatten_disjs(get_args(t)) : Term[t]
flatten_disjs(t::Vector{<:Term}) = reduce(vcat, flatten_disjs.(t); init=Term[])

"Instantiate universal quantifiers relative to a set of clauses."
function deuniversalize(term::Compound, clauses::Vector{Clause})
    if term.name == :forall
        cond, body = term.args
        sat, subst = resolve(cond, clauses)
        if !sat return Const(true) end
        instantiated = unique!(Term[substitute(body, s) for s in subst])
        return Compound(:and, instantiated)
    elseif term.name in logicals
        args = Term[deuniversalize(a, clauses) for a in term.args]
        return Compound(term.name, args)
    else
        return term
    end
end
deuniversalize(term::Const, ::Vector{Clause}) = term
deuniversalize(term::Var, ::Vector{Clause}) = term
deuniversalize(c::Clause, clauses::Vector{Clause}) =
    Clause(c.head, [deuniversalize(t, clauses) for t in c.body])


"Convert any clauses with disjunctions in their bodies into a set of clauses."
function regularize_clauses(clauses::Vector{Clause}; instantiate::Bool=false)
    regularized = Clause[]
    for c in clauses
        if length(c.body) == 0
            push!(regularized, c)
        else
            body = Compound(:and, c.body)
            if (instantiate == true) body = deuniversalize(body, clauses) end
            for conj in to_dnf(body).args
                push!(regularized, Clause(c.head, conj.args))
            end
        end
    end
    return regularized
end
