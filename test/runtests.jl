using FOL
using Test

clauses = @fol [
    ancestor(sakyamuni, bodhidharma) <<= true,
    teacher(bodhidharma, huike) <<= true,
    teacher(huike, sengcan) <<= true,
    teacher(sengcan, daoxin) <<= true,
    teacher(daoxin, hongren) <<= true,
    teacher(hongren, huineng) <<= true,
    ancestor(A, B) <<= teacher(A, B),
    ancestor(A, C) <<= teacher(B, C) & ancestor(A, B),
    grandteacher(A, C) <<= teacher(A, B) & teacher(B, C)
]

goals = @fol [ancestor(sakyamuni, huineng)]
sat, subst = resolve(goals, clauses);
@test sat == true
