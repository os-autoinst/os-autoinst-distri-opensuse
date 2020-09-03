# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Upgrade all guests to their latest state
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use warnings;
use strict;
use testapi;
use qam 'ssh_add_test_repositories';
use utils;
use virt_autotest::common;

sub run {
    my ($self) = @_;

    assert_script_run "ssh root\@$_ rm /etc/zypp/repos.d/SUSE_Maintenance* || true" foreach (keys %virt_autotest::common::guests);
    assert_script_run "ssh root\@$_ rm /etc/zypp/repos.d/TEST* || true"             foreach (keys %virt_autotest::common::guests);
    assert_script_run "ssh root\@$_ rm /tmp/dup* || true"                           foreach (keys %virt_autotest::common::guests);
    assert_script_run "ssh root\@$_ zypper ref"                                     foreach (keys %virt_autotest::common::guests);
    record_info "DUP", "Upgrading the system to it's latest version";
    script_run "( ssh root\@$_ '( zypper -n dup > /tmp/dup.log; echo \$? > /tmp/dup )' & )" foreach (keys %virt_autotest::common::guests);
    record_info "WAIT", "Waiting for all systems to be upgraded";
    script_retry("ssh root\@$_ cat /tmp/dup", delay => 60, retry => 180) foreach (keys %virt_autotest::common::guests);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

