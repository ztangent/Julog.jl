module Julog

include("structs.jl")
include("parse.jl")
include("utils.jl")
include("builtins.jl")
include("main.jl")

export Const, Var, Compound, Term, Clause, Subst, ClauseTable
export get_args, is_ground, substitute, has_subterm, find_subterms
export to_nnf, to_cnf, to_dnf, flatten_conjs, flatten_disjs, deuniversalize
export eval_term, unify, resolve, derivations, derive, fwd_chain, bwd_chain
export regularize_clauses, index_clauses, deindex_clauses, retrieve_clauses
export insert_clauses!, insert_clauses, subtract_clauses!, subtract_clauses
export parse_prolog, write_prolog
export @julog, @prolog, @varsub

end # module
