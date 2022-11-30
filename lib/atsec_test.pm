# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base module for ATSEC test cases
# Maintainer: QE Security <none@suse.de>

package atsec_test;

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
);

our $code_dir = '/usr/local/atsec';
our @white_list_for_dbus = (
    'org.freedesktop.hostname1',
    'org.freedesktop.locale1',
    'org.freedesktop.login1',
    'org.freedesktop.machine1',
    'org.freedesktop.PolicyKit1',
    'org.freedesktop.systemd1',
    'org.freedesktop.timedate1',
    'org.freedesktop.DBus',
    'org.opensuse.Network',
    'org.opensuse.Network.DHCP4',
    'org.opensuse.Network.DHCP6',
    'org.opensuse.Network.AUTO4',
    'org.opensuse.Network.Nanny',
    'org.opensuse.Snapper',
    ':1.13',
    ':1.19',
    ':1.22',
    ':1.29',
    ':1.30',
    ':1.36',
    ':1.37'
);

our $server_ip = get_var('SERVER_IP', '10.0.2.101');
our $client_ip = get_var('CLIENT_IP', '10.0.2.102');

1;
