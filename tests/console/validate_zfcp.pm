# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate zfcp in the installed system:
#          - Verification of FCP devices online
#          - Verification of FCP devices
#          - Verification of LUNs visible as SCSI devices
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use utils qw(arrays_subset);

# Get devices online.
# For each physical adapter in the mainframe there is a corresponding FCP channel providing physical
# connection to the SAN Fabric (multiple FCP channels are configured to increase the I/O bandwidth
# and improve data availability).
# HBAs are shown in the system as FCP devices
sub get_fcp_devices_online {
    record_info('FCP devices', 'Get expected devices online');

    # get test data
    my $test_data = get_test_suite_data();

    # FCP devices (online and offline)
    my $fcp_devices = $test_data->{zfcp}->{fcp_devices};
    # filtering online devices
    return [grep { $_->{attributes}->{online} } @{$fcp_devices}];
}

# Compare fcp devices
sub compare_fcp_devices {
    my (%args) = @_;

    my $devs_expected = [map { $_->{fcp_channel} } @{$args{devs_expected}}];
    my $devs_current = $args{devs_current};
    my $only_warning = $args{only_warning};

    if (scalar arrays_subset($devs_expected, $devs_current) > 0) {
        my $message = "Unexpected FCP devices online found in the installed system. " .
          "Please, check if it was an error or is intended and new adaptor became renamed " .
          "or (not) available:\n" .
          "Expected: " . join(",", @{$devs_expected}) . " " .
          "Got: " . join(",", @{$devs_current});
        $only_warning ? record_info('WARNING', $message) : die $message;
    }
}

# Checks if the installed system use all devices available online or throw a warning
sub check_fcp_devices_against_installed_system {
    my ($fcp_devices) = shift;

    my $fcp_devices_system = [split(/\n/,
            script_output("lszdev --no-headings --columns ID zfcp-host --online"))];
    compare_fcp_devices(devs_expected => $fcp_devices, devs_current => $fcp_devices_system,
        only_warning => 1);
}

# Checks if devices introduced during installation (for instance set via MACHINE level)
# match the ones for verification (specified in test data)
sub verify_fcp_devices_against_infrastructure {
    my ($fcp_devices) = shift;

    my $fcp_devices_infra = [split(/,/, get_required_var('ZFCP_ADAPTERS'))];
    compare_fcp_devices(devs_expected => $fcp_devices, devs_current => $fcp_devices_infra);
}

