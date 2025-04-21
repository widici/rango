(fn greet [Str name] (
    (putsln (<> "Hello " name "! :D"))
))

(fn fibonacci [Int a b n] (
    (var res (+ a b))
    (if (== n 0) (
        (ret Ok)
    ))
    (putsln (str res))
    (ret (fibonacci b res (- n 1)))
))

(fn factorial [Int n] (
    (if (== n 0) (
        (ret 1)
    ))
    (ret (* n (factorial (- n 1))))
))