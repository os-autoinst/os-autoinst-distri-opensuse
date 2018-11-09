use strict;
use warnings;
use testapi qw(check_var get_var get_required_var);
use needle;
use File::Basename;
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common;

init_main();

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

sub loadtests {
    my $filter = shift;
    return 1 unless $filter;

    if ($filter eq 'boot_from_dvd') {
        loadtest 'installation/bootloader_uefi' if (get_var("UEFI"));
        loadtest 'installation/bootloader' unless (get_var("UEFI"));
    }

    if ($filter eq 'boot_from_disk') {
        # Preparation for start testing
        loadtest 'kubic/disk_boot';
        loadtest 'kubic/networking';
        loadtest 'kubic/repositories';
    }

    if ($filter eq 'installation') {
        # Full list of installation test-modules can be found at 'main_common.pm'
        load_inst_tests;
    }

    if ($filter eq 'feature') {
        # Feature tests for Micro OS operating system
        loadtest 'caasp/create_autoyast' unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
        loadtest 'caasp/libzypp_config';
        loadtest 'caasp/one_line_checks';
        loadtest 'caasp/filesystem_ro';
        loadtest 'caasp/services_enabled';
        loadtest 'caasp/transactional_update';
        loadtest 'caasp/rebootmgr';
        loadtest 'caasp/journal_check';
    }

    if ($filter eq 'rcshell') {
        # Tests before the YaST installation
        loadtest 'caasp/rcshell_start';
        loadtest 'caasp/libzypp_config';
        loadtest 'caasp/one_line_checks';
    }
}

#######################
# Testing starts here #
#######################
if (get_var 'STACK_ROLE') {
    loadtests 'boot_from_disk';
    loadtests 'feature' if (check_var 'EXTRA', 'FEATURES');
    loadtest 'shutdown/shutdown';
}
else {
    loadtests 'boot_from_dvd';
    if (get_var 'SYSTEM_ROLE') {
        loadtests 'installation';
        loadtests 'boot_from_disk';
        loadtests 'feature' if (check_var 'EXTRA', 'FEATURES');
        loadtest 'shutdown/shutdown';
    }
    else {
        loadtests('rcshell') if (check_var 'EXTRA', 'RCSHELL');
    }
}

1;
