// Fibonacci sequence with a & b as start going up to index n
(fn fib [Int a b n] (
    (var res (+ a b))
    (if (== n 0) (
        (ret Ok)
    ))
    (putsln (str res))
    (ret (fib b res (- n 1)))
))