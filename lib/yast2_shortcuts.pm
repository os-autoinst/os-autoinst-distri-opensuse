# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Shortcuts for yast modules
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package yast2_shortcuts;

use strict;
use warnings;
use testapi;
use version_utils qw(is_leap is_sle);

use Exporter 'import';
our @EXPORT_OK = qw($is_older_product %remote_admin %firewall_settings %firewall_details $confirm %fw);

# VNC configuration
our $is_older_product = is_sle('<15') || is_leap('<15.0');
our %remote_admin = (
    allow_remote_admin_with_session => 'alt-a',
    allow_remote_admin_without_session => 'alt-l',
    do_not_allow_remote_admin => 'alt-n'
);
our %firewall_settings = (
    open_port => $is_older_product ? 'alt-p' : 'alt-f',
    details => 'alt-d'
);
our %firewall_details = (
    network_interfaces => 'alt-e',
    select_all => 'alt-a'
);
our $confirm = $is_older_product ? $cmd{ok} : $cmd{next};

# firewalld UI
our %fw = (
    service_stop => 'alt-s',    # Start-Up: Stop now (button)
    service_start => 'alt-s',    # Start-Up: Start now (button)
    zones_set_as_default => 'alt-s',    # Zones: Set As Default (button)
    interfaces_change_zone => 'alt-c',    # Interfaces: Change Zone (button)
    interfaces_change_zone_zone => 'alt-z',    # Interfaces->Change Zone: Zone (drop-down)
    zones_service_add => 'alt-d',    # Zones->Services: Add (button)
    zones_ports => 'alt-p',    # Zones->Ports: Ports (tab)
    yes => 'alt-y',    # Yes
    tcp => 'alt-t'    # TCP Ports (textbox)
);

1;
