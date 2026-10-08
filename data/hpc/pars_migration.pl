#!/usr/bin/perl

use strict;
use warnings;

my @migration_targets;
my $targets = '/tmp/migration_targets';
my $pattern = "SUSE Linux Enterprise";

open my $fd, '<', $targets or die "Could not open '$targets' $!\n";

while (my $line = <$fd>) {
    chomp $line;
    if ($line =~ $pattern) {
        push(@migration_targets, split('\|', $line));
    }
}

## return scalar for ease of handling
my $compactify;
my $i = 0;
foreach (@migration_targets) {
    if ($i == 0) {
        $compactify = "$_";
    } else {
        $compactify .= "|$_";
    }
    $i++;
}

print("$compactify");
