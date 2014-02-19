# DataFramesMeta.jl

Experiments with metaprogramming tools for DataFrames (and maybe other
Julia objects that hold variables). Goals are to improve performance
and provide more convenient syntax.

In earlier versions of DataFrames, expressions were used in indexing
and in `with` and `within` functions. This approach had several
deficiencies. Performance was poor. The functions relied on `eval`
which caused several issues, most notably that results were different
when used in the REPL than when used inside a function.

# Features

## `@with`

`@with` allows DataFrame columns to be referenced as symbols like
`:colX` in expressions. If an expression is wrapped in `^(expr)`,
`expr` gets passed through untouched. Here are some examples:

```julia
using DataArrays, DataFrames
using DataFramesMeta

df = DataFrame(x = 1:3, y = [2, 1, 2])
x = [2, 1, 0]

@with(df, :y + 1)
@with(df, :x + x)  # the two x's are different

x = @with df begin
    res = 0.0
    for i in 1:length(:x)
        res += :x[i] * :y[i]
    end
    res
end

@with(df, df[:x .> 1, ^(:y)]) # The ^ means leave the :y alone

```

This works for Associative types, too:

```julia
y = 3
d = {:s => 3, :y => 44, :d => 5}

@with(d, :s + :y + y)
```

`@with` is the fundamental macro used by the other metaprogramming
utilities.

## `@ix`

Select row and/or columns. This is an alternative to `getindex`.

```julia
@ix(df, :x .> 1)
@ix(df, :x .> x) # again, the x's are different
@ix(df, :A .> 1, [:B, :A])
```

## `@where`

Select row subsets.

```julia
@where(df, :x .> 1)
@where(df, :x .> x)
```

## `@select`

Column selections and transformations. Also works with Associative types.

```julia
@select(df, :x, :y, :z)
@select(df, x2 = 2 * :x, :y, :z)
```

## `@transform`

Add additional arguments based on keyword arguments. This is available
in both function and macro versions with the macro version allowing
direct reference to columns using the colon syntax:

```julia
transform(df, newCol = cos(df[:x]), anotherCol = df[:x]^2 + 3*df[:x] + 4)
@transform(df, newCol = cos(:x), anotherCol = :x^2 + 3*:x + 4)
```

`@transform` works for associative types, too.


## LINQ-Style Queries and Transforms

A number of functions for operations on DataFrames have been defined.
Here is a table of equivalents for Hadley's
[dplyr](https://github.com/hadley/dplyr) and common
[LINQ](http://en.wikipedia.org/wiki/Language_Integrated_Query)
functions.

    Julia             dplyr            LINQ
    ---------------------------------------------
    @where            filter           Where
    @transform        mutate           Select (?)
    @by                                GroupBy
    @groupby          group_by
    @based_on         summarise/do
    @orderby          arrange          OrderBy
    @select           select           Select


Chaining operations is a useful way to manipulate data. There are
several ways to do this. This is still in flux in base Julia
(https://github.com/JuliaLang/julia/issues/5571). Here is one option
from [Lazy.jl](https://github.com/one-more-minute/Lazy.jl) by Mike
Innes:

```julia
x_thread = @> begin
    df
    @transform(y = 10 * :x)
    @where(:a .> 2)
    @by(:b, meanX = mean(:x), meanY = mean(:y))
    @orderby(:meanX)
    @select(:meanX, :meanY, var = :b)
end
```

# Performance

`@with` works by parsing the expression body for all columns indicated
by symbols (e.g. `:colA`). Then, a function is created that wraps the
body and passes the columns as function arguments. This function is
then called. Operations are efficient because:

- A pseudo-anonymous function is defined, so types are stable.
- Columns are passed as references, eliminating DataFrame indexing.

All of the other macros are based on `@with`.


# Discussions

Everything here is experimental.

Right now, here's my judgement on the advantages of this approach

- The approach is quite expressive and flexible.
- Use of macros improves run-time efficiency.
- The API is relatively consistent.
- I have not run into any show-stoppers like we had with
  expression-based indexing.
- The code is relatively concise.

The main disadvantages are:

- The syntax is a little noisy with all of the `@something` macro
  calls. {This is my main gripe.}
- As with most macros, there's a certain amount of magic going on.

Right now, `@with` works for both AbstractDataFrames and Associative
types. `@ix` really only works for AbstractDataFrames. Because
macros are not type specific, it would be nice to make these
metaprogramming tools as general as possible.

Instead of `:colA` to refer to a member of the type, another option is
to use `*colA` or `^colA` or something else that isn't defined in
Julia (but can be parsed). Then, it'd be easier to mix use of symbols
with column references. `:colA` is most consistent in that it has (I
think) the tightest precedence, so you don't have to worry about using
parentheses. 

From the user's point of view, it'd be nice to swap the
"dereferencing", so in `@with(df, colA + :outsideVariable)`, `colA` is
a column, and `:outsideVariable` is an external variable. That is
quite difficult to do, though. You have to parse the expression tree
and replace all quoted variables with the "right thing". Here's an
example showing some of the difficulties:

```julia
@with df begin
    y = 1 + x + :z  # z is supposed to be an outside variable; x is a column
    fun(x) = x + 1  # don't want to substitute this x
    fun(y + x)      # don't want to substitute this y
end
```

For performance, we should check to see if this can play nicely with
`@devectorize` for use on columns.

