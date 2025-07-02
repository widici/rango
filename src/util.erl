%% TODO: consider switching to only using Gleam's Erlang FFI if feasible

-module(util).
-export([to_term/1]).

%% Converts a string into a term, used for the run subcommand
%% Throws an error if string cannot be parsed
-spec to_term(string()) -> term().
to_term(String) ->
    case erl_scan:string(String) of
        {ok, Tokens, _} ->
            case erl_parse:parse_term(Tokens) of
                {ok, Term} -> Term;
                {error, Reason} ->
                    erlang:error({parse_error, Reason, String})
            end;
        {error, Reason, _} ->
            erlang:error({scan_error, Reason, String})
    end.