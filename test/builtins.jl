# Test handling of built in predicates

# Test handling of and/N and or/N
clauses = @fol [
    shocked(P) <<= and(surprised(P), upset(P)),
    upset(P) <<= or(unhappy(P), angry(P)),
]

# Avery is surprised. Are they shocked? (No.)
facts = @fol [surprised(avery) <<= true]
@test resolve(@fol(shocked(avery)), [facts; clauses])[1] == false
# Bailey is surprised and angry. Are they shocked? (Yes.)
facts = @fol [surprised(bailey) <<= true, angry(bailey) <<= true]
@test resolve(@fol(shocked(bailey)), [facts; clauses])[1] == true
# Casey is unhappy. Is anyone upset? (Yes, Casey.)
facts = @fol [unhappy(casey) <<= true]
@test @folsub({P => casey}) in resolve(@fol(upset(P)), [facts; clauses])[2]

# Test handling of unifies/2 and not/1
clauses = @fol [
    child(zeus, kronos) <<= true,
    child(hera, kronos) <<= true,
    sibling(A, B) <<= child(A, C) & child(B, C) & not(unifies(A, B)),
]

# Is Hera her own sibling? (No)
@test resolve(@fol(sibling(hera, hera)), clauses)[1] == false
# Is Hera the sibling of Zeus? (Yes)
@test resolve(@fol(sibling(hera, zeus)), clauses)[1] == true

# Test the is/2 predicate (see also math_ops.jl for more tests)
clauses = @fol [
    square(X, Y) <<= is(Y, X * X),
    cube(X, Y) <<= is(Y, X * X * X)
]

# Is the cube of -1 the negation of its square? (Yes)
@test resolve(@fol([square(-1, S), cube(-1, C), S == -C]), clauses)[1] == true
# Is the cube of 2 twice its square? (Yes)
@test resolve(@fol([square(2, S), cube(2, C), C == 2*S]), clauses)[1] == true

# Test negation and double negation
clauses = @fol [red(roses) <<= true, blue(violets) <<= true]
@test resolve(@fol(not(red(roses))), clauses)[1] == false
@test resolve(@fol(not(blue(violets))), clauses)[1] == false
@test resolve(@fol(not(not(red(roses)))), clauses)[1] == true
@test resolve(@fol(not(not(blue(violets)))), clauses)[1] == true

# Test cut and fail by preventing infinite loops
clauses = @fol [
    fakeloop1(A) <<= fakeloop1(B),
    fakeloop1(A) <<= cut,
    fakeloop2(A) <<= fail & fakeloop2(B),
]

@test resolve(@fol(fakeloop1(0)), clauses)[1] == true
@test resolve(@fol(fakeloop2(0)), clauses)[1] == false
