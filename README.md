# FOL.jl

A Julia package for first order logic (FOL) programming, based heavily on Prolog.

## Examples

[Terms](http://www.dai.ed.ac.uk/groups/ssp/bookpages/quickprolog/node5.html) and [Horn clauses](https://en.wikipedia.org/wiki/Horn_clause) can be expressed in Prolog-like syntax using the
`@fol` macro:
```julia
# This creates a term
@fol teacher(bodhidharma, huike)
# This creates a fact (a term which is asserted to be true)
@fol teacher(bodhidharma, huike) <<= true
# This creates a definite clause
@fol grandteacher(A, C) <<= teacher(A, B) & teacher(B, C)
```
The `@fol` macro can be also applied to a list of clauses to create a
knowledge base. We use the traditional [Zen lineage chart](https://en.wikipedia.org/wiki/Zen_lineage_charts) as an example:
```julia
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
```
We can then query the knowledge base via [SLD resolution](https://en.wikipedia.org/wiki/SLD_resolution):
```julia
# Query: Is Sakyamuni the dharma ancestor of Huineng?
julia> goals = @fol [ancestor(sakyamuni, huineng)]; # List of terms to query or prove
julia> sat, subst = resolve(goals, clauses);
julia> sat
true

# Query: Who are the grandteachers of whom?
julia> goals = @fol [grandteacher(X, Y)];
julia> sat, subst = resolve(goals, clauses);
julia> subst
4-element Array{Any,1}:
  {Y => sengcan, X => bodhidharma}
  {Y => daoxin, X => huike}
  {Y => hongren, X => sengcan}
  {Y => huineng, X => daoxin}
```

## Comparison with Prolog syntax

`FOL` uses syntax very similar to Prolog. In particular, users should
note that argument-free terms with initial capitals are parsed as variables,
whereas lowercase terms are parsed as constants:
```julia-repl
julia> typeof(@fol(Person))
Var
julia> typeof(@fol(person))
Const
```

However, several important operators differ from Prolog, as shown by the examples below:

| FOL                                      | Prolog                                 | Meaning                             |
|------------------------------------------|----------------------------------------|-------------------------------------|
| `human(socrates) <<= true.`              | `human(socrates).`                     | Socrates is human.                  |
| `mortal(X) <<= human(X)`                 | `mortal(X) :- human(X).`               | If X is human, X is mortal.         |
| `!mortal(gaia)`                          | `\+mortal(gaia)`                       | Gaia is not mortal.                 |
| `mortal(X) <<= can_live(X) & can_die(X)` | `mortal(X) :- can_live(X), can_die(X)` | X is mortal if it can live and die. |

In words, `<<=` replaces the Prolog turnstile `:-`, `<<= true` replaces `.` when stating facts, `!` replaces `\+` for negation, there is no longer a special
operator for `cut`, `&` replaces `,` in the bodies of
definite clauses, and there is no `or` operator like the `;` in Prolog.

## Acknowledgements

This implementation was made with reference to Chris Meyer's [Python interpreter for Prolog](http://www.openbookproject.net/py4fun/prolog/intro.html), as well as the unification and SLD-resolution algorithms presented in [An Introduction to Prolog](https://link.springer.com/content/pdf/bbm%3A978-3-642-41464-0%2F1.pdf) by Pierre M. Nugues.
