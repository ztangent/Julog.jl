"Return all vars in a term."
function get_vars(t::Term)
    if t.type == constant return Set{Term}()
    elseif t.type == variable return Set{Term}([t])
    elseif length(t.args) == 0 return Set{Term}()
    else return union([get_vars(a) for a in t.args]...)
    end
end

"Check if a term is ground (contains no variables)."
function is_ground(t::Term)
    if t.type == constant return true
    elseif t.type == variable return false
    else return all([is_ground(a) for a in t.args])
    end
end

"Check whether a variable appears in a term."
function occurs_in(v::Term, t::Term)
    @assert v.type == variable
    if t.type == constant return false
    elseif t.type == variable return (v.name == t.name)
    else return any([occurs_in(v, a) for a in t.args])
    end
end

"Performs variable substitution of var by val in a term."
function substitute(term::Term, var::Term, val::Term)
    @assert var.type == variable
    if term.type == constant return term
    elseif term.type == variable return (term.name == var.name ? val : term)
    else return Compound(term.name, [substitute(a,var,val) for a in term.args])
    end
end

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

"Compose two substitutions (s2 after s1), modifying s1 in place."
function compose!(s1::Subst, s2::Subst)
    for (var, val) in s1
        s1[var] = substitute(val, s2)
    end
    for (var, val) in s2
        if !(var in keys(s1)) s1[var] = val end
    end
    return s1
end

"Replace variables in a term with fresh names."
function freshen(term::Term, vars::Set{Term})
    vmap = Subst(v => Var(gensym(v.name)) for v in vars)
    term = substitute(term, vmap)
    return term, vmap
end
freshen(term::Term) = freshen(term, get_vars(term))

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
        if c.head.type == compound && length(c.head.args) >= 1
            arg = c.head.args[1]
            if arg.type == variable
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
function retrieve_clauses(table::ClauseTable, term::Term, funcs::Dict=Dict())
    clauses = Clause[]
    funcs = length(funcs) > 0 ? merge(default_funcs, funcs) : default_funcs
    if term.name in keys(table)
        subtable = table[term.name]
        if term.type == compound && length(term.args) >= 1
            arg = term.args[1]
            if arg.type == variable || arg.name in keys(funcs)
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
