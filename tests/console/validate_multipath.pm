# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate multipathing on the installed system.
# The multipathing support in SUSE Linux Enterprise Server is based on
# the Device Mapper Multipath module of the Linux kernel and the multipath-tools user space package.
# the Multiple Devices Administration utility (multipath) can be used to view the status of multipathed devices.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';
use repo_tools 'verify_software';

# A multipath device can be identified by its WWID, by a user-friendly name, or by an alias
# (Default) Use the WWIDs shown in the /dev/disk/by-id/ location.
sub get_wwid {
    my $wwid = script_output('awk -F"[/]" \'NF>1 {print $2}\' /etc/multipath/wwids');
    defined $wwid ? return $wwid : die "WWWID not found in /etc/multipath/wwids";
}

sub verify_packages_installed {
    my ($software) = shift;
    record_info('packages', 'Verify required packages installed');
    my $errors = '';
    for my $name (keys %{$software->{packages}}) {
        $errors .= verify_software(name => $name,
            installed => $software->{packages}->{$name}->{installed},
            available => 1);
    }
    die "$errors" if $errors;
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
        assert_matches(qr/$k\s"?$v"?/, $conf_output, "Multipath attribute '$k $v' not found");
    }
}

sub verify_multipath_topology {
    my (%args) = @_;

    my $wwid = $args{wwid};
    my $test_data = $args{test_data};

    record_info('topology', 'Verify multipath topology');
    my $topology_output = script_output("multipath -ll");

    # Check general topology info
    my $topology = $test_data->{topology};
    my $ven_pro_rev = $topology->{vendor_product_revision};
    assert_matches(qr/$wwid dm-0 $ven_pro_rev/, $topology_output,
        'General topology info are not displayed properly');

    # Check specific topology info
    my $features = $topology->{features};
    my $hwhandler = $topology->{hwhandler};
    my $wp = $topology->{wp};
    assert_matches(qr/size=.* features='$features' hwhandler='$hwhandler' wp=$wp/,
        $topology_output, 'Specific topology info are not displayed properly');

    # Check priority groups
    my $policy = $test_data->{attributes}->{path_selector};
    for my $priority_group (@{$topology->{priority_groups}}) {
        my $prio = $priority_group->{prio};
        my $status = $priority_group->{status};
        assert_matches(qr/policy='$policy' prio=$prio status=$status/,
            $topology_output, "Policy/Priority/Status unexpected for priority group");

        for my $path (@{$priority_group->{paths}}) {
            my $name = $path->{name};
            my $status = $path->{status};
            assert_matches(qr/\d:\d:\d:\d+ $name \d+:\d+\s+$status/, $topology_output,
                "Path to '$name' should be '$status'");

            validate_script_output("multipath -d -v3 | grep ^$wwid",
                qr/$wwid.*$name/);
        }
    }
}

sub verify_basic_multipath_configuration {
    my (%args) = @_;

    my $wwid = $args{wwid};
    my $test_data = $args{test_data};

    verify_packages_installed($test_data->{software});

    # Verify required kernel modules are loaded:
    #   * dm_multipath: device-mapper multipath target
    #   * dm_mod        device-mapper driver
    #   * scsi_mod      SCSI core
    verify_kernel_modules_loaded(['dm_multipath', 'dm_mod', 'scsi_mod']);

    # Verify required service are running:
    #   * multipathd.service: Device-Mapper Multipath Device Controller
    verify_services_running(['multipathd']);

    # (Default) The multipath.conf file does not exist until you create and configure it.
    verify_multipath_conf_file_not_exist();
}

sub verify_multipath {
    my (%args) = @_;

    my $wwid = $args{wwid};
    my $test_data = $args{test_data};

    # Verify the currently used multipathd configuration
    verify_multipath_configuration($test_data);

    # Verify the current multipath topology from information fetched in sysfs and the device mapper
    verify_multipath_topology(wwid => $wwid, test_data => $test_data);
}

sub run {
    select_console 'root-console';

    my $test_data_multipath = get_test_suite_data()->{multipath};

    # Obtain dynamic WWID
    my $wwid = get_wwid();

    # Basic verification: checking packages, services, paths and content of files
    verify_basic_multipath_configuration(wwid => $wwid,
        test_data => $test_data_multipath);

    # Verification using multipath tool
    verify_multipath(wwid => $wwid, test_data => $test_data_multipath);
}

1;
