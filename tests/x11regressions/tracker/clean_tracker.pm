# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: First commit for tracker cases. Still need to modify main.pm to make it work.
# G-Maintainer: nick wang <nwang@suse.com>

use base "x11regressiontest";
use strict;
use testapi;

# Clean for testing tracker.

my @filenames = qw(newfile newpl.pl);

sub run() {
    my $self = shift;

    # Delete a file.
    foreach (@filenames) {
        x11_start_program("rm -rf $_");
        sleep 2;
    }
    wait_idle;
}

1;
# vim: set sw=4 et:
