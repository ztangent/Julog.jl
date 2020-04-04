# Test conversion to and from Prolog

pl_input = @prolog """
    member(X, [X | Y]).
    member(X, [Y | YS]) :- member(X, YS).
    vertebrate(A) :- fish(A) ; amphibian(A) ; reptile(A) ; bird(A) ; mammal(A).
    bird(A) :- dinosaur(A), \\+reptile(A).
    reptile(A) :- member(A, .(stegosaurus, .(triceratops, []))).
    dinosaur(A) :- member(A, [archaeopteryx, stegosaurus, triceratops]).
"""

julog_clauses = @julog [
    member(X, [X | Y]) <<= true,
    member(X, [Y | YS]) <<= member(X, YS),
    vertebrate(A) <<= fish(A),
    vertebrate(A) <<= amphibian(A),
    vertebrate(A) <<= reptile(A),
    vertebrate(A) <<= bird(A),
    vertebrate(A) <<= mammal(A),
    bird(A) <<= dinosaur(A) & !reptile(A),
    reptile(A) <<= member(A, cons(stegosaurus, cons(triceratops, []))),
    dinosaur(A) <<= member(A, [archaeopteryx, stegosaurus, triceratops])
]

@test pl_input == julog_clauses

@test resolve(@prolog("bird(archaeopteryx)."), pl_input)[1] == true

pl_output = """
member(X, [X | Y]).
member(X, [Y | YS]) :- member(X, YS).
vertebrate(A) :- fish(A).
vertebrate(A) :- amphibian(A).
vertebrate(A) :- reptile(A).
vertebrate(A) :- bird(A).
vertebrate(A) :- mammal(A).
bird(A) :- dinosaur(A), \\+(reptile(A)).
reptile(A) :- member(A, [stegosaurus, triceratops]).
dinosaur(A) :- member(A, [archaeopteryx, stegosaurus, triceratops]).
"""

@test write_prolog(pl_input) == pl_output
