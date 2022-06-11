"Recursive structure for representing goals."
mutable struct GoalTree
    term::Term # Term to be proven
    parent::Union{GoalTree,Nothing} # Parent goal
    children::Vector{Term} # List of subgoals
    active::Int # Index of active subgoal
    env::Subst # Dictionary of variable mappings for the current goal
    vmap::Subst # Variables inherited from parent
end

GoalTree(g::GoalTree) =
    GoalTree(g.term, g.parent, copy(g.children), g.active, copy(g.env), g.vmap)

"Built-in arithmetic operations."
const math_ops = Set([:+, :-, :*, :/, :mod])
"Built-in comparison operations."
const comp_ops = Set([:(==), :<=, :>=, :<, :>, :(!=)])
"Built-in operators."
const ops = union(math_ops, comp_ops)
"Built-in functions."
const default_funcs = Dict(op => eval(op) for op in ops)
"Built-in logical connectives."
const logicals = Set([true, false, :and, :or, :not, :!,
                      :exists, :forall, :imply, :(=>)])
"Built-in predicates with special handling during SLD resolution."
const builtins = union(comp_ops, logicals,
    Set([:is, :call, :unifies, :≐, :cut, :fail, :findall, :countall]))

"""
    eval_term(term, env[, funcs])

Given an environment, evaluate all variables in a Julog term to constants.
Returns a term that is as fully evaluated as possible.

# Arguments
- `term::Term`: A term to evaluate.
- `env::Dict{Var,Term}`: An environment mapping variables to terms.
- `funcs::Dict=Dict()`: Additional custom functions (e.g. custom math).
"""
eval_term(term::Term, env::Subst, funcs::Dict=Dict()) = error("Not implemented")
eval_term(term::Var, env::Subst, funcs::Dict=Dict()) =
    term in keys(env) ? eval_term(env[term], env, funcs) : term
function eval_term(term::Const, env::Subst, funcs::Dict=Dict())
    val = get(funcs, term.name, term)
    if val === term
        return val
    elseif isa(val, Function)
        return Const(val())
    else
        return Const(val)
    end
end
function eval_term(term::Compound, env::Subst, funcs::Dict=Dict())
    args = Term[eval_term(a, env, funcs) for a in term.args]
    func = get(funcs, term.name) do
        get(default_funcs, term.name, nothing)
    end
    if func !== nothing && all(isa(a, Const) for a in args)
        if isa(func, Function)
            # Evaluate function if all arguments are fully evulated
            return Const(func((a.name for a in args)...))
        elseif isa(func, Dict)
            # Lookup value if custom function is a lookup table
            key = Tuple(a.name for a in args)
            if key in keys(func) return Const(func[key]) end
            # Leave un-evaluated if lookup table has missing entries
            return Compound(term.name, args)
        else
            error("$(term.name) is neither a custom function or lookup table.")
        end
    else
        return Compound(term.name, args)
    end
end

"""
    unify(src, dst[, occurs_check, funcs])

Unifies src with dst and returns a dictionary of any substitutions needed.

# Arguments
- `src::Term`: A term to unify.
- `dst::Term`: A term to unify (src/dst order does not matter).
- `occurs_check::Bool=true`: Whether to perform the occurs check.
- `funcs::Dict=Dict()`: Custom functions to evaluate.
"""
function unify(src::Term, dst::Term,
               occurs_check::Bool=true, funcs::Dict=Dict())
    src_stack, dst_stack = Term[src], Term[dst]
    src_defer, dst_defer = Term[], Term[]
    subst = Subst()
    success = true
    while length(src_stack) > 0
        src, dst = pop!(src_stack), pop!(dst_stack)
        # Unify $src with $dst
        if isa(src, Const) && isa(dst, Const)
            success = _unify!(src::Const, dst, funcs)
            if !success break end
        elseif isa(src, Var)
            success = _unify!(src::Var, dst, src_stack, dst_stack,
                              subst, occurs_check)
            if !success break end
        elseif isa(dst, Var)
            success = _unify!(dst::Var, src, dst_stack, src_stack,
                              subst, occurs_check)
            if !success break end
        elseif isa(src, Compound) && isa(dst, Compound)
            success = _unify!(src::Compound, dst, src_stack, dst_stack)
            if !success break end
        elseif isa(src, Const) && isempty(dst.args)
            success = _unify!(src::Const, dst, funcs)
            if !success break end
        elseif isa(dst, Const) && isempty(src.args)
            success = _unify!(dst::Const, src, funcs)
            if !success break end
        else # Reaches here if one term is compound and the other is constant
            push!(src_defer, src)
            push!(dst_defer, dst)
        end
    end
    # Try evaluating deferred Const vs Compound comparisons
    for (src, dst) in zip(src_defer, dst_defer)
        src, dst = eval_term(src, subst, funcs), eval_term(dst, subst, funcs)
        if src != dst # "No: cannot unify $src and $dst after evaluation"
            success = false; break
        end
    end
    return success ? subst : nothing
