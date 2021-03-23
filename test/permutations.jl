# Test permutation generation

clauses = @julog [
    permutations(T) <<=
        unifies(T, [_, _ ,_]) &
        subset([1,2,3], T),

    member(X, [X | Y]) <<= true,
    member(X, [Y | YS]) <<= member(X, YS),
    subset([], _) <<= true,
    subset([X | XS], L) <<= member(X,L) & subset(XS,L),
]

sat, subst = resolve(@julog(permutations(T)),clauses)
@test @varsub({T => [1, 2, 3]}) in subst
@test @varsub({T => [1, 3, 2]}) in subst
@test @varsub({T => [2, 1, 3]}) in subst
@test @varsub({T => [2, 3, 1]}) in subst
@test @varsub({T => [3, 1, 2]}) in subst
@test @varsub({T => [3, 2, 1]}) in subst
