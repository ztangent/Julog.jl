# using Julog

@testset "Extended Built-ins" begin

@test resolve(@julog(atom(X)), Clause[])[1] == true
@test resolve(@julog(nonvar(X)), Clause[])[1] == false
@test resolve(@julog(ground(X)), Clause[])[1] == false
@test resolve(@julog(ground(atomic(X))), Clause[])[1] == false
@test resolve(@julog(ground(atomic(x))), Clause[])[1] == true
@test resolve(@julog(arg(1, f(a, b), a)), Clause[])[1] == true
@test resolve(@julog(functor(f(a, b), f, 2)), Clause[])[1] == true
@test resolve(@julog(functor(f(a, b), F, A)), Clause[])[1] == true
@test resolve(@julog(univ(Term, [baz, foo(1)])), Clause[])[1] == true
@test resolve(@julog(univ(foo(hello, X), List)), Clause[])[1] == true

end

# goal = @julog arg(1, f(a,b), a)
# res = resolve(goal, Clause[])