# NestedArrays

A Julia array wrapper for nested broadcasting and linear algebra

[![Build Status](https://travis-ci.org/andyferris/NestedArrays.jl.svg?branch=master)](https://travis-ci.org/andyferris/NestedArrays.jl)

[![Coverage Status](https://coveralls.io/repos/andyferris/NestedArrays.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/andyferris/NestedArrays.jl?branch=master)

[![codecov.io](http://codecov.io/github/andyferris/NestedArrays.jl/coverage.svg?branch=master)](http://codecov.io/github/andyferris/NestedArrays.jl?branch=master)

## Introduction

This package is a prototype for playing around with richer support for nested arrays in Julia. For me, this is motivated by two desires:

 * Working with arrays of arrays can sometimes be frustrating, in that it is difficult to control the behavior of `broadcast` and other functions. Helper wrappers like `NestedArray` and `StaticArrays.Scalar` can help to control which elements of which arrays are broadcasted together.
 * There is a (natural) tension built into Julia's `Base` library between the assumption that the elements of `AbstractArray{T}` are a scalar, and wanting the flexibility to do a "sensible default" thing when `T` is an array. 
 
The second point can be analyzed in light of the differences between Julia and other languages (like MATLAB), the recent introduction of `RowVector`, and some thoughts on (mathematical) type theory. Julia makes a distinction between a scalar, and a vector (or other array). Thinking throught the consequences of this and trying to arrive at a consistent solution to this lead to the introduction of `RowVector`, our first attempt at modelling the dual of a `Vector` which takes the inner-product (returning a scalar) for `RowVector * Vector` or `v1' * v2`. (I highly recommend viewing Jiahao's JuliaCon 2017 talk discussing this clearly and in detail). It's my opinion that similar lines of thinking (about type theory) may lead to a simplification of many of the semantics applied in `Base.LinAlg`, particularly regarding the role of scalars as the elements of `AbstractVector` and `AbstractMatrix`.

Mathematical type theory was introduced before programming languages in an attempt to address questions about the foundations of mathematics. It was realized that while set theory seemed well founded, statements about "sets of sets" could quickly become contradictory and obtuse. Type theory would fix this by distinguishing scalars, first-order sets of scalars, second-order sets of sets of scalars, and so-on. 

In analogy, linear algebra is typically introduces by the concept of what I'd call "first order" vector's of scalars. Given a scalar field `T` that supports `+`, `*`, `conj` (and related functions), we can make a `Vector{T}` which supports **linear** `+(::Vector{T}, ::Vector{T})`, `*(::T, ::Vector{T})` and `conj(::Vector{T})`. From here we can discuss linear operators (`Matrix{T}`), dual spaces, inner-products and outer-products – generally these can be constructed by an additional operator, as one example consider `ctranspose(::Vector{T}) -> RowVector{T}` and `*(::Vector, ::RowVector) -> Matrix` combined with `+`, `*` and `conj` on `RowVector` and `Matrix`.

From here, it can be just as tempting to discuss "vectors of vectors of scalars" or "matrices or matrices of scalars" as it is to discuss "sets of sets of scalars". In general mathematical discussion, we can deal with vectors/matrices of all orders without major problems or contradictions, as mathematicians are well aware of how a second-order matrix of matrices of scalars behaves (for instance, the eigenvalues of a block matrix are still from the underlying scalars). Generally, block vectors and matrices use "recursive" `ctranspose`, as is the default in Julia. To acheive this, Julia has amongst other things defined the `transpose` operator on scalars (`Number`) to be a no-op (as opposed to an error, which might be reasonable since scalar fields can exist without knowing anything about linear algebra).

I would argue that semantics would be simpler, more consistent and easier to reason with if we used Julia's rich type system to distinguish first-order arrays of scalars from higher order "nested arrays". This package explores just one of many design possibilities here. The advantage of asserting that `AbstractArray` deals with scalar field is simplicity and consistency. If we can *assume* that the elements of an array are scalar (unless told otherwise), methods and interfaces simplify. If a scalar type supports `+`, `*` and `conj` (possibly a no-op), then this type should be able to be transposed in a vector (the dual taken from a default inner-product) and multiplied by a matrix. At the moment we emit errors for `transpose(::Vector{String})` because we assume more things about `String` then strictly necessary to get the work of arrays (and linear algebra) done. Here, a single type, `NestedArray`, lets you build second-order arrays-of-arrays-of-scalars as `NestedArray{Array{T}}` and third-order `NestedArray{NestedArray{Array{T}}}`, and so-on.

If this prototype works out well, I may propose that we adopt (at least some) of this behavior in `Base`. At this stage this would involve (a) increasing the assumption in `Base` and `Base.LinAlg` in particular that `AbstractArray` elements are scalar and (b) promote the usage of `NestedArray` for cases where you want to deal with arrays-of-arrays (including for linear algebra). In this scenario, `NestedArrays` could either live inside of `Base` or outside of `Base` as a recommended package. (We could also go the other direction, and bring some of the behavior introduced here to `AbstractArray`, or simply leave this as a package).

Please note that the code is work-in-progress and not ready for general use. Feel free to play around!

## Unanswered questions

 * How far should the "nesting" be taken? Should iteration, `map`, `reduce`, `filter`, etc work on the elements of the elements? Similarly should `size`, `indices`, `getindex` and `setindex!` be extended/flattened?
 * Are there other common broadcasting behaviors that aren't covered by `NestedArray` and `StaticArrays.Scalar`?