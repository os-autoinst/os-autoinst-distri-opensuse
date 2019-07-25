# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Cleanup before testing tracker
# - remove two files (newfile and newpl.pl)
# Maintainer: Chingkai <qkzhu@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

my @filenames = qw(newfile newpl.pl);

sub run {
    # Delete a file.
    foreach (@filenames) {
        x11_start_program("rm -rf $_", target_match => 'generic-desktop');
    }
}

1;
