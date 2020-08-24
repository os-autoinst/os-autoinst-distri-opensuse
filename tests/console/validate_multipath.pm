# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate multipathing on the installed system.
# The multipathing support in SUSE Linux Enterprise Server is based on
# the Device Mapper Multipath module of the Linux kernel and the multipath-tools user space package.
# the Multiple Devices Administration utility (multipath) can be used to view the status of multipathed devices.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub verify_packages_installed {
    my ($pkg_ref) = shift;
    record_info('pkgs', 'Verify required packages installed');
    assert_script_run("rpm -qa | grep $_",
        fail_message => "$_ is not installed in the system") for (@{$pkg_ref});
}

sub verify_kernel_modules_loaded {
    my ($mod_ref) = shift;
    record_info('kernel module', 'Verify required kernel modules loaded');
    assert_script_run("lsmod | grep ^$_",
        fail_message => "$_ kernel module is not loaded") for (@{$mod_ref});
}

sub verify_services_running {
    my ($srv_ref) = shift;
    record_info('services', 'Verify required systemd services running');
    validate_script_output("systemctl show -p SubState --value $_", qr/running/) for (@{$srv_ref});
}

sub verify_worldwide_id_used {
    my ($wwid) = shift;
    record_info('WWID', 'Verify Worldwide ID is used');
    assert_script_run("grep \"$wwid\" /etc/multipath/wwids",
        fail_message => "WWID '$wwid' not listed in '/etc/multipath/wwids'");
}

sub verify_devices_mapped {
    my ($test_data) = shift;

    record_info('dev map', 'Verify device mapping');
    # Devices with WWID are listed in directories /dev/mapper and /dev/disk/by-id/ with symbolic
    # links pointing to their respective multipath device which are created under /dev
    # in the form of /dev/dm-N (non-administrative devices)
    while (my ($admin_dev, $internal_dev) = each(%{$test_data->{device_map}})) {
        for my $path (qw(/dev/mapper /dev/disk/by-id)) {
            assert_script_run("ls -l $path | grep ^l.*$admin_dev.*-\>.*$internal_dev",
                fail_message => "Expected multipath device listed in '$path' with name " .
                  "'$admin_dev' with symbolic link pointing to '/dev/$internal_dev'");
        }
    }
}

sub verify_multipath_conf_file_not_exist {
    record_info('/etc/multipath.conf', 'Verify /etc/multipath.conf does not exist');
    assert_script_run('! test -e /etc/multipath.conf',
        fail_message => "File '/etc/multipath.conf' is not expected to be created by default");
}

sub verify_multipath_configuration {
    my ($test_data) = shift;

    record_info('configuration', 'Verify multipath configuration with multipath tool');
    my $conf_output = script_output("multipath -t");
    while (my ($k, $v) = each(%{$test_data->{attributes}})) {
        assert_matches(qr/$k\s$v/, $conf_output, "Multipath attribute '$k $v' not found");
    }
}

sub verify_multipath_topology {
    my ($test_data) = shift;

    my $wwid = $test_data->{WWID};
    my $dm_N = $test_data->{device_map}->{hd0};

    record_info('topology', 'Verify multipath topology');
    my $topology_output = script_output("multipath -l");

    # Check infomation header
    assert_matches(qr/$wwid $dm_N/, $topology_output,
        "Topology information does not show header info with WWID dm-N");
    # Check paths
    while (my ($dev, $values) = each(%{$test_data->{topology}})) {
        # Check policy
        assert_matches(qr/prio=$values->{prio} status=$values->{status}/, $topology_output,
            "Policy unexpected for multipath path to $dev");
        # Check device
        assert_matches(qr/$dev.*active.*running/, $topology_output,
            "Device '$dev' should be active and running");
    }
}

sub verify_paths_list {
    my ($test_data) = shift;
    my $wwid = $test_data->{WWID};

    record_info('paths', 'Verify multipath paths');
    while (my ($dev, $values) = each(%{$test_data->{paths_list}})) {
        validate_script_output("multipath -d -v3 | grep ^$wwid",
            qr/$wwid.*$dev.*$values->{vendor_product_revision}/);
    }
}

sub verify_basic_multipath_configuration {
    my ($test_data) = shift;

    # Verify required packages are installed:
    #   * device-mapper:   Device Mapper Tools
    #   * multipath-tools: Tools to Manage Multipathed Devices with the device-mapper
    #   * kpartx:          Manages partition tables on device-mapper devices
    verify_packages_installed(['device-mapper', 'multipath-tools', 'kpartx']);

    # Verify required kernel modules are loaded:
    #   * dm_multipath: device-mapper multipath target
    #   * dm_mod        device-mapper driver
    #   * scsi_mod      SCSI core
    verify_kernel_modules_loaded(['dm_multipath', 'dm_mod', 'scsi_mod']);

    # Verify required service are running:
    #   * multipathd.service: Device-Mapper Multipath Device Controller
    verify_services_running(['multipathd']);

    # A multipath device can be identified by its WWID, by a user-friendly name, or by an alias
    # (Default) Use the WWIDs shown in the /dev/disk/by-id/ location.
    verify_worldwide_id_used($test_data->{WWID});

    # Verify internal device mapping
    verify_devices_mapped($test_data);

    # (Default) The multipath.conf file does not exist until you create and configure it.
    verify_multipath_conf_file_not_exist();
}

sub verify_multipath {
    my ($test_data) = shift;

    # Verify the currently used multipathd configuration
    verify_multipath_configuration($test_data);

    # Verify the current multipath topology from information fetched in sysfs and the device mapper
    verify_multipath_topology($test_data);

    # Verify paths list
    verify_paths_list($test_data);
}

sub run {
    select_console 'root-console';
    my $test_data = get_test_suite_data();

    # Basic verification: checking packages, services, paths and content of files
    verify_basic_multipath_configuration($test_data);

    # Verification using multipath tool
    verify_multipath($test_data);
}

1;
