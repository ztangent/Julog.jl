module FOL

include("structs.jl")
include("parse.jl")
include("utils.jl")
include("main.jl")

export Const, Var, Compound, Term, Clause, Subst
export is_ground, substitute, eval_term, unify, resolve
export index_clauses, deindex_clauses, retrieve_clauses, subtract_clauses!
export parse_prolog, write_prolog
export @fol, @folsub, @prolog

end # module
