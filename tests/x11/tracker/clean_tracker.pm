# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cleanup before testing tracker
# - remove two files (newfile and newpl.pl)
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>

use base "x11test";
use testapi;

my @filenames = qw(newfile newpl.pl);

sub run {
    # Delete a file.
    foreach (@filenames) {
        x11_start_program("rm -rf $_", target_match => 'generic-desktop');
    }
}

1;
