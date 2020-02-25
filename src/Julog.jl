module Julog

include("structs.jl")
include("parse.jl")
include("utils.jl")
include("main.jl")

export Term, Clause, Subst, ClauseTable
export is_ground, substitute, eval_term, unify, resolve
export index_clauses, deindex_clauses, retrieve_clauses
export insert_clauses!, insert_clauses, subtract_clauses!, subtract_clauses
export parse_prolog, write_prolog
export @julog, @prolog, @varsub

end # module
