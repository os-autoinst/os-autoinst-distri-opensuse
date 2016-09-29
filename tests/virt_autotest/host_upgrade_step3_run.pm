# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# G-Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# G-Maintainer: alice <xlai@suse.com>

use base "host_upgrade_base";
use testapi;
use virt_utils;
use strict;

sub get_script_run() {
    my $self = shift;

    my $pre_test_cmd = $self->get_test_name_prefix;
    $pre_test_cmd .= "-run 03";

    return "$pre_test_cmd";
}

sub run() {
    my $self = shift;
    repl_repo_in_sourcefile();
    $self->run_test(5400, "Test run completed successfully", "no", "yes", "/var/log/qa/ctcs2/", "host-upgrade-postVerify-logs");
}

1;

