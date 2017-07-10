module NestedArrays

import Base: @propagate_inbounds, @_inline_meta
import Base: IndexStyle, size, indices, getindex, setindex!, transpose, ctranspose
import Base.Broadcast: _containertype, promote_containertype, broadcast_c, _broadcast!

export NestedArray, NestedVector, NestedMatrix, nested

"""
    NestedArray(a)

Construct a `NestedArray` wrapping array `a`. The nested array applies broadcasting and
linear algebra operations in a nested sense. The elements of `a` are expected to behave
similarly to `AbstractArray`, but no type requirement is imposed.
"""
struct NestedArray{T, n, A <: AbstractArray{T, n}} <: AbstractArray{T, n}
    a::A
end

const NestedVector{T, A <: AbstractVector{T}} = NestedArray{T, 1, A}
const NestedMatrix{T, A <: AbstractVector{T}} = NestedArray{T, 2, A}
const NestedVecOrMat{T, A <: AbstractVecOrMat{T}} = Union{NestedVector{T, A}}

NestedArray(a::AbstractArray{T, n}) where {T, n} = NestedArray{T, n, typeof(a)}(a)
NestedArray{T}(a::AbstractArray{T, n}) where {T, n} = NestedArray{T, n, typeof(a)}(a)
NestedArray{T, n}(a::AbstractArray{T, n}) where {T, n} = NestedArray{T, n, typeof(a)}(a)
NestedVector(a::AbstractVector{T}) where {T} = NestedArray{T, 1, typeof(a)}(a)
NestedMatrix(a::AbstractMatrix{T}) where {T} = NestedArray{T, 2, typeof(a)}(a)

"""
    nested(a::AbstractArray)

Construct a `NestedArray` wrapping `a`, which allows for recursive broadcasting, transpose
and linear algebra.
"""
nested(a::AbstractArray) = NestedArray(a)

@inline size(a::NestedArray) = size(a.a)
@inline indices(a::NestedArray) = indices(a.a)
@inline IndexStyle(a::NestedArray) = IndexStyle(a.a)
@propagate_inbounds getindex(a::NestedArray, i...) = getindex(a.a, i...)
@propagate_inbounds setindex!(a::NestedArray, v, i...) = setindex!(a.a, v, i...)

# Transposition is recursive (same as Base, at the moment...)
# TODO - make (c)transpose(::AbstractMatrix) lazy
#      - make (c)transpose(::AbstractVecOrMat) non-recursive
#      - make (c)transpose(::NestedMatOrVec) recursive
transpose(a::NestedVecOrMat) = NestedArray(transpose(a.a))
ctranspose(a::NestedVecOrMat) = NestedArray(ctranspose(a.a))

# Broadcast results in a NestedArray and is recursive
_containertype(::Type{<:NestedArray}) = NestedArray
promote_containertype(::Type{NestedArray}, ::Type{Any}) = NestedArray
promote_containertype(::Type{Any}, ::Type{NestedArray}) = NestedArray
promote_containertype(::Type{NestedArray}, ::Type{Array}) = NestedArray
promote_containertype(::Type{Array}, ::Type{NestedArray}) = NestedArray
# TODO: tuples and sparse arrays

@inline function broadcast_c(f, ::Type{NestedArray}, a::NestedArray)
    NestedArray(broadcast(x -> (@_inline_meta; broadcast(f, x)), a.a))
end

@inline function broadcast_c(f, ::Type{NestedArray}, a1::NestedArray, a2::NestedArray)
    NestedArray(broadcast((x1, x2) -> (@_inline_meta; broadcast(f, x1, x2)), a1.a, a2.a))
end

# TODO broken for a1::Array?
@inline function broadcast_c(f, ::Type{NestedArray}, a1, a2::NestedArray)
    NestedArray(broadcast((x1, x2) -> (@_inline_meta; broadcast(y2 -> (@_inline_meta; f(x1, y2)), x2)), a1, a2.a))
end

# TODO broken for a2::Array?
@inline function broadcast_c(f, ::Type{NestedArray}, a1::NestedArray, a2)
    NestedArray(broadcast((x1, x2) -> (@_inline_meta; broadcast(y1 -> (@_inline_meta; f(y1, x2)), x1)), a1.a, a2))
end

# TODO finish making this generic
# TODO seperate `all(nest)` branch using dispatch instead?
@generated function broadcast_c(f, ::Type{NestedArray}, a...)
    nest = map(T -> T <: NestedArray, a.params)
    n = length(nest)
    if all(nest)
        expr_as = [:(a[$i]) for i = 1:n]
        expr_xs = [Symbol("x$i") for i = 1:n]
        return quote
            @_inline_meta
            NestedArray(broadcast(f, tuple($(expr_xs...)) -> broadcast(f, $(expr_xs...)), $(expr_as...)))
        end
    else
        error("Generic mixed nested/non-nested broadcasting is not implemented yet")
    end
end

# Same for broadcast!
# TODO: eliminating inner allocations
@inline function broadcast_c!(f, ::Type{NestedArray}, c, a::NestedArray)
    broadcast!(x -> (@_inline_meta; broadcast(f, x)), c, a.a)
    return c
end

@inline function broadcast_c!(f, ::Type{NestedArray}, c, a1::NestedArray, a2::NestedArray)
    NestedArray(broadcast!((x1, x2) -> (@_inline_meta; broadcast(f, x1, x2)), c, a1.a, a2.a))
    return c
end

# TODO broken for a1::Array?
@inline function broadcast_c!(f, ::Type{NestedArray}, c, a1, a2::NestedArray)
    NestedArray(broadcast!((x1, x2) -> (@_inline_meta; broadcast(y2 -> (@_inline_meta; f(x1, y2)), x2)), c, a1, a2.a))
    return c
end

# TODO broken for a2::Array?
@inline function broadcast_c!(f, ::Type{NestedArray}, c, a1::NestedArray, a2)
    NestedArray(broadcast!((x1, x2) -> (@_inline_meta; broadcast(y1 -> (@_inline_meta; f(y1, x2)), x1)), c, a1.a, a2))
    return c
end

# TODO finish making this generic
@generated function broadcast_c!(f, ::Type{NestedArray}, c, a...)
    nest = map(T -> T <: NestedArray, a.params)
    n = length(nest)
    if all(nest)
        expr_as = [:(a[$i].a) for i = 1:n]
        expr_xs = [Symbol("x$i") for i = 1:n]
        return quote
            @_inline_meta
            broadcast!(f, tuple($(expr_xs...)) -> broadcast(f, $(expr_xs...)), c, $(expr_as...))
            return c
        end
    else
        error("Generic mixed nested/non-nested broadcasting is not implemented yet")
    end
end

end # module
