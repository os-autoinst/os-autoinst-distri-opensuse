# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'DBus services exposure' test case of EAL4 test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#109542

use Mojo::Base 'consoletest';
use testapi;
use utils;
use eal4_test;
use Data::Dumper;
use version_utils 'is_sle';
use Utils::Architectures 'is_s390x';
use serial_terminal 'select_serial_terminal';

# List of known safe processes that can have DBus services
my @allowed_processes = qw(
  systemd
  wickedd-dhcp4
  wickedd-dhcp6
  wickedd
  wickedd-auto4
  systemd-logind
  wickedd-nanny
  systemd-machine
  libvirtd
  busctl
  snapperd
  virtnetworkd
  virtqemud
  dbus-send
);

sub parse_results {
    my $output = shift;
    my %results;

    foreach my $line (split(/\n/, $output)) {
        if ($line =~ /^NAME/) {
            # Skip header line
            next;
        }
        elsif ($line =~ /string\s+"(\S+)"/) {
            # Parse output of dbus_send
            $results{$1} = 1;
        }
        elsif ($line =~ /(\S+)\s+(\d+|-)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
            # Parse output of busctl list
            $results{$1} = {
                pid => $2,
                process => $3,
                user => $4,
                connection => $5,
                unit => $6,
                session => $7,
                description => $8
            };
        }
    }

    return %results;
}

sub is_dynamic_name {
    my $name = shift;
    # Dynamic names start with a colon followed by a number (e.g., :1.42)
    return $name =~ /^:\d+\.\d+$/;
}

sub run {
    my ($self) = shift;
    my $test_log = "dbus_services_exposure_log.txt";

    select_console 'root-console';
    select_serial_terminal;

    # Run the test
    my $output_dbus_send = script_output('/bin/dbus-send --system --print-reply --dest=org.freedesktop.DBus --type=method_call /org/freedesktop/DBUS org.freedesktop.DBus.ListNames');
    # Write output to a file for evidence
    assert_script_run('/bin/dbus-send --system --print-reply --dest=org.freedesktop.DBus --type=method_call /org/freedesktop/DBUS org.freedesktop.DBus.ListNames >> ' . $test_log . '');

    my %dbus_send_results = parse_results($output_dbus_send);
    record_info('Results of parsing dbus-send', Dumper(\%dbus_send_results));
    script_run('printf "\n#Results of parsing dbus-send:\n' . Dumper(\%dbus_send_results) . '\n" >> ' . $test_log . '');

    my $output_busctl_list = script_output('busctl list');
    script_run('printf "\n# busctl list:\n' . $output_busctl_list . '\n" >> ' . $test_log . '');

    my %busctl_list_result = parse_results($output_busctl_list);
    record_info('Results of parsing busctl list', Dumper(\%busctl_list_result));
    script_run('printf "\n#Results of parsing busctl list:\n' . Dumper(\%busctl_list_result) . '\n" >> ' . $test_log . '');

    # Add platform-specific services if needed
    if (is_sle('>=15-SP6') && is_s390x) {
        push(@allowed_processes, 'virtqemud');
    }

    # Write to file and upload white_list_for_dbus
    script_run('printf "\n#white_list_for_dbus:\n' . Dumper(\@eal4_test::white_list_for_dbus) . '\n" >> ' . $test_log . '');

    # Analyse the results.
    foreach my $wl (@eal4_test::white_list_for_dbus) {
    # Create a hash for faster lookups
    my %allowed_processes = map { $_ => 1 } @allowed_processes;

    # Filter out static whitelisted services
    foreach my $wl (@eal4_test::static_dbus_whitelist) {
        delete $dbus_send_results{$wl} if exists $dbus_send_results{$wl};

        # Also remove connections associated with whitelisted services
        if (exists $busctl_list_result{$wl} && $busctl_list_result{$wl}->{connection}) {
            my $connection = $busctl_list_result{$wl}->{connection};
            delete $dbus_send_results{$connection} if exists $dbus_send_results{$connection};
        }
    }

    # Filter out dynamic names
    my @dynamic_names = grep { is_dynamic_name($_) } keys %dbus_send_results;
    foreach my $dynamic_name (@dynamic_names) {
        # For dynamic names, check if they belong to allowed processes
        if (exists $busctl_list_result{$dynamic_name}) {
            my $process = $busctl_list_result{$dynamic_name}->{process};
            if (exists $allowed_processes{$process}) {
                delete $dbus_send_results{$dynamic_name};
            }
        }
        # If we can't find process info, assume it's the test process itself (dbus-send)
        else {
            delete $dbus_send_results{$dynamic_name};
        }
    }

    # Check remaining static names against allowed processes
    foreach my $name (keys %dbus_send_results) {
        next if is_dynamic_name($name);    # Already handled dynamic names

        if (exists $busctl_list_result{$name}) {
            my $process = $busctl_list_result{$name}->{process};
            if (exists $allowed_processes{$process}) {
                delete $dbus_send_results{$name};
            }
        }
    }

    # After filtering, there should be no unknown services left
    if (scalar(keys %dbus_send_results) > 0) {
        my @unknown_names = keys %dbus_send_results;
        record_info('Unknown DBus services found', Dumper(\@unknown_names), result => 'fail');
        $self->result('fail');
    }
    upload_log_file($test_log);
}

sub test_flags {
    return {always_rollback => 1};
    else {
        record_info('DBus services check', 'All DBus services are accounted for', result => 'ok');
    }
}

1;
