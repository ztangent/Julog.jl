@testset "Custom function evaluation" begin

funcs = Dict()
funcs[:pi] = pi
funcs[:zero] = () -> 0
funcs[:sin] = sin
funcs[:cos] = cos
funcs[:square] = x -> x * x
funcs[:dup] = x -> (x, x)
funcs[:pair] = (x, y) -> (x, y)
funcs[:fst] = tup -> tup[1]
funcs[:snd] = tup -> tup[2]
funcs[:fakesum] = Dict((1, 1) => 2, (2, 2) => 4)

@test resolve(@julog(zero == 0), Clause[], funcs=funcs)[1] == true
@test resolve(@julog(sin(pi / 2) == 1), Clause[], funcs=funcs)[1] == true
@test resolve(@julog(cos(pi) == -1), Clause[], funcs=funcs)[1] == true
@test resolve(@julog(square(5) == 25), Clause[], funcs=funcs)[1] == true
@test resolve(@julog(dup(6) == pair(6, 6)), Clause[], funcs=funcs)[1] == true
@test resolve(@julog(fakesum(1, 1) == 2), Clause[], funcs=funcs)[1] == true
@test resolve(@julog(fakesum(2, 2) == 4), Clause[], funcs=funcs)[1] == true

clauses = @julog [
    even(X) <<= mod(X, 2) == 0,
    is_dup(X) <<= fst(X) == snd(X),
    is_square(5, 5, 25) <<= true
]

@test resolve(@julog(even(fakesum(1, 1))), clauses, funcs=funcs)[1] == true
@test resolve(@julog(is_dup(dup(8))), clauses, funcs=funcs)[1] == true
@test resolve(@julog(is_square(5, X, square(5))), clauses, funcs=funcs)[1] == true

clauses = @julog [
    on_circ(Rad, Pt) <<= square(fst(Pt)) + square(snd(Pt)) == square(Rad),
    on_diag(X, Y) <<= dup(X) == pair(X, Y)
]

# Is the point (3, -4) on the circle of radius 5?
@test resolve(@julog(on_circ(5, (3, -4))), clauses, funcs=funcs)[1] == true
# How about the point (5 * sin(1), 5 * cos(1))?
@test resolve(@julog(on_circ(5, pair(5*sin(1), 5*cos(1)))), clauses, funcs=funcs)[1] == true
# Is the point (10, 10) on the line X=Y?
@test resolve(@julog(on_diag(10, 10)), clauses, funcs=funcs)[1] == true

end
