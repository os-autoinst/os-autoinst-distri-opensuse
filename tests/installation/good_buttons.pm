#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # support test for help and release note button
	# just did the check after the welcome test
	# 120 secs sounds long here but live installer is
	# slowly to show the page next the welcome page
    assert_screen "good-buttons", 120;
}

1;
# vim: set sw=4 et:
