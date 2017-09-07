use strict;
use warnings;
use testapi qw(check_var get_var get_required_var set_var);
use needle;
use File::Basename;
use mmapi 'get_children';
use lockapi 'barrier_create';

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
    unregister_needle_tags('ENV-OFW-1');
}
$needle::cleanuphandler = \&cleanup_needles;

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

set_var 'FAIL_EXPECTED', 'SMALL-DISK' if get_var('HDDSIZEGB') < 12;

# Set console for XEN-PV
if (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) {
    set_var('SERIALDEV', 'hvc0');
}

sub load_boot_tests {
    if (is_caasp 'DVD') {
        if (get_var("UEFI")) {
            loadtest 'installation/bootloader_uefi';
        }
        else {
            loadtest 'installation/bootloader';
        }
    }
    else {
        if (check_var("BACKEND", "svirt")) {
            if (check_var("VIRSH_VMM_FAMILY", "hyperv")) {
                loadtest "installation/bootloader_hyperv";
            }
            else {
                loadtest "installation/bootloader_svirt";
            }
        }
        # Make sure GRUB is present and in sane state (except Xen PV)
        loadtest 'installation/bootloader_uefi' unless check_var('VIRSH_VMM_TYPE', 'linux');
    }
}

# One-click installer - fate#322328
sub load_inst_tests {
    if (get_var 'AUTOYAST') {
        loadtest 'autoyast/installation';
    }
    else {
        loadtest 'caasp/oci_overview';

        # Check keyboard layout
        loadtest 'caasp/oci_keyboard';
        # Register system
        loadtest 'caasp/oci_register' if check_var('REGISTER', 'installation');
        # Set root password
        loadtest 'caasp/oci_password';
        # Set system Role
        loadtest 'caasp/oci_role';
        # Start installation
        loadtest 'caasp/oci_install';

        # Can not start installation with partitioning error
        return if check_var('FAIL_EXPECTED', 'SMALL-DISK');
        return if check_var('FAIL_EXPECTED', 'BSC_1043619');

        # Actual installation
        loadtest 'installation/install_and_reboot';
    }
}

# Feature tests before yast installation
sub load_rcshell_tests {
    loadtest 'caasp/rcshell_start';
    loadtest 'caasp/libzypp_config';
    loadtest 'caasp/one_line_checks';
}

# Feature tests after installation finishes
sub load_feature_tests {
    # Feature tests
    # 'create_autoyast' uses serial line heavily, which is notentirely
    # reliable on Hyper-V, no point in executing it as it always fails.
    loadtest 'caasp/create_autoyast' unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
    loadtest 'caasp/libzypp_config';
    loadtest 'caasp/filesystem_ro';
    loadtest 'caasp/services_enabled';
    loadtest 'caasp/one_line_checks';
    loadtest 'caasp/nfs_client' if get_var('NFS_SHARE');

    # Transactional updates
    loadtest 'caasp/transactional_update';
    loadtest 'caasp/rebootmgr';

    # Journal errors
    loadtest 'caasp/journal_check';

    # Docker
    loadtest 'console/docker';
}

sub load_stack_tests {
    loadtest "caasp/stack_" . get_var('STACK_ROLE');
}

# Init barriers on on controller node startup
# Have to be done here because grub2 needle times out on supportserver
sub stack_barriers_init {
    my $children = get_children;
    my $jobs     = 1 + keys %$children;

    barrier_create("VELUM_STARTED",     $jobs);        # Velum node is ready
    barrier_create("WORKERS_INSTALLED", $jobs - 1);    # Nodes are installed
    barrier_create("CNTRL_FINISHED",    $jobs);        # We are finished with testing

    set_var "STACK_SIZE", $jobs;
}

if (get_var('STACK_ROLE')) {
    # ==== CaaSP tests ====
    if (check_var 'STACK_ROLE', 'controller') {
        stack_barriers_init;
        loadtest "support_server/login";
        loadtest "support_server/setup";
    }
    else {
        load_boot_tests;
        load_inst_tests if is_caasp('DVD');
        loadtest 'caasp/first_boot';
    }
    load_stack_tests;
}
else {
    # ==== MicroOS tests ====
    load_boot_tests;
    if (is_caasp 'DVD') {
        if (get_var('EXTRA', '') =~ /RCSHELL/) {
            load_rcshell_tests;
            return 1;
        }
        load_inst_tests;
        return 1 if get_var 'FAIL_EXPECTED';
    }
    loadtest 'caasp/first_boot';
}

# ==== Extra tests run after installation  ====
if (get_var('REGISTER')) {
    loadtest 'caasp/register_and_check';
}

if (get_var('EXTRA', '') =~ /FEATURES/) {
    load_feature_tests;
}

1;
# vim: set sw=4 et:
