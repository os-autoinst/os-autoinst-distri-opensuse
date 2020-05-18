# XEN regression tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test the host kernel
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'xen';
use warnings;
use strict;
use virt_autotest::kernel;
use testapi;
use utils;
use qam;

sub run {
    my $self = shift;

    script_run "zypper lr -d";
    script_run "rpm -qa > /tmp/rpm-qa.txt";
    upload_logs("/tmp/rpm-qa.txt");

    check_virt_kernel();
}

sub post_run_hook {
}

sub test_flags {
    return {fatal => 1};
}

1;

