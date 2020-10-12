# Test that parsing works correctly

# Parsing of terms
@test Const(:atom) == @julog atom
@test Const(1) == @julog 1
@test Const((2,3)) == @julog (2,3)
@test Const("foo") == @julog "foo"
@test Var(:Variable) == @julog Variable
@test Compound(:functor, Term[Const(:a), Var(:B)]) == @julog functor(a, B)

# Parsing of clauses and facts
@test Clause(Const(:head), [Const(:body)]) == @julog head <<= body
@test Clause(Const(:head), [Const(:t1), Const(:t2)]) == @julog head <<= t1 & t2
@test Clause(Const(:head), []) == @julog head <<= true
@test Clause(Const(:head), []) == @julog head'

# Parsing of lists of terms or clauses
@test [Clause(Const(:fact), []), Const(:term)] == @julog [fact', term]
@test [Clause(Const(:a), [Const(:b)])] == @julog Clause[a <<= b]
@test Const[Const(:a), Const(:b)] == @julog [a, b]
@test Term[Const(:a), Const(:b)] == @julog Term[a, b]
@test Const[Const(:a), Const(:b)] == @julog Const[a, b]
@test Var[Var(:A), Var(:B)] == @julog Var[A, B]
@test Compound[Compound(:f, [Const(:arg)])] == @julog Compound[f(arg)]

# Interpolation of constants and Julog expressions
x, y = 2, Const(3)
@test Compound(:even, [Const(x)]) == @julog even($x)
@test Compound(:odd, [y]) == @julog odd(:y)
not_even = Compound(:not, [Compound(:even, [Var(:X)])])
odd_if_not_even = Clause(Compound(:odd, [Var(:X)]), [not_even])
@test odd_if_not_even == @julog odd(X) <<= :not_even

let f = :f
    @test @julog($f(x)) == @julog(f(x))
end

# Test parsing and interpolation in @varsub macro
a, b = :alice, Const(:bob)
s1 = Subst(Var(:A) => Const(a), Var(:B) => b)
s2 = @varsub {A => alice, B => bob}
s3 = @varsub {A => $a, B => :b}
@test s1 == s2 == s3
