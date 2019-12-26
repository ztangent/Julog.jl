module FOL

include("structs.jl")
include("parse.jl")
include("utils.jl")
include("main.jl")

export Const, Var, Compound, Term, Clause, Subst
export @fol, is_ground, substitute, eval_term, unify, resolve

end # module