# Verify FCP attributes, for instance:
#   port_type: FCP setups running in NPIV mode detect the LUNs automatically and
#              after setting the device online no further configuration is necessary.
#   online:    Channel is online or offline
sub verify_fcp_attributes {
    my ($fcp_devices) = shift;

    for my $fcp_device (@{$fcp_devices}) {
        my $fcp_channel = $fcp_device->{fcp_channel};
        while (my ($attribute, $value) = each(%{$fcp_device->{attributes}})) {
            validate_script_output("lszfcp -b $fcp_channel -a | grep $attribute", qr/\"$value\"/);
        }
    }
}
# Set FCP devices offline and set back online
sub verify_fcp_devices_can_be_set_online_offline {
    my ($fcp_devices) = shift;

    for my $fcp_device (@{$fcp_devices}) {
        my $fcp_channel = $fcp_device->{fcp_channel};
        assert_script_run("chccwdev -d $fcp_channel",
            fail_message => "FCP device with bus $fcp_channel could not be set offline");
        assert_script_run("chccwdev -e $fcp_channel",
            fail_message => "FCP device with bus $fcp_channel could not be set back online");
    }
}

# Verify SCSI devices using following commands:
#   lsscsi: list SCSI devices (or hosts) and their attributes.
#   lszfcp: list information about zfcp adapters, ports, and units
#   lszdev: Display configuration of z Systems specific devices
sub verify_scsi_devices {
    my ($fcp_devices) = shift;

    record_info('LUNs SCSI', 'Verification of LUNs visible as SCSI devices');
    for my $fcp_device (@{$fcp_devices}) {
        for my $lun (@{$fcp_device->{fcp_luns}}) {
            # Validate scsi devices with specific scsi command
            my $peripheral_type = $lun->{scsi}->{peripheral_type};
            my $vendor_model_revision = $lun->{scsi}->{vendor_model_revision};

            # Validate scsi devices with specific command for zfcp: lszfcp
            my $fcp_channel = $fcp_device->{fcp_channel};
            my $wwpn = $lun->{wwpn};
            my $bus_wwpn = "$fcp_channel/$wwpn";
            my $iscsi_output = script_output("lszfcp -D -b $fcp_channel | grep '$bus_wwpn'");

            # Store SCSI target id H:C:T:L
            my $hctl;
            if ($iscsi_output =~ /(?<hctl>(\d+:){3}\d+)/)
            {
                $hctl = $+{hctl};
            } else {
                die "Could not parse SCSI target ID for the device with wwpn: '$bus_wwpn'";
            }

            assert_script_run("lsscsi | grep '$hctl.*/dev/'",
                fail_message => "Device with wwpn: '$bus_wwpn' is not mapped to any device node");

            # Validate scsi devices with specific command for zfcp: lszdev
            $bus_wwpn = "$fcp_channel:$wwpn";
            assert_script_run("lszdev --no-headings zfcp-lun | grep $bus_wwpn",
                fail_message => "Device with wwpn: '$bus_wwpn' not listed in lszdev output");

            # Set SCSI devices offline and set back online (other states are also possible)
            my $state_file = "\"/sys/bus/scsi/devices/$hctl/state\"";
            validate_script_output("cat $state_file", qr/running/);
            assert_script_run("echo offline > $state_file",
                fail_message => "state offline could not be set for SCSI device $hctl");
            validate_script_output("cat $state_file", qr/offline/);
            assert_script_run("echo running > $state_file",
                fail_message => "state online could not be set for SCSI device $hctl");
            validate_script_output("cat $state_file", qr/running/);
        }
    }
}

# Verify FCP devices
sub verify_fcp_devices {
    my ($fcp_devices) = shift;

    record_info('FCP devices', 'Verification of FCP devices');
    check_fcp_devices_against_installed_system($fcp_devices);
    verify_fcp_devices_against_infrastructure($fcp_devices);
    verify_fcp_attributes($fcp_devices);
    verify_fcp_devices_can_be_set_online_offline($fcp_devices);
}

# The zfcp_ping and zfcp_show commands can probe ports and retrieve information about ports
# in the attached storage servers and in interconnect elements such as switches, bridges, and hubs.
# Because the commands are processed by the SAN management server, information can be obtained
# about ports and interconnect elements that are not connected to your FCP channel.
# Thus, zfcp_ping and zfcp_show can help to identify configuration problems in a SAN.
# The zfcp_show command retrieves information about the SAN topology and details about the SAN components.
sub investigate_san_fabric {
    my ($fcp_devices) = shift;

    zypper_call("in libzfcphbaapi0");
    for my $fcp_device (@{$fcp_devices}) {
        for my $lun (@{$fcp_devices->{fcp_luns}}) {
            my $wwpn = $lun->{wwpn};
            script_run("zfcp_ping -t97 $wwpn >> /tmp/zfcp_ping_wwpns.log");
        }
    }
    upload_logs('/tmp/zfcp_ping_wwpns.log');
    script_run('zfcp_show -v > /tmp/zfcp_show.log');
    upload_logs('/tmp/zfcp_show.log');
}

sub run {
    select_console 'root-console';

    my $fcp_devices = get_fcp_devices_online();
    verify_fcp_devices($fcp_devices);
    verify_scsi_devices($fcp_devices);
}

sub post_fail_hook {
    my ($self) = shift;

    my $fcp_devices_online = get_fcp_devices_online();
    investigate_san_fabric($fcp_devices_online);
    $self->SUPER::post_fail_hook();
}

1;
