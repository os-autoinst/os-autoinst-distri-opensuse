# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: GraphicMagick testsuite
# Maintainer: Ivan Lausuch <ilausuch@suse.com>
#
# Usage: perl check_compare.pl <tolerance> [<inverted:0/1>]

my $line = <STDIN>;
my ($tolerance, $inverted) = @ARGV;

my ($value) = ($line =~ m/\s*\w+:\s*(\d+.\d*).*/);

$tolerance //= 0;
$inverted  //= 0;

sub print_status {
    $value = shift;
    if ($value == 1) {
        print "OK";
        exit(0);
    }
    else {
        print "KO";
        exit(1);
    }
}

if ($value <= $tolerance) {
    $result = (1 + $inverted) % 2;
} else {
    $result = $inverted % 2;
}

print_status($result);
