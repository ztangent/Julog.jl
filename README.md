# FOL.jl

A Julia package for first order logic (FOL) programming, based heavily on Prolog.

## Example

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

## Acknowledgements

This implementation was made by referring to Chris Meyer's [Python interpreter for Prolog](http://www.openbookproject.net/py4fun/prolog/intro.html), as well as the unification and SLD-resolution algorithms presented in [An Introduction to Prolog](https://link.springer.com/content/pdf/bbm%3A978-3-642-41464-0%2F1.pdf) by Pierre M. Nugues.
