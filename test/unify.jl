@testset "Unification" begin

# Test unification of nested terms
subst = unify(@julog(f(g(X, h(X, b)), Z)), @julog(f(g(a, Z), Y)))
@test subst == @varsub {X => a, Z => h(a, b), Y => h(a, b)}

# Test occurs check during unification
@test unify(@julog(A), @julog(functor(A)), false) == @varsub {A => functor(A)}
@test unify(@julog(A), @julog(functor(A)), true) === nothing

# Test semantic unification of arithmetic functions (Prolog can't do this!)
# X unifies to 4, Y unifies to 5, so *(X, Y) unifies by evaluation to 20
@test unify(@julog(f(X, X*Y, Y)), @julog(f(4, 20, 5))) == @varsub {Y => 5, X => 4}
# X unifies to 4, Y unifies to /(20,4), so *(X, Y) unifies by evaluation to 20
@test unify(@julog(f(X, X*Y, Y)), @julog(f(4, 20, 20/4))) == @varsub {Y => /(20, 4), X => 4}
# X unifies to 4, Y unifies to 5, Z unifies to *(X, Y) === *(4, 5) post substitution
@test unify(@julog(f(X, X*Y, Y)), @julog(f(4, Z, 5))) == @varsub {Y => 5, X => 4, Z => *(4, 5)}
# X unifies to X, Y unifies to 5, X*Y cannot be evaluated and so fails to unify with 20
@test unify(@julog(f(X, X*Y, Y)), @julog(f(X, 20, 5))) === nothing

# Test subterm detection
@test has_subterm(@julog(atom), @julog(Var)) == true

@test has_subterm(@julog(functor(functor(atom))), @julog(functor)) == false
@test has_subterm(@julog(functor(functor(atom))), @julog(atom)) == true
@test has_subterm(@julog(functor(functor(atom))), @julog(functor(Var))) == true

@test has_subterm(@julog(list[a, b, c, d]), @julog(b)) == true
@test has_subterm(@julog(list[a, b, c, d]), @julog(list[a, b])) == false
@test has_subterm(@julog(list[a, b, c, d]), @julog(list[c, d])) == true

@test has_subterm(@julog(f(g(X, h(X, b)), Z)), @julog(h(X, Y))) == true

subterms = find_subterms(@julog(foo(bar(1), bar(bar(2)))), @julog(bar(X)))
@test Set(subterms) == Set(@julog(Term[bar(1), bar(bar(2)), bar(2)]))

end
