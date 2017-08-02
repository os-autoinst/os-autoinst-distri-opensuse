# SUSE's openQA tests
#
# Copyright ©2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure primary disk is selected for partitioning, e.g. for multi-drive setups
# Maintainer: Joachim Rauch <jrauch@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run {
    save_screenshot;
    send_key "$cmd{createpartsetup}";    #create partition setup
    save_screenshot;
    send_key 'alt-1';                    #use disk 1
    save_screenshot;
    wait_screen_change { send_key "$cmd{next}"; };
    send_key "$cmd{entiredisk}";         #use entire disk
    save_screenshot;
    wait_screen_change { send_key "$cmd{next}"; };
    save_screenshot;
}

1;
# vim: set sw=4 et:
