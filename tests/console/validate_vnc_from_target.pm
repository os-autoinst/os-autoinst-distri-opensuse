# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that, after remote installation, the xvnc.socket
# service is active and the firewall allows tigervnc service.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;

use testapi;
use utils "systemctl";

sub run {
    select_console "root-console";
    # Check if the xvnc.socket is enabled and active.
    # Workaround for bsc#1177485.
    my $xvnc_inactive = systemctl "is-active xvnc.socket", ignore_failure => 1;
    if ($xvnc_inactive) {
        record_soft_failure "bsc#1177485";
    }
    # Check if firewall allows tigervnc service
    my $firewall_services = script_output "firewall-cmd --list-services";
    die "The tigervnc service is not allowed by firewalld" unless ($firewall_services =~ /tigervnc/);
}

1;
