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
);

our $code_dir = '/usr/local/eal4';

# only include static well-known DBus service names in the whitelist
our @static_dbus_whitelist = (
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
    'org.opensuse.Snapper'
);

our $server_ip = get_var('SERVER_IP', '10.0.2.101');
our $client_ip = get_var('CLIENT_IP', '10.0.2.102');

1;
