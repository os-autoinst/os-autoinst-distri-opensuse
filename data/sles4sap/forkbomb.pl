#!/usr/bin/perl
#
# Maintainer: Ricardo Branco <rbranco@suse.de>
#
# Creates an (un)specified number of child processes,
# kills them all and patiently waits for them to die.
#
# Returns the number of child processes created.
#
# Useful to know how many processes we can create

use POSIX qw(pause);
use strict;
use warnings;

sub fork_bomb {
    my $max  = shift;
    my $pids = 0;

    $SIG{TERM} = "DEFAULT";
    # If explicitly ignored, wait() will wait for them all to die
    $SIG{CHLD} = "IGNORE";
    # Create our own process group so we can kill them all at once
    setpgrp 0, 0;

    for (my $i = 0; $i < $max || $max < 0; $i++) {
        my $pid = fork;
        last if !defined($pid);
        if (!$pid) {
            pause;
            exit;
        }
        $pids++;
    }

    # Kill them all without accidentally killing ourselves...
    $SIG{TERM} = "IGNORE";
    kill "TERM", -getpgrp(0);
    wait;

    return $pids;
}

if ($ARGV[1]) {
    print STDERR "Usage: $0 PROCESSES\n";
    exit 1;
}

my $n = fork_bomb(defined($ARGV[0]) ? $ARGV[0] : -1);
print "$n\n";
