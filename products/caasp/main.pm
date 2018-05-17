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
use caasp qw(update_scheduled get_delayed_worker);

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
}
$needle::cleanuphandler = \&cleanup_needles;

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

set_var 'FAIL_EXPECTED', 'SMALL-DISK' if get_var('HDDSIZEGB') < 12;

if (is_caasp('kubic')) {
    set_var('SYSTEM_ROLE_FIRST_FLOW', 1);
}

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
        if (get_var 'MULTI_STEP_KUBIC_FLOW') {
            load_inst_tests;
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

            load_common_installation_steps_tests;
        }
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
    # Container Tests
    loadtest 'caasp/create_autoyast' unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
    loadtest 'caasp/libzypp_config';
    loadtest 'caasp/filesystem_ro';
    loadtest 'caasp/overlayfs';
    loadtest 'caasp/services_enabled';
    loadtest 'caasp/one_line_checks';
    loadtest 'caasp/nfs_client' if get_var('NFS_SHARE');

    # Transactional updates
    loadtest 'caasp/transactional_update';
    loadtest 'caasp/rebootmgr';

    # Journal errors
    loadtest 'caasp/journal_check';

    # Container Tests
    if (!check_var('SYSTEM_ROLE', 'microos')) {
        loadtest 'console/docker';
        loadtest 'console/docker_runc';
        # OCI Containers
        if (is_caasp('kubic') && check_var('SYSTEM_ROLE', 'plain')) {
            loadtest 'console/kubeadm';
            loadtest 'console/skopeo';
            loadtest 'console/umoci';
            loadtest 'console/runc';
            loadtest 'console/rootless';
        }
    }
}

sub load_stack_tests {
    if (check_var 'STACK_ROLE', 'controller') {
        loadtest 'caasp/stack_initialize';
        loadtest 'caasp/stack_configure';
        loadtest 'caasp/stack_bootstrap';
        loadtest 'caasp/stack_kubernetes';
        if (update_scheduled) {
            loadtest 'caasp/stack_update';
        }
        else {
            loadtest 'caasp/stack_reboot';
        }
        loadtest 'caasp/stack_add_remove' if get_delayed_worker;
        unless (is_caasp('staging') || is_caasp('local')) {
            loadtest 'caasp/stack_conformance';
        }

        loadtest 'caasp/stack_finalize';
    }
    else {
        loadtest "caasp/stack_" . get_var('STACK_ROLE');
    }
}

# Init cluster variables
sub stack_init {
    my $children       = get_children;
    my $delayed_worker = get_delayed_worker;

    my $stack_size    = (keys %$children) - !!$delayed_worker;
    my $stack_masters = $stack_size > 6 ? 3 : 1;                 # For 6+ node clusters select 3 masters
    my $stack_workers = $stack_size - $stack_masters - 1;        # Do not count admin node into workers

    # Die more explicitly if you restart controller job (because stack_size = 0)
    die "Stack test can be re-run by restarting admin job" unless $stack_size;

    # Initial bootstrap variables
    set_var 'STACK_SIZE',    $stack_size;
    set_var 'STACK_NODES',   $stack_size - 1;
    set_var 'STACK_MASTERS', $stack_masters;
    set_var 'STACK_WORKERS', $stack_workers;

    barrier_create("WORKERS_INSTALLED", $stack_size);
}

if (get_var('STACK_ROLE')) {
    # ==== CaaSP tests ====
    if (check_var 'STACK_ROLE', 'controller') {
        stack_init;
        loadtest "support_server/login";
        loadtest "support_server/setup";
    }
    else {
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

# ==== Extra tests run after installation  ====
# REGISTER = 'suseconnect' -> Registers with SCC after the installation
# REGISTER = 'installation' -> Registers with SCC during the installation
if (get_var('REGISTER') && !check_var('STACK_ROLE', 'controller')) {
    loadtest 'caasp/register_and_check';
    loadtest 'caasp/register_toolchain' if is_caasp('3.0+');
}

if (get_var('EXTRA', '') =~ /FEATURES/) {
    load_feature_tests;
}

1;
# vim: set sw=4 et:
