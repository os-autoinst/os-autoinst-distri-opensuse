# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base module for audit-test test cases
# Maintainer: xiaojing.liu <xiaojing.liu@suse.com>

package atsec_test;

use base Exporter;

use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  $code_dir
  @white_list_for_dbus
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
    'org.opensuse.Snapper'
);

1;
