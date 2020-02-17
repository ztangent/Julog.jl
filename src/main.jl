"Recursive structure for representing goals."
mutable struct GoalTree
    term::Term # Term to be proven
    parent::Union{GoalTree,Nothing} # Parent goal
    children::Vector{Term} # List of subgoals
    active::Int # Index of active subgoal
    env::Subst # Dictionary of variable mappings
end

GoalTree(g::GoalTree) =
    GoalTree(g.term, g.parent, copy(g.children), g.active, copy(g.env))

"Built-in arithmetic operations."
const math_ops = Set([:+, :-, :*, :/, :mod])
"Built-in comparison operations."
const comp_ops = Set([:(==), :<=, :>=, :<, :>, :(!=)])
"Built-in operators."
const ops = union(math_ops, comp_ops)
"Built-in functions."
const default_funcs = Dict(op => (args...) -> eval(op)(args...) for op in ops)
"Built-in predicates with special handling during SLD resolution."
const builtins = union(comp_ops, Set([
    true, false, :and, :or,
    :unifies, :is, :not, :!,
    :exists, :forall, :imply, :(=>),
    :cut, :fail
]))

"
    eval_term(term, env[, funcs])

Given an environment, evaluate all variables in a FOL term to constants.
Returns a term that is as fully evaluated as possible.

# Arguments
- `term::Term`: A term to evaluate.
- `env::Dict{Var,Term}`: An environment mapping variables to terms.
- `funcs::Dict=Dict()`: Additional custom functions (e.g. custom math).
"
eval_term(term::Term, env::Subst, funcs::Dict=Dict()) = error("Not implemented")
eval_term(term::Const, env::Subst, funcs::Dict=Dict()) =
    term.name in keys(funcs) ? Const(funcs[term.name]) : term
eval_term(term::Var, env::Subst, funcs::Dict=Dict()) =
    term in keys(env) ? eval_term(env[term], env, funcs) : term
function eval_term(term::Compound, env::Subst, funcs::Dict=Dict())
    args = Term[eval_term(a, env, funcs) for a in term.args]
    funcs = merge(default_funcs, funcs)
    if term.name in keys(funcs) && all([isa(a, Const) for a in args])
        func = funcs[term.name]
        if isa(func, Function)
            # Evaluate function if all arguments are fully evulated
            return Const(func([a.name for a in args]...))
        elseif isa(func, Dict)
            # Lookup value if custom function is a lookup table
            key = Tuple(a.name for a in args)
            @assert (key in keys(func)) "$(term.name)$key is undefined."
            return Const(func[key])
        else
            error("$(term.name) is neither a custom function or lookup table.")
        end
    else
        return Compound(term.name, args)
    end
end

"""
    unify(src, dst[, occurs_check])

Unifies src with dst and returns a dictionary of any substitutions needed.

# Arguments
- `src::Term`: A term to unify.
- `dst::Term`: A term to unify (src/dst order does not matter).
- `occurs_check::Bool=true`: Whether to perform the occurs check.
"""
function unify(src::Term, dst::Term, occurs_check::Bool=true)
    stack = Tuple{Term, Term}[(src, dst)]
    subst = Subst()
    success = true
    while length(stack) > 0
        (src, dst) = pop!(stack)
        @debug "Unify $src with $dst"
        if isa(src, Const) && isa(dst, Const)
            if src.name == dst.name
                @debug "Yes: equal constants"
                continue
            else
                @debug "No: diff constants"
                success = false
                break
            end
        elseif isa(src, Var)
            if isa(dst, Var) && src.name == dst.name
                @debug "Yes: same variable"
                continue
            elseif occurs_check && occurs_in(src, dst)
                @debug "No: $src occurs in $dst"
                success = false
                break
            end
            @debug "Yes: substitute $src with $dst"
            # Replace src with dst in stack
            stack = Tuple{Term, Term}[(substitute(s, src, dst),
                                       substitute(d, src, dst))
                                      for (s, d) in stack]
            # Replace src with dst in substitution values
            for (k, v) in subst
                subst[k] = substitute(v, src, dst)
            end
            # Add substitution of src to dst
            subst[src] = dst
        elseif isa(dst, Var)
            @debug "Swap $dst and $src"
            push!(stack, (dst, src))
        elseif isa(src, Compound) && isa(dst, Compound)
            if src.name != dst.name
                @debug "No: diff functors"
                success = false
                break
            elseif length(src.args) != length(dst.args)
                @debug "No: diff arity"
                success = false
                break
            end
            @debug "Yes: pushing args onto stack"
            stack = vcat(stack, collect(zip(src.args, dst.args)))
        else
            # Reaches here if one term is compound and the other is constant
            @debug "No: Can't unify constant with compound"
            success = false
        end
    end
    return success ? subst : nothing
