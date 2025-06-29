(fn factorial [Int n] (
    (if (== n 0) (
        (ret 1)
    ))
    (ret (* n (factorial (- n 1))))
))