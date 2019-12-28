# Test list functionality with some basic list operations
clauses = @fol [
    member(X, [X | Y]) <<= true,
    member(X, [Y | YS]) <<= member(X, YS),
    append([], L, L) <<= true,
    append([X | XS], YS, [X | ZS]) <<= append(XS, YS, ZS),
    reverse(X, Y) <<= reverse(X, [], Y),
    reverse([], YS, YS) <<= true,
    reverse([X | XS], Accu, YS) <<= reverse(XS, [X | Accu], YS)
]

# Test list membership
@test resolve(@fol(member(banana, [avocado, banana, coconut])), clauses)[1] == true
@test resolve(@fol(member(durian, [avocado, banana, coconut])), clauses)[1] == false

# Test list appending
@test resolve(@fol(append([h,e,l,l], [o], [h,e,l,l,o])), clauses)[1] == true
@test resolve(@fol(append([o], [h,e,l,l], [h,e,l,l,o])), clauses)[1] == false

# Test list reversal
@test resolve(@fol(reverse([r,e,g,a,l], [l,a,g,e,r])), clauses)[1] == true
# A palindrome!
@test resolve(@fol(reverse([d,e,l,e,v,e,l,e,d], [d,e,l,e,v,e,l,e,d])), clauses)[1] == true
# Not a palindrome (but yes an ambigram)
@test resolve(@fol(reverse([p,a,s,s,e,d], [p,a,s,s,e,d])), clauses)[1] == false
