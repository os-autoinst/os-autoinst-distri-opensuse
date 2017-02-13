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

    # Register system
    loadtest 'casp/oci_register' if check_var('REGISTER', 'installation');

    # Set root password
    loadtest 'casp/oci_password';
    # Set system Role
    loadtest 'casp/oci_role';
    # Start installation
    loadtest 'casp/oci_install';

    # Actual installation
    loadtest 'installation/install_and_reboot';
}

# Feature tests before yast installation
sub load_rcshell_tests {
    loadtest 'casp/rcshell_start';
    loadtest 'casp/libzypp_config';
    loadtest 'casp/timezone_utc';
}

# Feature tests after installation finishes
sub load_feature_tests {
    if (check_var('FLAVOR', 'DVD')) {
        # Load DVD feature tests
    }
    else {
        # Load VMX feature tests
    }
    # Load universal feature tests
    loadtest 'casp/libzypp_config';
    loadtest 'casp/timezone_utc';
    loadtest 'casp/filesystem_ro';
    loadtest 'casp/services_enabled';
    loadtest 'casp/one_line_checks';
    loadtest 'casp/nfs_client' if get_var('NFS_SHARE');
    loadtest 'casp/journal_check';
}

# ==== Installation workflow ====
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
}
loadtest 'casp/first_boot';

# ==== Extra tests run after installation  ====
if (get_var('REGISTER')) {
    loadtest 'casp/register_and_check';
}

if (get_var('EXTRA', '') =~ /FEATURES/) {
    load_feature_tests;
}

1;
# vim: set sw=4 et:
