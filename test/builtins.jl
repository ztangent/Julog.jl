@testset "Built-in predicates" begin

# Test handling of and/N and or/N
clauses = @julog [
    shocked(P) <<= and(surprised(P), upset(P)),
    upset(P) <<= or(unhappy(P), angry(P)),
]

# Avery is surprised. Are they shocked? (No.)
facts = @julog [surprised(avery) <<= true]
@test resolve(@julog(shocked(avery)), [facts; clauses])[1] == false
# Bailey is surprised and angry. Are they shocked? (Yes.)
facts = @julog [surprised(bailey) <<= true, angry(bailey) <<= true]
@test resolve(@julog(shocked(bailey)), [facts; clauses])[1] == true
# Casey is unhappy. Is anyone upset? (Yes, Casey.)
facts = @julog [unhappy(casey) <<= true]
@test @varsub({P => casey}) in resolve(@julog(upset(P)), [facts; clauses])[2]

# Test handling of unifies/2 and not/1
clauses = @julog [
    child(zeus, kronos) <<= true,
    child(hera, kronos) <<= true,
    sibling(A, B) <<= child(A, C) & child(B, C) & not(unifies(A, B)),
]

# Is Hera her own sibling? (No)
@test resolve(@julog(sibling(hera, hera)), clauses)[1] == false
# Is Hera the sibling of Zeus? (Yes)
@test resolve(@julog(sibling(hera, zeus)), clauses)[1] == true

# Test the is/2 predicate (see also math_ops.jl for more tests)
clauses = @julog [
    square(X, Y) <<= is(Y, X * X),
    cube(X, Y) <<= is(Y, X * X * X)
]

# Is the cube of -1 the negation of its square? (Yes)
@test resolve(@julog([square(-1, S), cube(-1, C), S == -C]), clauses)[1] == true
# Is the cube of 2 twice its square? (Yes)
@test resolve(@julog([square(2, S), cube(2, C), C == 2*S]), clauses)[1] == true

# Test negation and double negation
clauses = @julog [red(roses) <<= true, blue(violets) <<= true]
@test resolve(@julog(not(red(roses))), clauses)[1] == false
@test resolve(@julog(not(blue(violets))), clauses)[1] == false
@test resolve(@julog(not(not(red(roses)))), clauses)[1] == true
@test resolve(@julog(not(not(blue(violets)))), clauses)[1] == true

# Test exists/2, forall/2, implies/2
clauses = @julog [
    human(pythagoras) <<= true,
    human(pyrrho) <<= true,
    human(zeno) <<= true,
    human(epicurus) <<= true,
    human(aristotle) <<= true,
    human(plato) <<= true,
    god(hera) <<= true,
    god(zeus) <<= true,
    god(aphrodite) <<= true,
    god(ares) <<= true,
    person(X) <<= human(X),
    person(X) <<= god(X),
    mortal(X) <<= human(X),
    immortal(X) <<= god(X)
]

# Is there a human who is mortal? (Yes.)
@test resolve(@julog(exists(human(X), mortal(X))), clauses)[1] == true
# Is there a god who is immortal? (Yes.)
@test resolve(@julog(exists(god(X), immortal(X))), clauses)[1] == true
# Is there a person who is mortal? (Yes.)
@test resolve(@julog(exists(person(X), mortal(X))), clauses)[1] == true

# Are all persons mortal? (No.)
@test resolve(@julog(forall(person(X), mortal(X))), clauses)[1] == false
# Are all humans mortal? (Yes.)
@test resolve(@julog(forall(human(X), mortal(X))), clauses)[1] == true
# Are all gods immortal? (Yes.)
@test resolve(@julog(forall(god(X), immortal(X))), clauses)[1] == true

# Is it true that if Hera is mortal, she's human? (Yes, since she's not mortal.)
@test resolve(@julog(imply(mortal(hera), human(hera))), clauses)[1] == true
# Is it true that if Hera is immortal, she's human? (No.)
@test resolve(@julog(imply(immortal(hera), human(hera))), clauses)[1] == false
# Is it true that for all people, being a god implies immortality? (Yes.)
@test resolve(@julog(forall(person(X), god(X) => immortal(X))), clauses)[1] == true
# Is it true that for all people, being a person implies immortality? (No.)
@test resolve(@julog(forall(person(X), person(X) => mortal(X))), clauses)[1] == false

# Of those who are persons, which are immortal?
sat, subst = resolve(@julog(person(X) => immortal(X)), clauses)
ans = Set([@varsub({X => hera}), @varsub({X => zeus}),
           @varsub({X => aphrodite}), @varsub({X => ares})])
@test ans == Set(subst)

# Test findall/3 and countall/2
humans = @julog list[pythagoras, pyrrho, zeno, epicurus, aristotle, plato]
@test resolve(@julog(findall(X, human(X), :humans)), clauses)[1] == true
@test resolve(@julog(countall(human(X), 6)), clauses)[1] == true
gods = @julog list[hera, zeus, aphrodite, ares]
@test resolve(@julog(findall(X, god(X), :gods)), clauses)[1] == true
@test resolve(@julog(countall(god(X), 4)), clauses)[1] == true
persons = @julog list[pythagoras, pyrrho, zeno, epicurus, aristotle, plato,
                      hera, zeus, aphrodite, ares]
@test resolve(@julog(findall(X, person(X), :persons)), clauses)[1] == true
@test resolve(@julog(countall(person(X), 10)), clauses)[1] == true

# Test cut and fail by preventing infinite loops
clauses = @julog [
    fakeloop1(A) <<= fakeloop1(B),
    fakeloop1(A) <<= cut,
    fakeloop2(A) <<= fail & fakeloop2(B),
]

@test resolve(@julog(fakeloop1(0)), clauses)[1] == true
@test resolve(@julog(fakeloop2(0)), clauses)[1] == false

# Test the meta-call predicate call/N
clauses = @julog [
    test(x, y) <<= true,
    pred(test) <<= true,
    metatest1(A, B, C) <<= call(A, B, C),
    metatest2(A, B, C) <<= pred(A) & call(A, B, C)
]

@test_throws Exception resolve(@julog(call(P, A, B)), clauses)
@test @varsub({A => x, B => y}) in resolve(@julog(call(test, A, B)), clauses)[2]
@test @varsub({A => x, B => y}) in resolve(@julog(call(test(A), B)), clauses)[2]
@test @varsub({B => y}) in resolve(@julog(call(test(x), B)), clauses)[2]
@test @varsub({A => x}) in resolve(@julog(call(test(A), y)), clauses)[2]

@test_throws Exception resolve(@julog(metatest1(P, x, y)), clauses)
@test @varsub({B => y}) in resolve(@julog(metatest1(test, x, B)), clauses)[2]
@test @varsub({P => test}) in resolve(@julog(metatest2(P, x, y)), clauses)[2]
@test @varsub({B => y}) in resolve(@julog(metatest2(test, x, B)), clauses)[2]

end
