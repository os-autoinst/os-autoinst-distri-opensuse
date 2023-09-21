# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use base "host_upgrade_base";
#use virt_utils qw(set_serialdev);
use strict;
use warnings;
use testapi;
use virt_utils;

sub get_script_run {
    my $pre_test_cmd;

    handle_sp_in_settings_with_sp0("UPGRADE_PRODUCT");
    handle_sp_in_settings_with_sp0("GUEST_LIST");
    handle_sp_in_settings_with_sp0("BASE_PRODUCT");

    my $mode = get_var("TEST_MODE", "");
    my $hypervisor = get_var("HOST_HYPERVISOR", "");
    my $base = get_var("BASE_PRODUCT", "");    #EXAMPLE, sles-11-sp3
    my $upgrade = get_var("UPGRADE_PRODUCT", "");    #EXAMPLE, sles-12-sp2
    my $upgrade_repo = get_var("UPGRADE_REPO", "");
    #Prefer to use offline media for upgrade to avoid registration via autoyast
    $upgrade_repo =~ s/-Online-/-Full-/ if ($upgrade_repo =~ /15-sp[2-9]/i);
    my $guest_list = get_var("GUEST_LIST", "");
    my $do_registration = (check_var('SCC_REGISTER', 'installation') || check_var('REGISTER', 'installation') || get_var('AUTOYAST', '')) ? "true" : "false";
    my $registration_server = get_var('SCC_URL', 'https://scc.suse.com');
    my $registration_code = get_var('SCC_REGCODE', 'INVALID_REGCODE');

    $pre_test_cmd = "/usr/share/qa/tools/_generate_vh-update_tests.sh";
    $pre_test_cmd .= " -m $mode";
    $pre_test_cmd .= " -v $hypervisor";
    $pre_test_cmd .= " -b $base";
    $pre_test_cmd .= " -u $upgrade";
    $pre_test_cmd .= " -r $upgrade_repo";
    $pre_test_cmd .= " -i $guest_list";
    $pre_test_cmd .= " -e $do_registration";
    $pre_test_cmd .= " -s $registration_server";
    $pre_test_cmd .= " -c $registration_code";

    return "$pre_test_cmd";
}

sub run {
    my $self = shift;
    $self->run_test(180, "Generated test run file");
}

1;

