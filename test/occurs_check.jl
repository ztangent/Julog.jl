# Test occurs check
@test unify(@julog(A), @julog(some_functor(A)), false) != nothing
@test unify(@julog(A), @julog(some_functor(A)), true) == nothing
