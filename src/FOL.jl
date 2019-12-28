module FOL

include("structs.jl")
include("parse.jl")
include("utils.jl")
include("main.jl")

export Const, Var, Compound, Term, Clause, Subst
export is_ground, substitute, eval_term, unify, resolve
export @fol, @folsub

end # module