end

"Handle built-in predicates"
function handle_builtins!(queue, clauses, goal, term; options...)
    funcs = get(options, :funcs, Dict())
    if term.name == true
        return true
    elseif term.name == false
        return false
    elseif term.name == :is
        # Handle is/2 predicate
        qn, ans = term.args[1], eval_term(term.args[2], goal.env, funcs)
        # Failure if RHS is insufficiently instantiated
        if !isa(ans, Const) return false end
        # LHS can either be a variable or evaluate to a constant
        if isa(qn, Var) && !(qn in keys(goal.env))
            # If LHS is a free variable, bind to RHS
            for (k, v) in goal.env
                goal.env[k] = substitute(v, qn, ans)
            end
            goal.env[qn] = ans
            return true
        else
            # If LHS evaluates to a constant, check if it is equal to RHS
            qn = eval_term(qn, goal.env, funcs)
            return isa(qn, Const) ? qn == ans : false
        end
        return false
    elseif term.name == :unifies
        # Check if all arguments unify
        term = substitute(term, goal.env)
        occurs_check = get(options, :occurs_check, false)
        for i in 1:(length(term.args)-1)
            if unify(term.args[i], term.args[i+1], occurs_check) == nothing
                return false
            end
        end
        return true
    elseif term.name == :and
        # Remove self and add all arguments as children to the goal, succeed
        splice!(goal.children, goal.active, term.args)
        goal.active -= 1
        return true
    elseif term.name == :or
        # Create new goals for each term in disjunct, add to queue
        for arg in term.args
            g = GoalTree(goal)
            g.children[g.active] = arg # Replace disjunct with term
            push!(queue, g)
        end
        # No longer work on this goal
        return false
    elseif term.name in [:not, :!]
        # Try to resolve negated predicate, return true upon failure
        neg_goal = term.args[1]
        sat, _ = resolve(Term[neg_goal], clauses; options...,
                         env=copy(goal.env), mode=:any)
        return !sat # Success if no proof is found
    elseif term.name == :exists
        # exists(Cond, Body) holds if Body holds for at least 1 binding of Cond
        cond, body = term.args[1], term.args[2]
        sat, subst = resolve(Term[cond, body], clauses; options...,
                             env=copy(goal.env), mode=:any)
        # Update bindings if satisfied
        goal.env = sat ? compose(goal.env, subst[1]) : goal.env
        return sat
    elseif term.name == :forall
        # forall(Cond, Body) holds if Body holds for all bindings of Cond
        cond, body = term.args[1], term.args[2]
        term = @fol(not(and(:cond, not(:body)))) # Rewrite term
        goal.children[goal.active] = term # Replace term
        goal.active -= 1
        return true
    elseif term.name in [:imply, :(=>)]
        # imply(Cond, Body) holds if or(not(Cond), Body) holds
        cond, body = term.args[1], term.args[2]
        sat, _ = resolve(Term[cond], clauses; options...,
                         env=copy(goal.env), mode=:any)
        # Return true if Cond does not hold
        if !sat return true end
        # Otherwise replace original term with [Cond, Body], return true
        splice!(goal.children, goal.active, [cond, body])
        goal.active -= 1
        return true
    elseif term.name == :cut
        # Remove all other goals and succeed
        empty!(queue)
        return true
    elseif term.name == :fail
        # Fail and skip goal
        return false
    elseif term.name in comp_ops
        result = eval_term(term, goal.env, funcs)
        return (isa(result, Const) && result.name == true)
    end
    return false
end

"Nested dictionary to store indexed clauses."
ClauseTable = Dict{Symbol,Dict{Symbol,Vector{Clause}}}

"Index clauses by functor name and first argument for efficient look-up."
function index_clauses(clauses::Vector{Clause})
    table = ClauseTable()
    for c in clauses
        subtable = get!(table, c.head.name, Dict{Symbol,Vector{Clause}}())
        if isa(c.head, Compound) && length(c.head.args) >= 1
            arg = c.head.args[1]
            if isa(arg, Var)
                push!(get!(subtable, :__var__, Clause[]), c)
            else
                push!(get!(subtable, Symbol(arg.name), Clause[]), c)
            end
            push!(get!(subtable, :__all__, Clause[]), c)
        else
            push!(get!(subtable, :__no_args__, Clause[]), c)
        end
    end
    return table
end

