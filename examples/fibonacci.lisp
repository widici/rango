(fn fibonacci [Int a b n] (
    (var res (+ a b))
    (if (== n 0) (
        (ret Ok)
    ))
    (putsln (str res))
    (ret (fibonacci b res (- n 1)))
))