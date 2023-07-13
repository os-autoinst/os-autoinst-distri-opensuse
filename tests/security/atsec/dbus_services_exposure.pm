# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'DBus services exposure' test case of ATSec test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#109542

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use atsec_test;
use Data::Dumper;

my %white_list_for_busctl = (
    systemd => 1,
    'wickedd-dhcp4' => 1,
    'wickedd-dhcp6' => 1,
    wickedd => 1,
    'wickedd-auto4' => 1,
    'systemd-logind' => 1,
    'wickedd-nanny' => 1,
    'systemd-machine' => 1,
    libvirtd => 1,
    busctl => 1,
    snapperd => 1,
    'session-1' => 1,
    'session-3' => 1
);

sub parse_results {
    my $output = shift;
    my %results;
    foreach my $line (split(/\n/, $output)) {
        if ($line =~ /^NAME/) {
            # do nothing for the title
            next;
        }
        elsif ($line =~ /string\s+"(\S+)"/) {
            # This regex is used to parse the output of dbus_send, such as:
            # array [
            #    string "org.freedesktop.DBus"
            #    string "org.opensuse.Network.Nanny"
            #    string ":1.7"
            #    string "org.freedesktop.login1"
            #    string ":1.8"
            #    ... ]
            $results{$1} = 1;
        }
        elsif ($line =~ /(\S+)\s+(\d+|-)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
            # This regex is used to parse the output of busctl list, such as:
            # NAME                         PID PROCESS         USER     CONNECTION    UNIT                     SESSION DESCRIPTION
            # :1.0                           1 systemd         root     :1.0          init.scope               -       -
            # :1.60                      30274 busctl          root     :1.60         session-5.scope          5       -
            # :1.8                         970 wickedd-nanny   root     :1.8          wickedd-nanny.service    -       -
            # org.freedesktop.DBus           1 systemd         root     -             init.scope               -       -
            # org.freedesktop.PolicyKit1     - -               -        (activatable) -                        -       -
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

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Run the test
    my $output_dbus_send = script_output('/bin/dbus-send --system --print-reply --dest=org.freedesktop.DBus --type=method_call /org/freedesktop/DBUS org.freedesktop.DBus.ListNames');
    my %dbus_send_results = parse_results($output_dbus_send);
    record_info('Results of parsing dbus-send', Dumper(\%dbus_send_results));

    my $output_busctl_list = script_output('busctl list');
    my %busctl_list_result = parse_results($output_busctl_list);
    record_info('Results of parsing busctl list', Dumper(\%busctl_list_result));

    # Analyse the results.
    foreach my $wl (@atsec_test::white_list_for_dbus) {

        # Remove the well known names which are in the white list.
        delete $dbus_send_results{$wl} if $dbus_send_results{$wl};

        # The destination may be the child object of the well known, such as
        # org.opensuse.Network         966 wickedd         root     :1.5          wickedd.service          -       -
        # So we also consider ':1.5' is well known one.
        if ($busctl_list_result{$wl}) {
            my $connection = $busctl_list_result{$wl}->{connection};
            delete $dbus_send_results{$connection} if $dbus_send_results{$connection};
        }
    }

    # The names not in white list need to be analysed further.
    # Find the names in 'busctl' and check their processes
    foreach my $key (keys %dbus_send_results) {
        next unless $busctl_list_result{$key};
        my $process = $busctl_list_result{$key}->{process};
        delete $dbus_send_results{$key} if $white_list_for_busctl{$process};
    }

    # After filtering there should be only one unknow name. This belongs to 'dbus-send'
    if (scalar(keys %dbus_send_results) > 1) {
        my @unknown_names = keys %dbus_send_results;
        record_info('There are unknow names', Dumper(\@unknown_names), result => 'fail');
        $self->result('fail');
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
