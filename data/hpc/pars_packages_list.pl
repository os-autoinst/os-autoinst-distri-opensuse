#!/usr/bin/perl

use strict;
use warnings;

my @migration_targets;
#TODO: 15-SP2 should be a variable taken from the file name
my $rpm_list = '/tmp/package_list-15-SP2';
my $pattern = "rpm:";

open my $fd, '<', $rpm_list or die "Could not open '$rpm_list' $!\n";

while (my $line = <$fd>) {
    chomp $line;
    if ($line =~ $pattern) {
        push(@migration_targets, split('\,', $line));
    }
}

## return scalar for ease of handling
my $compactify;
foreach (@migration_targets) {
    $compactify = join('|', @migration_targets);
}

print("$compactify");
