# Test built-in math and comparison operators
@test resolve(@fol(1 == 1), Clause[])[1] == true
@test resolve(@fol(1 == 2), Clause[])[1] == false
@test resolve(@fol(1 != 2), Clause[])[1] == true
@test resolve(@fol(1 < 2), Clause[])[1] == true
@test resolve(@fol(3 > 2), Clause[])[1] == true
@test resolve(@fol(3 <= 4), Clause[])[1] == true
@test resolve(@fol(5 >= 4), Clause[])[1] == true

@test resolve(@fol(1 + 1 == 2), Clause[])[1] == true
@test resolve(@fol(5 - 6 == -1), Clause[])[1] == true
@test resolve(@fol(6 * 9 != 42), Clause[])[1] == true
@test resolve(@fol(8 * 8 > 7 * 9), Clause[])[1] == true
@test resolve(@fol(5 / 2 == 2.5), Clause[])[1] == true
@test resolve(@fol(mod(5, 2) == 1), Clause[])[1] == true

# Define addition using built-in operators
clauses = @fol [
    add(X, Y, Z) <<= is(Z, X + Y),
    add(X, Y, Z) <<= is(X, Z - Y),
    add(X, Y, Z) <<= is(Y, Z - X)
]

# Is 1 + 1 = 2?
@test resolve(@fol(add(1, 1, 2)), clauses)[1] == true
# What is 2 + 3?
@test @folsub({Z => 5}) in resolve(@fol(add(2, 3, Z)), clauses)[2]
# What is 5 - 2?
@test @folsub({X => 2}) in resolve(@fol(add(X, 3, 5)), clauses)[2]
# What is 5 - 3?
@test @folsub({Y => 3}) in resolve(@fol(add(2, Y, 5)), clauses)[2]
# Using is/2 doesn't allow us ask for all the ways to add to 5
@test resolve(@fol(add(X, Y, 5)), clauses)[1] == false
