# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Overview Tab in YaST2
# lan module dialog.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::OverviewTab;
use strict;
use warnings;
use testapi;
use YaST::workarounds;
use version_utils qw(is_sle);

use constant {
    OVERVIEW_TAB => 'yast2_lan_overview_tab_selected',
    NAME_COLUMN => 'yast2_lan_overview_tab_name_column',
    BRIDGE_DEVICE_IN_LIST => 'yast2_lan_device_bridge_selected',
    BOND_DEVICE_IN_LIST => 'yast2_lan_device_bond_selected',
    VLAN_DEVICE_IN_LIST => 'yast2_lan_device_vlan_selected',
    ETHERNET_DEVICE_IN_LIST => 'yast2_lan_device_ethernet_selected'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
}

sub press_add {
    apply_workaround_bsc1204176(OVERVIEW_TAB) if (is_sle('>=15-SP4'));
    assert_screen(OVERVIEW_TAB);
    send_key('alt-a');
}

sub press_edit {
    apply_workaround_bsc1204176(OVERVIEW_TAB) if (is_sle('>=15-SP4'));
    assert_screen(OVERVIEW_TAB);
    send_key('alt-i');
}

sub press_delete {
    apply_workaround_bsc1204176(OVERVIEW_TAB) if (is_sle('>=15-SP4'));
    assert_screen(OVERVIEW_TAB);
    send_key('alt-t');
}

sub select_device {
    my ($self, $device) = @_;
    assert_and_click(NAME_COLUMN);
    send_key 'home';
    my $device_needle;
    if ($device eq 'bridge') {
        $device_needle = BRIDGE_DEVICE_IN_LIST;
    }
    elsif ($device eq 'bond') {
        $device_needle = BOND_DEVICE_IN_LIST;
    }
    elsif ($device eq 'vlan') {
        $device_needle = VLAN_DEVICE_IN_LIST;
    }
    elsif ($device eq 'eth') {
        $device_needle = ETHERNET_DEVICE_IN_LIST;
    }
    else {
        die "\"$device\" device is not known.";
    }
    send_key_until_needlematch $device_needle, 'down', 6;
}

sub press_ok {
    apply_workaround_bsc1204176(OVERVIEW_TAB) if (is_sle('>=15-SP4'));
    send_key('alt-o');
}

1;
