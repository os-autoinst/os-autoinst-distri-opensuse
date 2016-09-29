# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add case upgrade_glib2_pango32bit to fix bsc#978972
#    Migration from SLED11SP4 to SLED12SP2 is failed since libpango
#    dependency problem, the fix of this bug has been released to MU.
#    This script will update the package and create a new SLED11 image
#    for openQA's offline_migration test.
#
#    See also: bsc#978972
# G-Maintainer: Chingkai <qkzhu@suse.com>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self     = shift;
    my $repo_url = 'http://download.suse.de/ibs/SUSE:/SLE-11-SP1:/Update/standard/';

    x11_start_program("xterm");
    become_root;
    script_run "chmod 444 /usr/sbin/packagekitd";    # packagekitd will be not executable
    script_run "pkill -f packagekitd";
    script_run "zypper ar $repo_url repo";
    script_run "zypper -n in glib2 pango-32bit";
    script_run "zypper rr repo";
    script_run "chmod 755 /usr/sbin/packagekitd";    # restore the permission of packagekitd
    type_string "exit\n";
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
