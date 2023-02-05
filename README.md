# Julog.jl

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/ztangent/Julog.jl/CI)
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/ztangent/Julog.jl)
![License](https://img.shields.io/github/license/ztangent/Julog.jl?color=lightgrey)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliahub.com/docs/Julog)

A Julia package for Prolog-style logic programming.

## Installation

Enter the package manager by pressing `]` at the Julia REPL, then run:
```
add Julog
```
The latest development version can also be installed by running:
```
add <link to this git repository>
```

## Features

- [Prolog-like syntax](#syntax)
- [Interpolation of expressions](#interpolation)
- [Custom function support](#custom-functions)
- [Built-in predicates and logical connectives](#built-in-predicates)
- [Conversion utilities](#conversion-utilities)

## Usage

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
With the `resolve` function, we can query the knowledge base via [SLD resolution](https://en.wikipedia.org/wiki/SLD_resolution) (the form of backward-chaining proof search used by Prolog):
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

Forward-chaining proof search is supported as well, using `derive`. We can also compute the list of n-step derivations with `derivations(clauses, n)`:
```julia
# Facts derivable from one iteration through the rules
julia> derivations(clauses, 1)
16-element Array{Clause,1}:
 teacher(bodhidharma, huike)
 ⋮
 ancestor(sakyamuni, huike)

# The set of all derivable facts (i.e. the closure / fixed-point)
julia> derivations(clauses, Inf)
30-element Array{Clause,1}:
 teacher(bodhidharma, huike)
 ⋮
 ancestor(sakyamuni, huineng)
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

In words, `<<=` replaces the Prolog turnstile `:-`, `<<= true` or `'` replaces `.` when stating facts, `!` replaces `\+` for negation, there is no longer a special operator for `cut`, `&` replaces `,` in the bodies of definite clauses, and there is no `or` operator like the `;` in Prolog.

In addition, when constructing Prolog-style linked-lists, the syntax `@julog list[a, b, c]` should be used when the list is not nested within any other compound term. This is because the `@julog [a, b, c]` syntax is reserved for creating a *Julia* list of Julog objects, such as a list of Julog clauses. Lists which are nested within other term, e.g., `member(b, [a, b, c])`, are parsed in the same way as Prolog. (Note that list predicates like `member` are not [built-in predicates](#built-in-predicates), and have to be manually defined as a clause.)

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

Unlike Prolog, Julog also supports [extended unification](https://www.sciencedirect.com/science/article/pii/0743106687900021) via the evaluation of functional terms. In other words, the following terms unify:
```julia
julia> unify(@julog(f(X, X*Y, Y)), @julog(f(4, 20, 5)))
Dict{Var, Term} with 2 entries:
  Y => 5
  X => 4
```

However, the extent of such unification is limited. If variables used within a functional expression are not sufficiently instantiated at the time of evaluation, evaluation will be partial, causing unification to fail:
```julia
julia> unify(@julog(f(X, X*Y, Y)), @julog(f(X, 20, 5))) === nothing
true
```

## Built-in Predicates

`Julog` provides a number of built-in predicates for control-flow and convenience. Some of these are also part of ISO Prolog, but may not share the exact same behavior.

- `cons` and `cend` are reserved for lists. `[x, y, z]` is equivalent to `cons(x, cons(y, cons(z, cend()))`.
- `true` and `false` operate as one might expect.
- `and(A, B, C, ...)` is equivalent to `A & B & C & ...` in the body of an Julog clause.
- `or(A, B, C, ...)` is equivalent to `A ; B ; C ; ...` in Prolog-syntax.
- `not(X)` / `!X` is true if X cannot be proven (i.e. negation as failure).
- `unifies(X, Y)` / `X ≐ Y` is true if `X` unifies with `Y`.
- `exists(Cond, Act)` is true if `Act` is true for at least one binding of `Cond`.
- `forall(Cond, Act)` is true if `Act` is true for all possible bindings of `Cond` (beware infinite loops).
- `imply(Cond, Act)` / `Cond => Act` is true if either `Cond` is false, or both `Cond` and `Act` are true.
- `call(pred, A, B, ...)`, the meta-call predicate, is equivalent to `pred(A, B, ...)`.
- `findall(Template, Cond, List)` finds all instances where `Cond` is true, substitutes any variables into `Template`, and unifies `List` with the result.
- `countall(Cond, N)` counts the number of proofs of `Cond` and unifies `N` with the result.
- `fail` causes the current goal to fail (equivalent to `false`).
- `cut` causes the current goal to succeed and suppresses all other goals. However, this does not have the same effects as in Prolog because `Julog` uses breadth-first search during SLD-resolution, unlike most Prolog implementations, which use depth-first search.

See [`test/builtins.jl`](test/builtins.jl) for usage examples.

## Conversion Utilities

Julog provides some support for converting and manipulating logical formulae, for example, conversion to negation, conjunctive, or disjunctive normal form:
```julia
julia> formula = @julog and(not(and(a, not(b))), c)
julia> to_nnf(formula)
and(or(not(a), b), c)
julia> to_cnf(formula)
and(or(not(a), b), or(c))
julia> to_dnf(formula)
or(and(not(a), c), and(b, c))
```

This can be useful for downstream applications, such as classical planning. Note however that these conversions do not handle the implicit existential quantification in Prolog semantics, and hence are not guaranteed to preserve equivalence when free variables are involved. In particular, care should be taken with negations of conjunctions of unbound predicates. For example, the following expression states that "All ravens are black.":
```julia
@julog not(and(raven(X), not(black(X))))
```
However, `to_dnf` doesn't handle the implied existential quantifier over `X`, and gives the non-equivalent statement "Either there are no ravens, or there exist black things, or both.":
```julia
@julog or(and(not(raven(X))), and(black(X)))
```

## Related Packages

There are several other Julia packages related to Prolog and logic programming:

- [HerbSWIPL.jl](https://github.com/Herb-AI/HerbSWIPL.jl) is a wrapper around SWI-Prolog that uses the Julog parser and interface.
- [Problox.jl](https://github.com/femtomc/Problox.jl) is a lightweight Julia wrapper around [ProbLog](https://dtai.cs.kuleuven.be/problog/), a probabilistic variant of Prolog.

## Acknowledgements

This implementation was made with reference to Chris Meyer's [Python interpreter for Prolog](http://www.openbookproject.net/py4fun/prolog/intro.html), as well as the unification and SLD-resolution algorithms presented in [An Introduction to Prolog](https://link.springer.com/content/pdf/bbm%3A978-3-642-41464-0%2F1.pdf) by Pierre M. Nugues.