end

function _unify!(src::Const, dst::Term, funcs::Dict=Dict())
     if src.name != dst.name
         src_val = get(funcs, src.name, src.name)
         dst_val = get(funcs, dst.name, dst.name)
         return src_val == dst_val
     end
     return true
end

function _unify!(src::Var, dst::Term, src_stack, dst_stack,
                 subst, occurs_check::Bool=true)
    if isa(dst, Var) && src.name == dst.name # "Yes: same variable"
        return true
    elseif occurs_check && occurs_in(src, dst) # "No: src occurs in dst"
        return false
    end
    # Replace src with dst in stack
    for i in 1:length(src_stack)
        s, d = src_stack[i], dst_stack[i]
        ss = substitute(s, src, dst)
        if s !== ss src_stack[i] = ss end
        dd = substitute(d, src, dst)
        if d !== dd dst_stack[i] = dd end
    end
    # Replace src with dst in substitution values
    map!(v -> substitute(v, src, dst), values(subst))
    # Add substitution of src to dst
    subst[src] = dst
    return true
end

function _unify!(src::Compound, dst::Term, src_stack, dst_stack)
    if src.name != dst.name # "No: diff functors"
        return false
    elseif length(src.args) != length(dst.args) # "No: diff arity"
        return false
    end
    # "Yes: pushing args onto stack"
    append!(src_stack, src.args)
    append!(dst_stack, dst.args)
    return true
end

"Handle built-in predicates"
function handle_builtins!(queue, clauses, goal, term; options...)
    funcs = get(options, :funcs, Dict())
    occurs_check = get(options, :occurs_check, false)
    vcount = get(options, :vcount, Ref(UInt(0)))
    if term.name == true
        return true
    elseif term.name == false
        return false
    elseif term.name == :call
        # Handle meta-call predicate
        pred, args = term.args[1], term.args[2:end]
        if isa(pred, Var) pred = get(goal.env, pred, nothing) end
        if isnothing(pred) error("$term not sufficiently instantiated.") end
        term = Compound(pred.name, [pred.args; args]) # Rewrite term
        goal.children[goal.active] = term # Replace term
        goal.active -= 1
        return true
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
    elseif term.name in [:unifies, :≐]
        # Check if LHS and RHS unify
        term = substitute(term, goal.env)
        lhs, rhs = term.args[1], term.args[2]
        unifier = unify(lhs, rhs, occurs_check, funcs)
        if isnothing(unifier) return false end
        compose!(goal.env, unifier) # Update variable bindings if satisfied
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
                         vcount=vcount, env=copy(goal.env), mode=:any)
        return !sat # Success if no proof is found
    elseif term.name == :exists
        # exists(Cond, Body) holds if Body holds for at least 1 binding of Cond
        cond, body = term.args
        sat, subst = resolve(Term[cond, body], clauses; options...,
                             vcount=vcount, env=copy(goal.env), mode=:any)
        # Update variable bindings if satisfied
        goal.env = sat ? compose!(goal.env, subst[1]) : goal.env
        return sat
    elseif term.name == :forall
        # forall(Cond, Body) holds if Body holds for all bindings of Cond
        cond, body = term.args
        term = @julog(not(and(:cond, not(:body)))) # Rewrite term
        goal.children[goal.active] = term # Replace term
        goal.active -= 1
        return true
    elseif term.name in [:imply, :(=>)]
        # imply(Cond, Body) holds if or(not(Cond), Body) holds
        cond, body = term.args
        sat, _ = resolve(Term[cond], clauses; options...,
                         vcount=vcount, env=copy(goal.env), mode=:any)
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
    elseif term.name == :findall
        # Find list of all cond matches, substituted into template
        template, cond, list = term.args
        _, subst = resolve(Term[cond], clauses; options...,
                           vcount=vcount, env=copy(goal.env), mode=:all)
        matches = to_term_list([substitute(template, s) for s in subst])
        unifier = unify(list, matches, occurs_check, funcs)
        if isnothing(unifier) return false end
        compose!(goal.env, unifier) # Update variable bindings if satisfied
        return true
    elseif term.name == :countall
        # Count number of ways to prove the condition
        cond, count = term.args
        _, subst = resolve(Term[cond], clauses; options...,
                           vcount=vcount, env=copy(goal.env), mode=:all)
        unifier = unify(count, Const(length(subst)), occurs_check, funcs)
        if isnothing(unifier) return false end
        compose!(goal.env, unifier) # Update variable bindings if satisfied
        return true
    elseif term.name in comp_ops || term.name in keys(funcs)
        defer_eval = get(options, :defer_eval, false)
        result = eval_term(term, goal.env, funcs)
        if isa(result, Const)
            # Return true if term evaluates to true
            return result.name == true
        elseif defer_eval && goal.active < length(goal.children)
            # Defer evaluation
            goal.children[goal.active] = goal.children[goal.active + 1]
            goal.children[goal.active + 1] = term
            goal.active -= 1
            return true
        end
    end
    return false
