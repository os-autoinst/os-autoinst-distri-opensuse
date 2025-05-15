# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base module for EAL4 test cases
# Maintainer: QE Security <none@suse.de>

package eal4_test;

use base Exporter;

use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  $code_dir
  @white_list_for_dbus
  $server_ip
  $client_ip
  upload_log_file
);

our $code_dir = '/usr/local/eal4';
our @white_list_for_dbus = (
    'org.freedesktop.hostname1',
    'org.freedesktop.locale1',
    'org.freedesktop.login1',
    'org.freedesktop.machine1',
    'org.freedesktop.PolicyKit1',
    'org.freedesktop.systemd1',
    'org.freedesktop.timedate1',
    'org.freedesktop.DBus',
    'org.gtk.vfs.Daemon',
    'org.opensuse.Network',
    'org.opensuse.Network.DHCP4',
    'org.opensuse.Network.DHCP6',
    'org.opensuse.Network.AUTO4',
    'org.opensuse.Network.Nanny',
    'org.opensuse.Snapper',
    ':1.13',
    ':1.19',
    ':1.22',
    ':1.27',
    ':1.28',
    ':1.29',
    ':1.30',
    ':1.31',
    ':1.34',
    ':1.35',
    ':1.36',
    ':1.37',
    ':1.39',
    ':1.41'
);

our $server_ip = get_var('SERVER_IP', '10.0.2.101');
our $client_ip = get_var('CLIENT_IP', '10.0.2.102');

sub upload_log_file {
    # Compress and upload single file for reference
    my $file_name = $_[0];
    if (script_run "! [[ -e $file_name ]]") {
        $file_name =~ s/\s//g;    # remove whitespaces
        script_run "p7zip -k $file_name";
        if (script_run "! [[ -e $file_name.7z ]]") {
            upload_logs($file_name . ".7z", timeout => 600);
            script_run "rm $file_name.7z";
        }
    }
}
1;
