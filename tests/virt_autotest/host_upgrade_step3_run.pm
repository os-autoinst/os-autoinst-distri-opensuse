# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: host_upgrade_step3_run : Get the second stage script name for host upgrade test.
#          This test verifies virtualization host upgrade test result.
# Maintainer: alice <xlai@suse.com>

use base "host_upgrade_base";
use testapi;
use utils "zypper_call";
use virt_utils;
use strict;
use warnings;

sub get_script_run {
    my $self = shift;

    my $pre_test_cmd = $self->get_test_name_prefix;
    $pre_test_cmd .= "-run 03";

    return "$pre_test_cmd";
}

sub run {
    my $self = shift;

    #Install qa test repo
    my $installed_product = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));
    my $upgrade_product   = get_required_var('UPGRADE_PRODUCT');
    my ($upgrade_release) = lc($upgrade_product) =~ /sles-([0-9]+-sp[0-9]+)/;
    if (check_var('ARCH', 'x86_64') && $installed_product =~ /12-sp5/img && $upgrade_product =~ /15-sp2/img) {
        my $qa_test_repo = 'http://dist.nue.suse.com/ibs/QA:/Head/SLE-' . uc($upgrade_release);
        script_run("zypper rm -n -y qa_lib_virtauto", 300);
        zypper_call("rr server-repo qa-test-repo");
        zypper_call("--no-gpg-checks ar -f '$qa_test_repo' qa-test-repo");
        zypper_call("--gpg-auto-import-keys ref", 300);
        zypper_call("in qa_lib_virtauto",         300);
    }
    update_guest_configurations_with_daily_build();
    $self->run_test(5400, "Host upgrade virtualization test pass", "no", "yes", "/var/log/qa/", "host-upgrade-postVerify-logs");
}

1;

