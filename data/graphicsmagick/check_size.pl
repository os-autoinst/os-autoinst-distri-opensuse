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
# Usage; perl check_size.pl image width height

my ($img, $w, $h) = @ARGV;

sub get_size {
    my $file = shift;
    $out = `gm identify $file`;
    return ($w, $h) = ($out =~ m/[\w|\.]+\s+\w+\s+(\d+)x(\d+).*/);
}

sub check_size {
    my $file = shift;
    my $w    = shift;
    my $h    = shift;

    my ($iw, $ih) = get_size($file);
    return $w == $iw && $h == $ih;
}

if (check_size($img, $w, $h)) {
    print("OK");
    exit(0);
} else {
    print("KO");
    exit(1);
}
