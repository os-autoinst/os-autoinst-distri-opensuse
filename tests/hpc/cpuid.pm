# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: Add test for cpuid
#    https://fate.suse.com/319512
#
#    At the moment this test is in a pretty undefined state, since it's not clarified yet,
#    what needs to be tested exactly
#
#    For now, it only shows the output of 'cpuid' and prints it to the serialdev
# Maintainer: soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    script_run "cpuid | tee /dev/$serialdev";
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
