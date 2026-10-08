#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::More;
use FindBin '$Bin';

my $dbfile = "$Bin/movies.db";
my $sqlite_select = "sqlite3 --list --header $dbfile";

-e $dbfile and unlink $dbfile;

my $sqlite_version = qx{sqlite3 --version};
note "sqlite3 version: $sqlite_version";

subtest create_tables => sub {

    call_sqlite_file("$Bin/init-tables.sql", "create tables");

    my @output = sqlite_select("SELECT * FROM movie ORDER BY mid;");

    my @expected = (
        "mid|name|year",
        "1|The Dead Dont Die|2019",
        "2|Night on Earth|1991",
        "3|Only Lovers Left Alive|2013",
        "4|Ed Wood|1994",
        "5|Sleepy Hollow|1999",
        "6|Edward Scissorhands|1990",
        "7|The Matrix|1999",
        "8|Amores Perros|2000",
    );
    is_deeply(\@output, \@expected, "select from movies");
};

subtest test_alter_tables => sub {
    call_sqlite_file("$Bin/alter-tables.sql", "alter tables");

    my @output = sqlite_select(".schema");
    note "Updated schema:";
    note $_ for @output;

    @output = sqlite_select("SELECT * FROM movie ORDER BY mid LIMIT 1;");
    my @expected = (
        "mid|name|year|mtime",
        "1|The Dead Dont Die|2019|",
    );
    is_deeply(\@output, \@expected, "select from movie");

};

subtest test_view => sub {
    my @output = sqlite_select("SELECT * FROM cinema ORDER BY year, name LIMIT 6;");

    my @expected = (
        "name|year|directors",
        "Edward Scissorhands|1990|Tim Burton",
        "Night on Earth|1991|Jim Jarmusch",
        "Ed Wood|1994|Tim Burton",
        "Sleepy Hollow|1999|Tim Burton",
        "The Matrix|1999|Lana Wachowski+Lilly Wachowski",
        "Amores Perros|2000|Alejandro González Iñárritu",
    );
    is_deeply(\@output, \@expected, "select from cinema (view)");
};

subtest test_trigger => sub {
    my $cmd = sprintf q{echo "%s;" | sqlite3 %s},
      q{UPDATE movie SET name='The Dead Don''t Die' WHERE mid=1},
      $dbfile;
    note "Command: '$cmd'";
    my @output = qx{$cmd};
    $? == 0 ? pass "update" : fail "update";

    @output = sqlite_select(
        "SELECT * FROM movie WHERE mtime >= datetime('NOW', '-1 minute');"
    );
    if (@output == 2) {
        pass "one updated row";
    }
    else {
        fail "one updated row";
    }
};

subtest test_unique => sub {
    my $cmd = sprintf q{echo '%s;' | sqlite3 %s 2>&1},
      q{INSERT INTO director_movie (did, mid) VALUES (1,1)},
      $dbfile;
    note "Command: '$cmd'";
    my $output = qx{$cmd};
    if ($? != 0) {
        pass "forbidden duplicate row";
    }
    else {
        fail "forbidden duplicate row";
    }
    like($output, qr{UNIQUE}, "Error message like expected")
      or diag "Output was: >>$output<<";

};

subtest test_foreign_key => sub {
    my $cmd = sprintf q{echo '%s;' | sqlite3 --cmd "%s" %s 2>&1},
      q{INSERT INTO director_movie (did, mid) VALUES (99,99)},
      "PRAGMA foreign_keys = ON",
      $dbfile;
    note "Command: '$cmd'";
    my $output = qx{$cmd};
    if ($? != 0) {
        pass "foreign key";
    }
    else {
        fail "foreign key";
    }
    like($output, qr{FOREIGN KEY}, "Error message like expected")
      or diag "Output was: >>$output<<";

};

subtest test_rollback => sub {
    my @output = call_sqlite_file("$Bin/rollback.sql", "savepoint & rollback");

    my @expected = (
        "mid|name|year|mtime",
        "9|The Matrix Reloaded|2003|",
    );
    is_deeply(\@output, \@expected, "output savepoint & rollback ok");
};

done_testing;

# Helpers

sub sqlite_select {
    my ($select) = @_;

    my $cmd = qq{echo "$select" | $sqlite_select };
    note "Command: '$cmd'";
    chomp(my @output = qx{$cmd});
    return @output;
}

sub call_sqlite_file {
    my ($file, $label) = @_;

    my $cmd = qq{$sqlite_select < $file};
    note "Command: '$cmd'";

    my @output = qx{$sqlite_select < $file};
    if ($? != 0) {
        fail $label;
        diag @output;
        # BAIL_OUT isn't helpful, apparently the TAP output then only shows
        # this error but none of the previous results
        # BAIL_OUT("Command '$sqlite_select' exited with error, aborting");
    }
    else {
        pass $label;
    }
    chomp @output;
    return @output;
}

