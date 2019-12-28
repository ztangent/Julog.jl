# Test occurs check
@test unify(@fol(A), @fol(some_functor(A)), false) != nothing
@test unify(@fol(A), @fol(some_functor(A)), true) == nothing
