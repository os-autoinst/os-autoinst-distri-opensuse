# SUSE's openQA tests
#
# Copyright (C) 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "consoletest";
use testapi;

sub run() {
    my $repo_url = 'http://download.suse.de/ibs/SUSE:/SLE-11-SP1:/Update/standard/';
    select_console 'root-console';
    script_run "chmod 444 /usr/sbin/packagekitd";    # packagekitd will be not executable
    script_run "pkill -f packagekitd";
    script_run "zypper ar $repo_url repo";
    script_run "zypper -n in glib2 pango-32bit";
    script_run "zypper rr repo";
    script_run "chmod 755 /usr/sbin/packagekitd";    # restore the permission of packagekitd
}

1;
# vim: set sw=4 et:
