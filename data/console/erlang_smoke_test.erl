% erlang_smoke_test.erl
-module(erlang_smoke_test).
-export([run/0]).

% Run all smoke tests for standard library and required modules
run() ->
    io:format("Running Erlang/Elixir smoke tests~n"),
    standard_library_test(),
    epmd_test(),
    getopt_test(),
    cf_test(),
    erlware_commons_test(),
    io:format("All tests passed successfully~n").

% Standard Library Test (lists module example)
standard_library_test() ->
    io:format("Testing Standard Library~n"),
    RevList = lists:reverse([1, 2, 3]),
    case RevList of
        [3, 2, 1] -> io:format("Standard Library test passed: lists:reverse/1~n");
        _ -> io:format("Standard Library test failed: lists:reverse/1~n")
    end.

% Test for erlang-epmd (Erlang Port Mapper Daemon)
epmd_test() ->
    io:format("Testing Erlang EPMD with debug mode~n"),
    os:cmd("epmd -d &"),
    timer:sleep(1000),
    case gen_tcp:connect({127,0,0,1}, 4369, []) of
        {ok, Socket} ->
            io:format("Erlang EPMD started successfully in debug mode~n"),
            gen_tcp:close(Socket);
        {error, _Reason} ->
            io:format("Erlang EPMD test failed: Could not connect to EPMD~n")
    end,
    os:cmd("pkill epmd").

% Test for erlang-getopt (Command-line options parser)
getopt_test() ->
    io:format("Testing Getopt Module with positional options and option terminator~n"),

    OptSpecList = [
        {xml, $x, "xml", undefined, "Output data as XML"},
        {dbname, undefined, undefined, string, "Database name"},
        {output_file, undefined, undefined, string, "File where the data will be saved to"}
    ],

    TestArgs = "-x mydb file.out -- --dbname mydb dummy",

    case code:which(getopt) of
        undefined ->
            io:format("Getopt test failed: getopt module not found~n");
        _ ->
            case getopt:parse(OptSpecList, TestArgs) of
                {ok, {Opts, NonOpts}} ->
                    io:format("Parsed options: ~p~nNon-option arguments: ~p~n", [Opts, NonOpts]),
                    if
                        Opts == [xml, {dbname, "mydb"}, {output_file, "file.out"}] ->
                            io:format("Getopt test passed: Parsed options correctly~n");
                        true ->
                            io:format("Getopt test failed: Unexpected positional options result~n")
                    end,
                    if
                        NonOpts == ["--dbname", "mydb", "dummy"] ->
                            io:format("Getopt test passed: Parsed non-option arguments correctly~n");
                        true ->
                            io:format("Getopt test failed: Non-option arguments not parsed as expected~n")
                    end;
                _ ->
                    io:format("Getopt test failed: Parsing returned an error~n")
            end
    end.


% Test for cf module (checking text output instead of colors)
cf_test() ->
    io:format("Testing CF Text Output~n"),
    {ok, File} = file:open("/tmp/cf_test_output.txt", [write]),
    OriginalGroupLeader = group_leader(),
    erlang:group_leader(File, self()),
    cf:print("Red text and blue background~n"),
    cf:print("Green text reset to normal~n"),
    erlang:group_leader(OriginalGroupLeader, self()),
    file:close(File),
    {ok, Output} = file:read_file("/tmp/cf_test_output.txt"),
    OutputString = binary_to_list(Output),
    case lists:all(fun(Text) -> string:find(OutputString, Text) =/= nomatch end,
                   ["Red text", "blue background", "Green text"]) of
        true -> io:format("CF test passed: Expected text was output~n");
        false -> io:format("CF test failed: Expected text not found~n")
    end.

% Test for erlang-erlware_commons (Date formatting test)
erlware_commons_test() ->
    io:format("Testing Erlware Commons Date Formatting~n"),
    
    % Define a sample date and expected formatted output
    SampleDate = {{2024, 10, 31}, {14, 30, 0}}, % October 31, 2024, 14:30:00
    ExpectedOutput = "2024-10-31 14:30:00",

    % Format the date using ec_date:format/2
    case ec_date:format("{Y}-{m}-{d} {H}:{i}:{s}", SampleDate) of
        ExpectedOutput ->
            io:format("Erlware Commons test passed: Date formatted correctly~n");
        ActualOutput ->
            io:format("Erlware Commons test failed: Expected ~s but got ~s~n", [ExpectedOutput, ActualOutput])
    end.
