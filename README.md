# Julog.jl

A Julia package for Prolog-style logic programming.

## Features

- [Prolog-like syntax](#syntax)
- [Interpolation of expressions](#interpolation)
- [Custom function support](#custom-functions)
- [Built-in predicates and logical connectives](#built-in-predicates)

## Examples

[Terms](http://www.dai.ed.ac.uk/groups/ssp/bookpages/quickprolog/node5.html) and [Horn clauses](https://en.wikipedia.org/wiki/Horn_clause) can be expressed in Prolog-like syntax using the
`@julog` macro:
```julia
# This creates a term
@julog teacher(bodhidharma, huike)
# This creates a fact (a term which is asserted to be true)
@julog teacher(bodhidharma, huike) <<= true
# This creates a definite clause
@julog grandteacher(A, C) <<= teacher(A, B) & teacher(B, C)
```
The `@julog` macro can be also applied to a list of clauses to create a
knowledge base. We use the traditional [Zen lineage chart](https://en.wikipedia.org/wiki/Zen_lineage_charts) as an example:
```julia
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
```
We can then query the knowledge base via [SLD resolution](https://en.wikipedia.org/wiki/SLD_resolution):
```julia
# Query: Is Sakyamuni the dharma ancestor of Huineng?
julia> goals = @julog [ancestor(sakyamuni, huineng)]; # List of terms to query or prove
julia> sat, subst = resolve(goals, clauses);
julia> sat
true

# Query: Who are the grandteachers of whom?
julia> goals = @julog [grandteacher(X, Y)];
julia> sat, subst = resolve(goals, clauses);
julia> subst
4-element Array{Any,1}:
  {Y => sengcan, X => bodhidharma}
  {Y => daoxin, X => huike}
  {Y => hongren, X => sengcan}
  {Y => huineng, X => daoxin}
```

More examples can be found in the [`test`](test) folder.

## Syntax

`Julog` uses syntax very similar to Prolog. In particular, users should
note that argument-free terms with initial capitals are parsed as variables,
whereas lowercase terms are parsed as constants:
```julia
julia> typeof(@julog(Person))
Var
julia> typeof(@julog(person))
Const
```

However, several important operators differ from Prolog, as shown by the examples below:

| Julog                                      | Prolog                                 | Meaning                             |
|------------------------------------------|----------------------------------------|-------------------------------------|
| `human(socrates) <<= true`              | `human(socrates).`                     | Socrates is human.                  |
| `mortal(X) <<= human(X)`                 | `mortal(X) :- human(X).`               | If X is human, X is mortal.         |
| `!mortal(gaia)`                          | `\+mortal(gaia)`                       | Gaia is not mortal.                 |
| `mortal(X) <<= can_live(X) & can_die(X)` | `mortal(X) :- can_live(X), can_die(X)` | X is mortal if it can live and die. |

In words, `<<=` replaces the Prolog turnstile `:-`, `<<= true` replaces `.` when stating facts, `!` replaces `\+` for negation, there is no longer a special operator for `cut`, `&` replaces `,` in the bodies of definite clauses, and there is no `or` operator like the `;` in Prolog.

If Prolog syntax is preferred, the `@prolog` macro and `parse_prolog` functions can be used to convert Prolog strings directly to Julog constructs, while `write_prolog` converts a list of Julog clauses to a Prolog string. However, this conversion cannot presently handle all of Prolog syntax (e.g., nested infix operators or comparison operators such as `=:=`), and should be used with caution.

## Interpolation

Similar to [string interpolation](https://docs.julialang.org/en/latest/manual/strings/#string-interpolation-1) and [expression interpolation](https://docs.julialang.org/en/v1/manual/metaprogramming/#Expressions-and-evaluation-1) in Julia, you can interpolate Julia expressions when constructing `Julog` terms using the `@julog` macro. `Julog` supports two forms of interpolation. The first form is constant interpolation using the `$` operator, where ordinary Julia expressions are converted to `Const`s:

```julia
julia> e = exp(1)
2.718281828459045
julia> term = @julog irrational($e)
irrational(2.718281828459045)
julia> dump(term)
Compound
  name: Symbol irrational
  args: Array{Term}((1,))
    1: Const
      name: Float64 2.718281828459045
```

The second form is term interpolation using the `:` operator, where pre-constructed `Julog` terms are interpolated into a surrounding `Julog` expression:

```julia
julia> e = Const(exp(1))
2.718281828459045
julia> term = @julog irrational(:e)
irrational(2.718281828459045)
julia> dump(term)
Compound
  name: Symbol irrational
  args: Array{Term}((1,))
    1: Const
      name: Float64 2.718281828459045
```

Interpolation allows us to easily generate Julog knowledge bases programatically using Julia code:

```julia
julia> people = @julog [avery, bailey, casey, darcy];
julia> heights = [@julog(height(:p, cm($(rand(140:200))))) for p in people]
4-element Array{Compound,1}:
 height(avery, cm(155))
 height(bailey, cm(198))
 height(casey, cm(161))
 height(darcy, cm(175))
```

## Custom Functions

In addition to standard arithmetic functions, `Julog` supports the evaluation of custom functions during proof search, allowing users to leverage the full power of precompiled Julia code. This can be done by providing a dictionary of functions when calling `resolve`. This dictionary can also accept constants (allowing one to store, e.g., numeric-valued fluents), and lookup-tables. An example is shown below:

```julia
funcs = Dict()
funcs[:pi] = pi
funcs[:sin] = sin
funcs[:cos] = cos
funcs[:square] = x -> x * x
funcs[:lookup] = Dict((:foo,) => "hello", (:bar,) => "world")

@assert resolve(@julog(sin(pi / 2) == 1), Clause[], funcs=funcs)[1] == true
@assert resolve(@julog(cos(pi) == -1), Clause[], funcs=funcs)[1] == true
@assert resolve(@julog(lookup(foo) == "hello"), Clause[], funcs=funcs)[1] == true
@assert resolve(@julog(lookup(bar) == "world"), Clause[], funcs=funcs)[1] == true
```

See [`test/custom_funcs.jl`](test/custom_funcs.jl) for more examples.

## Built-in Predicates

`Julog` provides a number of built-in predicates for control-flow and convenience. Some of these are also part of ISO Prolog, but may not share the exact same behavior.

- `c` and `cend` are reserved for lists. `[x, y, z]` is equivalent to `c(x, c(y, c(z, cend()))`.
- `true` and `false` operate as one might expect.
- `and(A, B, C, ...)` is equivalent to `A & B & C & ...` in the body of an Julog clause.
- `or(A, B, C, ...)` is equivalent to `A ; B ; C ; ...` in Prolog-syntax.
- `not(X)` / `!X` is true if X cannot be proven (i.e. negation as failure).
- `unifies(X, Y)` is true if `X` unifies with `Y`.
- `exists(Cond, Act)` is true if `Act` is true for at least one binding of `Cond`.
- `forall(Cond, Act)` is true if `Act` is true for all possible bindings of `Cond` (beware infinite loops).
- `imply(Cond, Act)` / `Cond => Act` is true if either `Cond` is false, or both `Cond` and `Act` are true.
- `fail` causes the current goal to fail (equivalent to `false`).
- `cut` causes the current goal to succeed and suppresses all other goals. However, this does not have the same effects as in Prolog because `Julog` uses breadth-first search during SLD-resolution, unlike most Prolog implementations, which use depth-first search.

See [`test/builtins.jl`](test/builtins.jl) for usage examples.

## Acknowledgements

This implementation was made with reference to Chris Meyer's [Python interpreter for Prolog](http://www.openbookproject.net/py4fun/prolog/intro.html), as well as the unification and SLD-resolution algorithms presented in [An Introduction to Prolog](https://link.springer.com/content/pdf/bbm%3A978-3-642-41464-0%2F1.pdf) by Pierre M. Nugues.