"Retrieve matching clauses from indexed clause table."
function retrieve_clauses(term::Term, table::ClauseTable)
    clauses = Clause[]
    if term.name in keys(table)
        subtable = table[term.name]
        if isa(term, Compound) && length(term.args) >= 1
            arg = term.args[1]
            if isa(arg, Var)
                clauses = get(subtable, :__all__, Clause[])
            else
                clauses = [get(subtable, Symbol(arg.name), Clause[]);
                           get(subtable, :__var__, Clause[])]
            end
        else
            clauses = get(subtable, :__no_args__, Clause[])
        end
    end
    return clauses
end

"""
    resolve(goals, clauses; <keyword arguments>)

SLD-resolution of goals with additional Prolog-like control flow.

# Arguments
- `goals::Vector{<:Term}`: A list of FOL terms to be prove or query.
- `clauses::Vector{Clause}`: A list of FOL clauses.
- `env::Subst=Subst([])`: An initial environment mapping variables to terms.
- `mode::Symbol=:all`: How results should be returned.
  `:all` returns all possible substitiutions. `:any` returns the first
  satisfying substitution found. `:interactive` prompts for continuation
  after each satisfying substitution is found.
- `occurs_check::Bool=false`: Flag for occurs check during unification
- `funcs::Dict=Dict()`: Custom functions for evaluating terms.
  A function `f` should be stored as funcs[:f] = f
"""
function resolve(goals::Vector{<:Term}, clauses::Vector{Clause}; options...)
    return resolve(goals, index_clauses(clauses); options...)
end

function resolve(goals::Vector{<:Term}, clauses::ClauseTable; options...)
    # Unpack options
    env = Subst(get(options, :env, []))
    occurs_check = get(options, :occurs_check, false)
    mode = get(options, :mode, :all)
    # Construct top level goal and put it on the queue
    queue = [GoalTree(Const(false), nothing, Vector{Term}(goals), 1, env)]
    subst = []
    # Iterate across queue of goals
    while length(queue) > 0
        goal = popfirst!(queue)
        @debug string("Goal: ", Clause(goal.term, goal.children), " ",
                      "Env: ", goal.env)
        if goal.active > length(goal.children)
            # All subgoals are done
            if goal.parent == nothing
                # If goal has no parent, we are successful
                @debug string("Success: ", goal.env)
                if !(goal.env in subst)
                    push!(subst, goal.env)
                end
                if (mode == :all) continue
                elseif (mode == :any || length(queue) == 0) break
                elseif mode == :interactive
                    # Interactively prompt for continuation
                    println(goal.env)
                    print("Continue? [y/n]: ")
                    s = readline()
                    if s in ["y", "Y", ""] continue
                    else break
                    end
                end
            end
            @debug string("Done, returning to parent.")
            # Copy construct parent to create fresh copy of environment
            parent = GoalTree(goal.parent)
            # Unify goal term with corresponding term in parent
            src = substitute(goal.term, goal.env)
            dst = parent.children[parent.active]
            unif = unify(src, dst, occurs_check)
            parent.env = compose(parent.env, unif)
            # Advance parent to next subgoal and put it back on the queue
            parent.active += 1
            push!(queue, parent)
            continue
        end
        # Examine current subgoal
        term = goal.children[goal.active]
        @debug string("Subgoal: ", term)
        # Handle built-in special terms
        if term.name in builtins
            success = handle_builtins!(queue, clauses, goal, term; options...)
            # If successful, go to next subgoal, otherwise skip to next goal
            if success
                @debug string("Done, returning to parent.")
                goal.active += 1
                push!(queue, goal)
            end
            continue
        end
        # Substitute variables in term
        term = freshen(substitute(term, goal.env))
        # Iterate across clause set with matching heads
        matched_clauses = retrieve_clauses(term, clauses)
        matched = false
        for c in matched_clauses
            # If term unifies with head of a clause, add it as a subgoal
            child_env = unify(term, c.head, occurs_check)
            if child_env != nothing
                child = GoalTree(c.head, goal, copy(c.body), 1, child_env)
                push!(queue, child)
                matched = true
            end
        end
        if !matched @debug string("Failed, no matching clauses.") end
    end
    # Goals were satisfied if we found valid substitutions
    return (length(subst) > 0), subst
end

"Resolve a single term with respect to a set of clauses."
resolve(goal::Term, clauses::Vector{Clause}; options...) =
    resolve(Term[goal], clauses; options...)

"Resolve a set of clauses as goals by converting them to terms."
resolve(goals::Vector{Clause}, clauses::Vector{Clause}; options...) =
    resolve([convert(Term, g) for g in goals], clauses; options...)
