@testset "Zen lineage (example)" begin

# Test composition and transitive relations using the traditional Zen lineage
clauses = @julog [
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

# Is Sakyamuni the dharma ancestor of Huineng?
goals = @julog [ancestor(sakyamuni, huineng)]
sat, subst = resolve(goals, clauses);
@test sat == true

# Who are the grandteachers of whom?
goals = @julog [grandteacher(X, Y)]
sat, subst = resolve(goals, clauses)
subst = Set(subst)
@test @varsub({X => bodhidharma, Y => sengcan}) in subst
@test @varsub({X => huike, Y => daoxin}) in subst
@test @varsub({X => sengcan, Y => hongren}) in subst
@test @varsub({X => daoxin, Y => huineng}) in subst

# Test that forward chaining produces the same / correct results
fwd_sat, fwd_subst = derive(goals, clauses)
@test fwd_sat == sat
@test Set(fwd_subst) == subst
n_init = 6
n_ancestor = 5 + 15
n_grandteacher = 4
@test length(derivations(clauses, Inf)) == n_ancestor + n_grandteacher + n_init

# Test clause table manipulation
table = index_clauses(clauses[1:4])
table = insert_clauses!(table, clauses[4:end])
@test table == index_clauses(clauses)
subtract_clauses!(table, clauses[5:end])
@test Set(deindex_clauses(table)) == Set(clauses[1:4])

end