end

"""
    resolve(goals, clauses; <keyword arguments>)
    bwd_chain(goals, clauses; <keyword arguments>)

SLD-resolution of goals with additional Prolog-like control flow.

# Arguments
- `goals::Vector{<:Term}`: A list of Julog terms to be prove or query.
- `clauses::Vector{Clause}`: A list of Julog clauses.
- `env::Subst=Subst()`: An initial environment mapping variables to terms.
- `funcs::Dict=Dict()`: Custom functions for evaluating terms.
  A function `f` should be stored as `funcs[:f] = f`
- `mode::Symbol=:all`: How results should be returned.
  `:all` returns all possible substitiutions. `:any` returns the first
  satisfying substitution found. `:interactive` prompts for continuation
  after each satisfying substitution is found.
- `search::Symbol=:bfs`: search either breadth (`:bfs`) or depth-first (`:dfs`)
- `occurs_check::Bool=false`: Flag for occurs check during unification
- `defer_eval::Bool=false`: Flag to defer evaluation of (custom) operators.
"""
function resolve(goals::Vector{<:Term}, clauses::Vector{<:AbstractClause}; options...)
    return resolve(goals, index_clauses(clauses); options...)
end

function resolve(goals::Vector{<:Term}, clauses::ClauseTable; options...)
    # Unpack options
    env = get(options, :env, Subst())::Subst
    funcs = get(options, :funcs, Dict())::Dict
    mode = get(options, :mode, :all)::Symbol
    search = get(options, :search, :bfs)::Symbol
    occurs_check = get(options, :occurs_check, false)::Bool
    vcount = get(options, :vcount, Ref(UInt(0)))::Ref{UInt}
    # Construct top level goal and put it on the queue
    queue = [GoalTree(Const(false), nothing, Vector{Term}(goals), 1, env, Subst())]
    subst = Subst[]
    # Iterate across queue of goals
    while length(queue) > 0
        goal = (search == :dfs) ? pop!(queue) : popfirst!(queue)
        @debug string("Goal: ", Clause(goal.term, goal.children), " ",
                      "Env: ", goal.env)
        if goal.active > length(goal.children)
            # All subgoals are done
            if isnothing(goal.parent)
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
            # Remap variables from child to parent
            vmap = Subst()
            for (pvar, cvar) in goal.vmap
                if !(cvar in keys(goal.env)) continue end
                if pvar == goal.env[cvar] continue end
                vmap[pvar] = goal.env[cvar]
            end
            parent.env = compose!(parent.env, vmap)
            # Advance parent to next subgoal and put it back on the queue
            parent.active += 1
            push!(queue, parent)
            continue
        end
        # Examine current subgoal
        term = goal.children[goal.active]
        @debug string("Subgoal: ", term)
        # Handle built-in special terms
        if term.name in builtins || term.name in keys(funcs)
            success = handle_builtins!(queue, clauses, goal, term;
                                       vcount=vcount, options...)
            # If successful, go to next subgoal, otherwise skip to next goal
            if success
                @debug string("Done, returning to parent.")
                goal.active += 1
                push!(queue, goal)
            end
            continue
        end
        # Substitute and freshen variables in term
        vmap = Subst()
        term = freshen!(substitute(term, goal.env), vmap, vcount)
        # Iterate across clause set with matching heads
        matched_clauses = retrieve_clauses(clauses, term, funcs)
        matched = false
        for c in matched_clauses
            # Freshen variables in clause
            c = freshen!(c, Subst(), vcount)
            # If term unifies with head of a clause, add it as a subgoal
            unifier = unify(term, c.head, occurs_check, funcs)
            if isnothing(unifier) continue end
            child = GoalTree(c.head, goal, copy(c.body), 1, unifier, vmap)
            push!(queue, child)
            matched = true
        end
        if !matched @debug string("Failed, no matching clauses.") end
    end
    # Goals were satisfied if we found valid substitutions
    return (length(subst) > 0), subst
