// A factorial of n function implementation
(fn fact [Int n] (
    (if (== n 0) (
        (ret 1)
    ))
    (ret (* n (fact (- n 1))))
))