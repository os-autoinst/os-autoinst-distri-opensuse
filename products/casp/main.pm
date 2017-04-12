use strict;
use warnings;
use testapi qw(check_var get_var set_var);
use needle;
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common;

init_main();

# Reuse SP2 needles for YaST installer
sub cleanup_needles {
    remove_common_needles;
    unregister_needle_tags('ENV-INSTLANG-de_DE');
    unregister_needle_tags('ENV-VERSION-12');
    unregister_needle_tags('ENV-VERSION-12-SP1');
    unregister_needle_tags('ENV-SP2ORLATER-0');

    unregister_needle_tags('ENV-FLAVOR-Desktop-DVD');
    unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    unregister_needle_tags('ENV-ARCH-s390x');
    unregister_needle_tags('ENV-OFW-0');
    unregister_needle_tags('ENV-OFW-1');
}
$needle::cleanuphandler = \&cleanup_needles;

my $distri = testapi::get_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

set_var 'FAIL_EXPECTED', 'SMALL-DISK' if get_var('HDDSIZEGB') < 12;

# Set console for XEN-PV
if (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) {
    set_var('SERIALDEV', 'hvc0');
}

sub load_boot_tests() {
    if (check_var('FLAVOR', 'DVD')) {
        if (get_var("UEFI")) {
            loadtest 'installation/bootloader_uefi';
        }
        else {
            loadtest 'installation/bootloader';
        }
    }
    else {
        if (check_var("BACKEND", "svirt")) {
            loadtest "installation/bootloader_svirt";
        }
        else {
            # For all [non]uefi VMX images as boot screens are the same
            loadtest 'installation/bootloader_uefi';
        }
    }
}

# One-click installer - fate#322328
sub load_inst_tests() {
    loadtest 'casp/oci_overview';

    # Check keyboard layout
    loadtest 'casp/oci_keyboard';
    # Register system
    loadtest 'casp/oci_register' if check_var('REGISTER', 'installation');
    # Set root password
    loadtest 'casp/oci_password';
    # Set system Role
    loadtest 'casp/oci_role';
    # Start installation
    loadtest 'casp/oci_install';

    # Can not start installation with partitioning error
    return if check_var('FAIL_EXPECTED', 'SMALL-DISK');

    # Actual installation
    loadtest 'installation/install_and_reboot';
}

# Feature tests before yast installation
sub load_rcshell_tests {
    loadtest 'casp/rcshell_start';
    loadtest 'casp/libzypp_config';
    loadtest 'casp/one_line_checks';
}

# Feature tests after installation finishes
sub load_feature_tests {
    # Feature tests
    loadtest 'casp/create_autoyast';
    loadtest 'casp/libzypp_config';
    loadtest 'casp/filesystem_ro';
    loadtest 'casp/services_enabled';
    loadtest 'casp/one_line_checks';
    loadtest 'casp/nfs_client' if get_var('NFS_SHARE');

    # Transactional updates
    loadtest 'casp/transactional_update';
    loadtest 'casp/rebootmgr';

    # Journal errors
    loadtest 'casp/journal_check';
}

sub load_stack_tests {
    loadtest "casp/stack_" . get_var('STACK_ROLE');
}

if (get_var('STACK_ROLE')) {
    # ==== CaaSP tests ====
    if (check_var 'STACK_ROLE', 'controller') {
        loadtest 'casp/stack_barrier_init';
        loadtest "support_server/login";
        loadtest "support_server/setup";
    }
    else {
        load_boot_tests;
        load_inst_tests;
        loadtest 'casp/first_boot';
    }
    load_stack_tests;
}
else {
    # ==== MicroOS tests ====
    load_boot_tests;
    if (check_var('FLAVOR', 'DVD')) {
        if (get_var('EXTRA', '') =~ /RCSHELL/) {
            load_rcshell_tests;
            return 1;
        }
        if (get_var('AUTOYAST')) {
            loadtest 'autoyast/installation';
        }
        else {
            load_inst_tests;
        }
        return 1 if get_var 'FAIL_EXPECTED';
    }
    loadtest 'casp/first_boot';
}

# ==== Extra tests run after installation  ====
if (get_var('REGISTER')) {
    loadtest 'casp/register_and_check';
}

if (get_var('EXTRA', '') =~ /FEATURES/) {
    load_feature_tests;
}

1;
# vim: set sw=4 et:
