"Replace all variables in a term with fresh names."
freshen(t::Term) = error("Not implemented.")
freshen(t::Const) = t
freshen(t::Var) = Var(gensym(t.name))
freshen(t::Compound) = Compound(t.name, Term[freshen(a) for a in t.args])

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
