# FOL.jl

A Julia library for first order logic (FOL) programming, based heavily on Prolog.

## Example

Terms and Horn clauses can be expressed in Prolog-like syntax using the
`@fol` macro:
```
# This creates a term
@fol teacher(bodhidharma, huike)
# This creates a fact (a term which is asserted to be true)
@fol teacher(bodhidharma, huike) <<= true
# This creates a definite clause
@fol grandteacher(A, C) <<= teacher(A, B) & teacher(B, C)
```
The `@fol` macro can be also applied to a list of clauses to create a
knowledge base. We use the traditional Zen lineage chart as an example:
```
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
We can then query the knowledge base via SLD resolution:
```
# Is Sakyamuni the dharma ancestor of Huineng?
goals = @fol [ancestor(sakyamuni, huineng)]; # List of terms to query or prove
sat, subst = resolve(goals, clauses);
sat
# Output: true
```
```
# Who are the grandteachers of whom?
goals = @fol [grandteacher(X, Y)];
sat, subst = resolve(goals, clauses);
subst
# Output:
# 4-element Array{Any,1}:
#  {Y => sengcan, X => bodhidharma}
#  {Y => daoxin, X => huike}
#  {Y => hongren, X => sengcan}
#  {Y => huineng, X => daoxin}
```
