# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;
    select_console 'root-console';

    script_run("zypper lr -d | tee /dev/$serialdev");

    my $pattern   = get_var("DE_PATTERN");
    my $zypp_type = "pattern";
    if (check_var("DE_IS_PKG", 1)) {
        $zypp_type = "package";
    }
    assert_script_run("zypper -n in -t $zypp_type $pattern", 600);

    # Toggle the default window manager
    assert_script_run("sed -i 's/DEFAULT_WM=.*/DEFAULT_WM=\"${pattern}\"/' /etc/sysconfig/windowmanager");
}

1;
# vim: set sw=4 et:
