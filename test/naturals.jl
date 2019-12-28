# Test the natural numbers and addition
clauses = @fol [
    nat(0) <<= true,
    nat(s(N)) <<= nat(N),
    add(0, Y, Y) <<= true,
    add(s(X), Y, s(Z)) <<= add(X, Y, Z)
]

# Is 1 a natural number?
sat, subst = resolve(@fol(nat(s(0))), clauses)
@test sat == true

# Is 5 a natural number?
sat, subst = resolve(@fol(nat(s(s(s(s(s(0))))))), clauses)
@test sat == true

# Is 1 + 1 = 2?
sat, subst = resolve(@fol(add(s(0), s(0), s(s(0)))), clauses)
@test sat == true

# What are all the ways to add up to 3?
sat, subst = resolve(@fol(add(A, B, s(s(s(0))))), clauses)
subst = Set(subst)
@test @folsub({A => 0, B => s(s(s(0)))}) in subst
@test @folsub({A => s(0), B => s(s(0))}) in subst
@test @folsub({A => s(s(0)), B => s(0)}) in subst
@test @folsub({A => s(s(s(0))), B => 0}) in subst