end

resolve(goal::Term, clauses::Vector{<:AbstractClause}; options...) =
    resolve(Term[goal], clauses; options...)

resolve(goals::Vector{Clause}, clauses::Vector{<:AbstractClause}; options...) =
    resolve([convert(Term, g) for g in goals], clauses; options...)

const bwd_chain = resolve

"Return all facts derivable in `n` steps from the initial set of clauses."
function derivations(clauses::Vector{<:AbstractClause}, n::Real=1; options...)
    rules = filter(c -> length(c.body) > 0, clauses)
    facts = filter(c -> length(c.body) == 0, clauses)
    return derivations(rules, facts, n; options...)
end

function derivations(rules::Vector{T}, facts::Vector{T}, n::Real=1;
                     options...) where {T <: AbstractClause}
    return derivations(rules, index_clauses(facts), n; options...)
end

function derivations(rules::Vector{T}, facts::ClauseTable{T}, n::Real=1;
                     as_indexed::Bool=false, options...) where {T <: AbstractClause}
    step = 0
    n_facts = num_clauses(facts)
    while step < n
        # Iteratively add facts derivable from each rule
        derived = derive_step(rules, facts; options...)
        insert_clauses!(facts, derived)
        # Terminate early if we reach a fixed point
        n_facts_new = num_clauses(facts)
        if (n_facts < n_facts_new) n_facts = n_facts_new else break end
        step += 1
    end
    return as_indexed ? facts : deindex_clauses(facts)
end

"Iteratively add facts derivable from each rule."
function derive_step(rules::Vector{T}, facts::ClauseTable{T};
                     options...) where {T <: AbstractClause}
    # Iteratively add facts derivable from each rule
    derived = Term[]
    for r in rules
        # Find all valid substitutions of each rule's body
        _, subst = resolve(r.body, facts; options...)
        append!(derived, Term[substitute(r.head, s) for s in subst])
    end
    return [Clause(d, []) for d in derived]
end

"""
    derive(goals, clauses; <keyword arguments>)
    fwd_chain(goals, clauses; <keyword arguments>)

Derive goals via forward-chaining from the initial set of clauses.

# Arguments
- `goals::Vector{<:Term}`: A list of Julog terms to be prove or query.
- `clauses::Vector{Clause}`: A list of Julog clauses.
- `max-steps::Real=100`: Maximum steps before terminating with failure.

See `resolve` for other supported arguments.
"""
function derive(goals::Vector{<:Term}, clauses::Vector{T};
                max_steps::Real=100, options...) where {T <: AbstractClause}
    grounded = all(is_ground.(goals))
    rules = filter(c -> length(c.body) > 0, clauses)
    facts = index_clauses(filter(c -> length(c.body) == 0, clauses))
    n_facts = num_clauses(facts)
    step = 0
    while step < max_steps
        # Return all goals are grounded and satisfied
        if grounded
            sat, subst = resolve(goals, facts; options...)
            if sat return sat, subst end
        end
        # Iteratively add facts derivable from each rule
        derived = derive_step(rules, facts; options...)
        insert_clauses!(facts, derived)
        # Terminate early if we reach a fixed point
        n_facts_new = num_clauses(facts)
        if (n_facts < n_facts_new) n_facts = n_facts_new else break end
        step += 1
    end
    return resolve(goals, facts; options...)
end

derive(goal::Term, clauses::Vector{<:AbstractClause}; options...) =
    derive(Term[goal], clauses; options...)

derive(goals::Vector{Clause}, clauses::Vector{<:AbstractClause}; options...) =
    derive([convert(Term, g) for g in goals], clauses; options...)

const fwd_chain = derive
