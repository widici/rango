(use "erlang" "+" 2)
(use "erlang" "-" 2)
(use "erlang" "*" 2)

(use "erlang" "=:=" 2)
(use "erlang" "=/=" 2)
(use "erlang" "<" 2)
(use "erlang" ">=" 2)

(use "erlang" "and" 2)
(use "erlang" "or" 2)

(use "lists" "flatten" 1)

(use "io" "format" 2)

(fn putsln [Str str] (
    (ret (format "~s~n" (list str)))
)) 

(fn puts [Str str] (
    (ret (format "~s" (list str)))
))

(use "erlang" "integer_to_list" 1)

(fn str [Int int] (
    (ret (integer_to_list int))
))