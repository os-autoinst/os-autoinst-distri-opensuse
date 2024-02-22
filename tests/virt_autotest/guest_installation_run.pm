# SUSE's openQA tests
#
# Copyright 2012-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: guest_installation_run: This test is used to verify if different products can be installed successfully as guest on specify host.
# Maintainer: alice <xlai@suse.com>

use base "virt_autotest_base";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use Utils::Backends 'use_ssh_serial_console';
use ipmi_backend_utils;
use virt_utils;

sub get_script_run {
    my $pre_test_cmd = "";
    if (is_s390x) {
        #Use pipefail to keep the correct returns from test_virtualization-virt_install_withopt-run
        $pre_test_cmd = "set -o pipefail;";
        $pre_test_cmd .= "/usr/share/qa/tools/test_virtualization-virt_install_withopt-run";
    }
    else {
        my $prd_version = script_output("cat /etc/issue");
        if ($prd_version =~ m/SUSE Linux Enterprise Server 11/) {
            $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-standalone-run";
        }
        else {
            $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-virt_install_withopt-run";
        }
    }
    # testsuite setting pre-handling for no service pack products
    handle_sp_in_settings_with_fcs("GUEST_PATTERN");
    my $guest_pattern = get_var('GUEST_PATTERN', 'sles-12-sp2-64-[p|f]v-def-net');
    my $parallel_num = get_var("PARALLEL_NUM", "2");

    $pre_test_cmd = $pre_test_cmd . " -f " . $guest_pattern . " -n " . $parallel_num . " -r ";
    $pre_test_cmd .= " 2>&1 | tee /tmp/s390x_guest_install_test.log" if (is_s390x);

    return $pre_test_cmd;
}

sub analyzeResult {
    my ($self, $text) = @_;
    my $result;
    $text =~ /Test in progress(.*)Test run complete/s;
    my $rough_result = $1;
    foreach (split("\n", $rough_result)) {
        if ($_ =~ /(\S+)\s+\.{3}\s+\.{3}\s+(PASSED|FAILED|SKIPPED|TIMEOUT)\s+\((\S+)\)/g) {
            $result->{$1}{status} = $2;
            $result->{$1}{test_time} = $3;
        }
    }
    return $result;
}

sub post_execute_script_assertion {
    my $self = shift;
    my $output = $self->{script_output};

    $output =~ s/"|'|`//g;
    my $guest_installation_assert_pattern = "Test[[:space:]]in[[:space:]]progress.*(fail|timeout).*Test[[:space:]]run[[:space:]]complete";
    script_output("shopt -s nocasematch;[[ ! \"$output\" =~ $guest_installation_assert_pattern ]]", type_command => 0, proceed_on_failure => 0);
    save_screenshot;
}

sub run {
    my $self = shift;

    select_console 'sol', await_console => 0;
    use_ssh_serial_console;

    # Add option to keep guest after successful installation
    # Only for x86_64 now
    if (is_x86_64) {
        assert_script_run("sed -i 's/vm-install.sh/vm-install\.sh -g -k /' /usr/share/qa/qa_test_virtualization/installos");
        assert_script_run("sed -i 's/virt-install.sh/virt-install\.sh -u /' /usr/share/qa/qa_test_virtualization/virt_installos");
        assert_script_run('cat /usr/share/qa/qa_test_virtualization/installos | grep vm-install');
        save_screenshot;
        assert_script_run('cat /usr/share/qa/qa_test_virtualization/virt_installos | grep virt-install');
        save_screenshot;
    }

    $self->{"product_tested_on"} = "SLES-12-SP2";
    $self->{"product_name"} = "GuestIn_stallation";
    $self->{"package_name"} = "Guest Installation Test";
    $self->{success_guest_list} = [];

    my $upload_guest_assets_flag = 'no';
    # Only enable UPLOAD_GUEST_ASSETS for x86_64 now
    if (check_var('UPLOAD_GUEST_ASSETS', '1') && is_x86_64) {
        $upload_guest_assets_flag = 'yes';
    }

    $self->run_test(7600, "", "yes", "yes", "/var/log/qa/", "guest-installation-logs", $upload_guest_assets_flag);
    #upload testing logs for s390x guest installation test
    if (is_s390x) {
        #upload s390x_guest_install_test.log
        upload_asset("/tmp/s390x_guest_install_test.log", 1, 1);
        lpar_cmd("rm -r /tmp/s390x_guest_install_test.log");
    }
}

1;

