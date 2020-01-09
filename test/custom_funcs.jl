# Test evaluation of custom functions
funcs = Dict()
funcs[:sin] = sin
funcs[:cos] = cos
funcs[:square] = x -> x * x
funcs[:dup] = x -> (x, x)
funcs[:pair] = (x, y) -> (x, y)
funcs[:fst] = tup -> tup[1]
funcs[:snd] = tup -> tup[2]

@test resolve(@fol(sin($pi / 2) == 1), Clause[], funcs=funcs)[1] == true
@test resolve(@fol(cos($pi) == -1), Clause[], funcs=funcs)[1] == true
@test resolve(@fol(square(5) == 25), Clause[], funcs=funcs)[1] == true
@test resolve(@fol(dup(6) == pair(6, 6)), Clause[], funcs=funcs)[1] == true

clauses = @fol [
    on_circ(Rad, Pt) <<= square(fst(Pt)) + square(snd(Pt)) == square(Rad),
    on_diag(X, Y) <<= dup(X) == pair(X, Y)
]

# Is the point (3, -4) on the circle of radius 5?
@test resolve(@fol(on_circ(5, (3, -4))), clauses, funcs=funcs)[1] == true
# How about the point (5 * sin(1), 5 * cos(1))?
@test resolve(@fol(on_circ(5, pair(5*sin(1), 5*cos(1)))), clauses, funcs=funcs)[1] == true
# Is the point (10, 10) on the line X=Y?
@test resolve(@fol(on_diag(10, 10)), clauses, funcs=funcs)[1] == true