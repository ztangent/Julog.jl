# Test built-in math and comparison operators
@test resolve(@julog(1 == 1), Clause[])[1] == true
@test resolve(@julog(1 == 2), Clause[])[1] == false
@test resolve(@julog(1 != 2), Clause[])[1] == true
@test resolve(@julog(1 < 2), Clause[])[1] == true
@test resolve(@julog(3 > 2), Clause[])[1] == true
@test resolve(@julog(3 <= 4), Clause[])[1] == true
@test resolve(@julog(5 >= 4), Clause[])[1] == true

@test resolve(@julog(1 + 1 == 2), Clause[])[1] == true
@test resolve(@julog(5 - 6 == -1), Clause[])[1] == true
@test resolve(@julog(6 * 9 != 42), Clause[])[1] == true
@test resolve(@julog(8 * 8 > 7 * 9), Clause[])[1] == true
@test resolve(@julog(5 / 2 == 2.5), Clause[])[1] == true
@test resolve(@julog(mod(5, 2) == 1), Clause[])[1] == true

# Define addition using built-in operators
clauses = @julog [
    add(X, Y, Z) <<= is(Z, X + Y),
    add(X, Y, Z) <<= is(X, Z - Y),
    add(X, Y, Z) <<= is(Y, Z - X)
]

# Is 1 + 1 = 2?
@test resolve(@julog(add(1, 1, 2)), clauses)[1] == true
# What is 2 + 3?
@test @varsub({Z => 5}) in resolve(@julog(add(2, 3, Z)), clauses)[2]
# What is 5 - 2?
@test @varsub({X => 2}) in resolve(@julog(add(X, 3, 5)), clauses)[2]
# What is 5 - 3?
@test @varsub({Y => 3}) in resolve(@julog(add(2, Y, 5)), clauses)[2]
# Using is/2 doesn't allow us ask for all the ways to add to 5
@test resolve(@julog(add(X, Y, 5)), clauses)[1] == false
