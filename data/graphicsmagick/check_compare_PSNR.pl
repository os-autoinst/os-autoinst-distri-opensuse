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
# Usage: perl check_compare_PSNR <tolerance> [<inverted:0/1>]

my $line = <STDIN>;
my ($tolerance) = @ARGV;

my $value = 0;
my $inf   = 100000;

if ($line =~ m/\s*\w+:\s*inf\s*/) {
    $value = $inf;
}
else {
    ($value) = ($line =~ m/\s*\w+:\s*(\d+.\d*).*/);
}

$tolerance = $inf if (not defined $tolerance or $tolerance eq "inf");

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

if ($value >= $tolerance) {
    print_status(1);
} else {
    print_status(0);
}
