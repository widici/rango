// Calculates exponents where x is raised to the power of n
(fn pow [Int x n] (
    (if (== n 1) (
        (ret x)
    ))
    (ret (* x (pow x (- n 1))))
))