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
use version_utils 'is_caasp';
use main_common;
use caasp qw(update_scheduled get_delayed);

init_main();

# Reuse SP2 needles for YaST installer
sub cleanup_needles {
    remove_common_needles;
    unregister_needle_tags('ENV-INSTLANG-de_DE');
    unregister_needle_tags('ENV-VERSION-12');
    unregister_needle_tags('ENV-VERSION-12-SP1');
    unregister_needle_tags('ENV-VERSION-12-SP2');
    unregister_needle_tags('ENV-SP2ORLATER-0');

    unregister_needle_tags('ENV-FLAVOR-Desktop-DVD');
    unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    unregister_needle_tags('ENV-ARCH-s390x');
    unregister_needle_tags('ENV-OFW-1');

    unregister_needle_tags('CAASP-VERSION-2.0') if is_caasp('3.0+');
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

sub load_caasp_boot_tests {
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
sub load_caasp_inst_tests {
    if (get_var 'AUTOYAST') {
        loadtest 'autoyast/installation';
    }
    else {
        # One Click Installer removed in CaaSP 4.0
        if (is_caasp('4.0+') && !update_scheduled('migration')) {
            loadtest 'caasp/oci_overview';
            loadtest 'caasp/oci_keyboard';
            loadtest 'installation/accept_license';
            if (check_var('REGISTER', 'installation')) {
                loadtest 'installation/scc_registration';
            } else {
                loadtest 'installation/skip_registration';
            }
            loadtest 'installation/system_role';
            loadtest 'installation/caasp_roleconf' unless check_var('SYSTEM_ROLE', 'plain');
            loadtest 'installation/user_settings_root';
            loadtest 'installation/releasenotes';
            loadtest 'installation/installation_overview';
            loadtest 'installation/start_install';

            # Can not start installation with partitioning error
            return if check_var('FAIL_EXPECTED', 'SMALL-DISK');
        } else {
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
        }
        load_common_installation_steps_tests;
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
    # 'create_autoyast' uses serial line heavily, which is not entirely
    # reliable on Hyper-V, no point in executing it as it always fails.
    loadtest 'caasp/create_autoyast' unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
    loadtest 'caasp/libzypp_config';
    loadtest 'caasp/overlayfs' unless is_caasp('4.0+');
    loadtest 'caasp/services_enabled';
    loadtest 'caasp/one_line_checks';
    loadtest 'caasp/nfs_client' if get_var('NFS_SHARE');

    load_transactional_role_tests;

    # Tests that require registered system
    if (get_var 'REGISTER') {
        loadtest 'caasp/register_and_check';
        loadtest 'caasp/register_toolchain' if is_caasp('3.0+');
    }

    # Journal errors
    loadtest 'caasp/journal_check';

    # Container Tests
    loadtest 'console/docker';
    loadtest 'console/docker_runc';
}

sub load_stack_tests {
    if (check_var 'STACK_ROLE', 'controller') {
        if (update_scheduled 'migration') {
            loadtest 'caasp/shift_version', name => 'ver=dec';
        }
        loadtest 'caasp/stack_initialize';
        loadtest 'caasp/stack_configure';
        loadtest 'caasp/stack_bootstrap';
        loadtest 'caasp/stack_kubernetes';

        # CAP deployment needs a lot of resources
        if (check_var('MACHINE', 'cap_x86_64')) {
            loadtest 'caasp/stack_cap';
        }
        # [Update or] Reboot to check cluster will survive
        if (update_scheduled) {
            loadtest 'caasp/stack_update';
        } else {
            loadtest 'caasp/stack_reboot';
        }
        if (update_scheduled 'migration') {
            loadtest 'caasp/shift_version', name => 'ver=inc';
        }
        # Add and remove cluster nodes
        loadtest 'caasp/stack_add_remove' if get_delayed;

        # Section for long running tests
        unless (is_caasp('staging') || is_caasp('local')) {
            loadtest 'caasp/stack_conformance';
        }
        loadtest 'caasp/stack_finalize';
    }
    else {
        loadtest 'caasp/stack_' . get_var('STACK_ROLE');
    }
}

# Init cluster variables
sub stack_init {
    my $children      = get_children;
    my $stack_delayed = get_delayed;

    my $stack_size    = (keys %$children) - $stack_delayed;
    my $stack_masters = $stack_size > 5 ? 3 : 1;              # For 5+ node clusters select 3 masters
    my $stack_workers = $stack_size - $stack_masters - 1;     # Do not count admin node into workers

    # Die more explicitly if you restart controller job (because stack_size = 0)
    die "Stack test can be re-run by restarting admin job" unless $stack_size;

    # Initial bootstrap variables
    set_var 'STACK_SIZE',    $stack_size;
    set_var 'STACK_NODES',   $stack_size - 1;
    set_var 'STACK_MASTERS', $stack_masters;
    set_var 'STACK_WORKERS', $stack_workers;
    set_var 'STACK_DELAYED', $stack_delayed;

    barrier_create("NODES_ONLINE",         $stack_size);
    barrier_create("DELAYED_NODES_ONLINE", $stack_delayed + 1);
}

if (get_var('STACK_ROLE')) {
    # ==== CaaSP tests ====
    if (check_var 'STACK_ROLE', 'controller') {
        stack_init;
        loadtest "support_server/login";
        loadtest "support_server/setup";
    }
    else {
        if (update_scheduled 'migration') {
            loadtest 'caasp/shift_version', name => 'ver=dec';
        }
        load_caasp_boot_tests;
        load_caasp_inst_tests if is_caasp('DVD');
        loadtest 'caasp/first_boot';
    }
    load_stack_tests;
}
else {
    # ==== MicroOS tests ====
    load_caasp_boot_tests;
    if (is_caasp 'DVD') {
        if (get_var('EXTRA', '') =~ /RCSHELL/) {
            load_rcshell_tests;
            return 1;
        }
        load_caasp_inst_tests;
        return 1 if get_var 'FAIL_EXPECTED';
    }
    loadtest 'caasp/first_boot';
}

# MicroOS feature tests
if (get_var('EXTRA', '') =~ /FEATURES/) {
    load_feature_tests;
}

1;
