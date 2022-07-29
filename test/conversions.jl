@testset "Logical form conversions" begin

@test to_nnf(@julog(a)) == @julog a
@test to_nnf(@julog(and())) == @julog true
@test to_nnf(@julog(or())) == @julog false
@test to_nnf(@julog(and(a))) == @julog a
@test to_nnf(@julog(true => not(and(not(!a), b, or(not(c), false))))) ==
    @julog(or(not(a), not(b), c))
@test to_nnf(@julog(not(forall(human(X), mortal(X))))) ==
    @julog(exists(human(X), not(mortal(X))))
@test to_nnf(@julog(not(exists(god(X), mortal(X))))) ==
    @julog(forall(god(X), not(mortal(X))))

@test to_cnf(@julog(and(a))) == @julog and(or(a))
@test to_cnf(@julog(and(and(or(a, and(b, or(c, d))), or(e, f)), and(not(x), or(y, z))))) ==
    @julog(and(or(a, b), or(a, c, d), or(e, f), or(not(x)), or(y, z)))
@test to_cnf(@julog(true => not(and(not(!a), b, or(not(c), false))))) ==
    @julog(and(or(not(a), not(b), c)))

@test to_dnf(@julog(and(a))) == @julog or(and(a))
@test to_dnf(@julog(or(or(and(a, or(b, and(c, d))), and(e, f)), or(not(x), and(y, z))))) ==
    @julog(or(and(a, b), and(a, c, d), and(e, f), and(not(x)), and(y, z)))
@test to_dnf(@julog(true => not(and(not(!a), b, or(not(c), false))))) ==
    @julog(or(and(not(a)), and(not(b)), and(c)))

# Test flattening of conjuctions and disjunctions
@test flatten_conjs(@julog(and(a, and(b, c)))) == @julog Const[a, b, c]
@test flatten_conjs(@julog([a, and(b, c)])) == @julog Const[a, b, c]
@test flatten_disjs(@julog(or(a, or(b, c)))) == @julog Const[a, b, c]
@test flatten_disjs(@julog([a, or(b, c)])) == @julog Const[a, b, c]

# Test instantiation of universal quantifiers
clauses = @julog [
    block(a) <<= true,
    block(b) <<= true,
    block(c) <<= true,
    holding(a) <<= true
]
universal_term = @julog(forall(block(X), not(holding(X))))
@test deuniversalize(universal_term, clauses) ==
    @julog and(not(holding(a)), not(holding(b)), not(holding(c)))
universal_clause = Clause(@julog(handempty), [universal_term])
@test deuniversalize(universal_clause, clauses) ==
    @julog handempty <<= and(not(holding(a)), not(holding(b)), not(holding(c)))

# Test regularization of clause bodies
clauses = @julog [
    binary(X) <<= or(woman(X), man(X)) & not(nonbinary(X)),
    bigender(X) <<= and(woman(X), man(X)),
    nonbinary(X) <<= or(genderqueer(X), agender(X), thirdgender(X))
]

regularized = @julog [
    binary(X) <<= woman(X) & not(nonbinary(X)),
    binary(X) <<= man(X) & not(nonbinary(X)),
    bigender(X) <<= woman(X) & man(X),
    nonbinary(X) <<= genderqueer(X),
    nonbinary(X) <<= agender(X),
    nonbinary(X) <<= thirdgender(X)
]

@test regularize_clauses(clauses) == regularized

end
