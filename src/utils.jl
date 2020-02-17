"Replace all variables in a term with fresh names."
freshen(t::Term) = error("Not implemented.")
freshen(t::Const) = t
freshen(t::Var) = Var(gensym(t.name))
freshen(t::Compound) = Compound(t.name, Term[freshen(a) for a in t.args])

"Replace selected variables in a term with fresh names."
freshen(t::Term, vars::Set{Var}) = error("Not implemented.")
freshen(t::Const, vars::Set{Var}) = t
freshen(t::Var, vars::Set{Var}) = v in vars ? Var(gensym(t.name)) : t
freshen(t::Compound, vars::Set{Var}) =
    Compound(t.name, Term[freshen(a, vars) for a in t.args])

"Return all vars in a term."
get_vars(t::Term) = error("Not implemented.")
get_vars(t::Const) = Set{Var}()
get_vars(t::Var) = Set{Var}([t])
get_vars(t::Compound) = union([get_vars(a) for a in t.args]...)

"Check if a term is ground (contains no variables)."
is_ground(t::Term) = error("Not implemented.")
is_ground(t::Const) = true
is_ground(t::Var) = false
is_ground(t::Compound) = all([is_ground(a) for a in t.args])

"Check whether a variable appears in a term."
occurs_in(v::Var, t::Term) = error("Not implemented.")
occurs_in(v::Var, t::Const) = false
occurs_in(v::Var, t::Var) = (v.name == t.name)
occurs_in(v::Var, t::Compound) = any([occurs_in(v, a) for a in t.args])

"Performs variable substitution of var by val in a term."
substitute(term::Term, var::Var, val::Term) = error("Not implemented.")
substitute(term::Const, var::Var, val::Term) = term
substitute(term::Var, var::Var, val::Term) = term.name == var.name ? val : term
substitute(term::Compound, var::Var, val::Term) =
    Compound(term.name, Term[substitute(a, var, val) for a in term.args])

"Apply substitution to a term."
function substitute(term::Term, subst::Subst)
    for (var, val) in subst
        term = substitute(term, var, val)
    end
    return term
end

"Compose two substitutions (s2 after s1)."
function compose(s1::Subst, s2::Subst)
    subst = Subst(var => substitute(val, s2) for (var, val) in s1)
    return merge(s2, subst)
end

"Nested dictionary to store indexed clauses."
ClauseTable = Dict{Symbol,Dict{Symbol,Vector{Clause}}}

"Insert clauses into indexed table for efficient look-up."
function insert_clauses!(table::ClauseTable, clauses::Vector{Clause})
    # Ensure no duplicates are added
    clauses = unique(clauses)
    if (length(table) > 0) setdiff!(clauses, deindex_clauses(table)) end
    # Iterate over clauses and insert into table
    for c in clauses
        subtable = get!(table, c.head.name, Dict{Symbol,Vector{Clause}}())
        if isa(c.head, Compound) && length(c.head.args) >= 1
            arg = c.head.args[1]
            if isa(arg, Var)
                push!(get!(subtable, :__var__, Clause[]), c)
            else
                push!(get!(subtable, Symbol(arg.name), Clause[]), c)
            end
            push!(get!(subtable, :__all__, Clause[]), c)
        else
            push!(get!(subtable, :__no_args__, Clause[]), c)
        end
    end
    return table
end

"Insert clauses into indexed table and return a new table."
function insert_clauses(table::ClauseTable, clauses::Vector{Clause})
    return insert_clauses!(deepcopy(table), clauses)
end

"Index clauses by functor name and first argument for efficient look-up."
function index_clauses(clauses::Vector{Clause})
    return insert_clauses!(ClauseTable(), clauses)
end

"Convert indexed clause table to flat list of clauses."
function deindex_clauses(table::ClauseTable)
    clauses = Clause[]
    for (functor, subtable) in table
        if :__no_args__ in keys(subtable)
            append!(clauses, subtable[:__no_args__])
        else
            append!(clauses, subtable[:__all__])
        end
    end
    return clauses
end

"Retrieve matching clauses from indexed clause table."
function retrieve_clauses(table::ClauseTable, term::Term)
    clauses = Clause[]
    if term.name in keys(table)
        subtable = table[term.name]
        if isa(term, Compound) && length(term.args) >= 1
            arg = term.args[1]
            if isa(arg, Var)
                clauses = get(subtable, :__all__, Clause[])
            else
                clauses = [get(subtable, Symbol(arg.name), Clause[]);
                           get(subtable, :__var__, Clause[])]
            end
        else
            clauses = get(subtable, :__no_args__, Clause[])
        end
    end
    return clauses
end

"Subtract one clause table from another (in-place)."
function subtract_clauses!(table1::ClauseTable, table2::ClauseTable)
    for (functor, subtable2) in table2
        if !(functor in keys(table1)) continue end
        subtable1 = table1[functor]
        for arg in keys(subtable2)
            if !(arg in keys(subtable1)) continue end
            setdiff!(subtable1[arg], subtable2[arg])
        end
    end
    return table1
end

"Subtract one clause table from another (returns new copy)."
function subtract_clauses(table1::ClauseTable, table2::ClauseTable)
    return subtract_clauses!(deepcopy(table1), table2)
end

"Subtract clauses from a indexed clause table (in-place)."
function subtract_clauses!(table::ClauseTable, clauses::Vector{Clause})
    return subtract_clauses!(table, index_clauses(clauses))
end

"Subtract clauses from a indexed clause table (returns new copy)."
function subtract_clauses(table::ClauseTable, clauses::Vector{Clause})
    return subtract_clauses(table, index_clauses(clauses))
end
