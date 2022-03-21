
"Nested dictionary to store indexed clauses."
const ClauseSubtable{T} = Dict{Symbol,Vector{T}} where  T <: AbstractClause
const ClauseTable{T} = Dict{Symbol,ClauseSubtable{T}}

function insert_clause!(table::ClauseTable{T}, c::Clause) where {T <: AbstractClause}
    subtable = get!(table, c.head.name, Dict{Symbol,Vector{T}}())
    if isa(c.head, Compound) && length(c.head.args) >= 1
        arg = c.head.args[1]
        if isa(arg, Var)
            push!(get!(subtable, :__var__, Vector{T}()), c)
        else
            push!(get!(subtable, Symbol(arg.name), Vector{T}()), c)
        end
        push!(get!(subtable, :__all__, Vector{T}()), c)
    else
        push!(get!(subtable, :__no_args__, Vector{T}()), c)
    end
end

"Insert clauses into indexed table for efficient look-up."
function insert_clauses!(table::ClauseTable{T}, clauses::Vector{T})  where {T <: AbstractClause}
    # Ensure no duplicates are added
    clauses = unique(clauses)
    if (length(table) > 0) setdiff!(clauses, deindex_clauses(table)) end
    # Iterate over clauses and insert into table
    for c in clauses
        insert_clause!(table, c)
    end
    return table
end

"Insert clauses into indexed table and return a new table."
function insert_clauses(table::ClauseTable{T}, clauses::Vector{T})  where {T <: AbstractClause}
    return insert_clauses!(deepcopy(table), clauses)
end

"Index clauses by functor name and first argument for efficient look-up."
function index_clauses(clauses::Vector{T})  where {T <: AbstractClause}
    return insert_clauses!(ClauseTable{T}(), clauses)
end

"Convert indexed clause table to flat list of clauses."
function deindex_clauses(table::ClauseTable{T})  where {T <: AbstractClause}
    clauses = Vector{T}()
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
function retrieve_clauses(table::ClauseTable{T}, term::Term, funcs::Dict=Dict())  where {T <: AbstractClause}
    clauses = Vector{T}()
    funcs = length(funcs) > 0 ? merge(default_funcs, funcs) : default_funcs
    if term.name in keys(table)
        subtable = table[term.name]
        if isa(term, Compound) && length(term.args) >= 1
            arg = term.args[1]
            if isa(arg, Var) || arg.name in keys(funcs)
                clauses = get(subtable, :__all__, clauses)
            else
                clauses = [get(subtable, Symbol(arg.name), clauses);
                           get(subtable, :__var__, clauses)]
            end
        else
            clauses = get(subtable, :__no_args__, clauses)
        end
    end
    return clauses
end

"Subtract one clause table from another (in-place)."
function subtract_clauses!(table1::ClauseTable{T}, table2::ClauseTable{T})  where {T <: AbstractClause}
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
function subtract_clauses(table1::ClauseTable{T}, table2::ClauseTable{T})  where {T <: AbstractClause}
    return subtract_clauses!(deepcopy(table1), table2)
end

"Subtract clauses from a indexed clause table (in-place)."
function subtract_clauses!(table::ClauseTable{T}, clauses::Vector{T})  where {T <: AbstractClause}
    return subtract_clauses!(table, index_clauses(clauses))
end

"Subtract clauses from a indexed clause table (returns new copy)."
function subtract_clauses(table::ClauseTable{T}, clauses::Vector{T})  where {T <: AbstractClause}
    return subtract_clauses(table, index_clauses(clauses))
end

"Return number of clauses in indexed clause table."
function num_clauses(table::ClauseTable{T})  where {T <: AbstractClause}
    n = 0
    for (functor, subtable) in table
        if :__no_args__ in keys(subtable)
            n += length(subtable[:__no_args__])
        else
            n += length(subtable[:__all__])
        end
    end
    return n
end