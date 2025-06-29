(fn power [Int x n] (
    (if (== n 1) (
        (ret x)
    ))
    (ret (* x (power x (- n 1))))
))