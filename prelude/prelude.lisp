(use "erlang" "+" 2)
(use "erlang" "-" 2)
(use "erlang" "*" 2)

(use "io" "format" 2)

(fn putsln [Str str] Str (
    (ret (format "~s~n" (list str)))
)) 

(fn puts [Str str] Str (
    (ret (format "~s" (list str)))
))