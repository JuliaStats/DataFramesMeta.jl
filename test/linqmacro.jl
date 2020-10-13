module TestLinqMacro

using Test
using DataFrames
using DataFramesMeta
using Statistics
using Random

df = DataFrame(a = repeat(1:5, outer = 20),
               b = repeat(["a", "b", "c", "d"], inner = 25),
               x = repeat(1:20, inner = 5))

x = @where(df, :a .> 2, :b .!= "c")
x = @transform(x, y = 10 * :x)
x = @by(x, :b, meanX = mean(:x), meanY = mean(:y))
x = @orderby(x, -:meanX)
x = @select(x, var = :b, :meanX, :meanY)

x1 = @linq transform(where(df, :a .> 2, :b .!= "c"), y = 10 * :x)
x1 = @linq by(x1, :b, meanX = mean(:x), meanY = mean(:y))
x1 = @linq select(orderby(x1, -:meanX), var = :b, :meanX, :meanY)

## chaining
xlinq = @linq df  |>
    where(:a .> 2, :b .!= "c")  |>
    transform(y = 10 * :x)  |>
    by(:b, meanX = mean(:x), meanY = mean(:y))  |>
    orderby(-:meanX)  |>
    select(var = :b, :meanX, :meanY)

@test x == x1
@test x == xlinq

xlinq2 = @linq df  |>
    where(:a .> 2, :b .!= "c")  |>
    transform(y = 10 * :x)  |>
    groupby(:b) |>
    orderby(-mean(:x))  |>
    groupby(:b) |>
    based_on(meanX = mean(:x), meanY = mean(:y))

xlinq2[!, [:meanX, :meanY]] == xlinq[!, [:meanX, :meanY]]

@test xlinq2[!, [:meanX, :meanY]] == xlinq[!, [:meanX, :meanY]]

xlinq3 = @linq df  |>
    where(:a .> 2, :b .!= "c")  |>
    transform(y = 10 * :x)  |>
    DataFrames.groupby(:b) |>
    orderby(-mean(:x))  |>
    groupby(:b) |>
    based_on(meanX = mean(:x), meanY = mean(:y))

@test xlinq3[!, [:meanX, :meanY]] == xlinq[!, [:meanX, :meanY]]

@test (@linq df |> with(:a)) == df.a

@testset "@linq with `cols`" begin
    df = DataFrame(
            a = [1, 2, 3, 4],
            b = ["a", "b", "c", "d"],
            x = [10, 20, 30, 40],
            y = [40, 50, 60, 70]
        )

    a_sym = :a
    b_str = "b"
    x_sym = :x
    y_str = "y"
    xlinq3 = @linq df  |>
        where(cols(a_sym) .> 2, :b .!= "c")  |>
        transform(cols(y_str) = 10 * cols(x_sym))  |>
        DataFrames.groupby(b_str) |>
        orderby(-mean(cols(x_sym)))  |>
        groupby(:b) |>
        based_on(cols("meanX") = mean(:x), meanY = mean(:y))

    @test isequal(xlinq3, DataFrame(b = "d", meanX = 40.0, meanY = 400.0))
end

end # module
