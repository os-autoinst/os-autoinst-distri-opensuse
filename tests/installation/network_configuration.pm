# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify default options in Network Configuration during installation
# and modify some of these options.
# Related documentation:
# - https://documentation.suse.com/sles/15-SP2/html/SLES-all/appendix-linuxrc.html
# - https://github.com/openSUSE/linuxrc/blob/master/linuxrc_hostname.md
# - https://github.com/yast/yast-network/blob/master/doc/hostname.md
# Maintainer: Joaquín Rivera <jeriveramoya@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use registration 'assert_registration_screen_present';

sub check_install_inf_settings {
    my %install_inf_settings = (
        # linuxrc writes by default /etc/install.inf::SetHostnameUsed=0
        # linuxrc writes /etc/install.inf::SetHostnameUsed=1 if `hostname` boot option is used
        SetHostnameUsed => script_output('grep "^SetHostnameUsed:" /etc/install.inf') =~ s/SetHostnameUsed: //r,

        # linuxrc writes by default /etc/install.inf::SetHostname=1
        # linuxrc writes /etc/install.inf::SetHostnameUsed=1 if `hostname` boot option is used
        SetHostname => script_output('grep "^SetHostname:" /etc/install.inf') =~ s/SetHostname: //r,

        # linuxrc doesn't write /etc/install.inf::Hostname by default. So, it is not present by default
        # linuxrc takes the value of `hostname` boot option and writes it to /etc/install.inf::Hostname if `hostname` boot option is used
        Hostname => script_output('grep "^Hostname:" /etc/install.inf', proceed_on_failure => 1) =~ s/Hostname: //r
    );

    die "Parameter `hostname` not used in cmdline, but `/etc/install.inf::SetHostnameUsed` is set to " . $install_inf_settings{SetHostnameUsed} if ($install_inf_settings{SetHostnameUsed} != 0);
    die "By default hostname by DHCP should be enabled, but `/etc/install.inf::SetHostname` is set to " . $install_inf_settings{SetHostname} if ($install_inf_settings{SetHostname} != 1);
    die "By default linuxrc should not specify a static hostname, but `/etc/install.inf::Hostname` is set to " . $install_inf_settings{Hostname} if ($install_inf_settings{Hostname});
}

sub get_etc_sysconfig_network_dhcp_settings {
    my %sysconfig_network_dhcp = (
        # linuxrc writes by default /etc/sysconfig/network/dhcp::DHCLIENT_SET_HOSTNAME="yes"
        'DHCLIENT_SET_HOSTNAME' => script_output('grep "^DHCLIENT_SET_HOSTNAME=" /etc/sysconfig/network/dhcp') =~ s/DHCLIENT_SET_HOSTNAME="(\w*)"/$1/r
    );

    return %sysconfig_network_dhcp;
}

sub run {
    select_console('install-shell');
    check_install_inf_settings();
    my %sysconfig_network_dhcp = get_etc_sysconfig_network_dhcp_settings();
    select_console 'installation';

    if (get_var 'OFFLINE_SUT') {
        assert_screen 'inst-networksettings';
    }
    else {
        assert_registration_screen_present;
        send_key 'alt-w';    # Network Configuration
        assert_screen 'inst-network';
        send_key 'alt-s';    # Hostname/DNS
        assert_screen 'inst-network-hostname-dns-tab';
        assert_and_click 'inst-network-hostname-dhcp';
        assert_and_click 'inst-network-hostname-dhcp-modified';
    }
    send_key $cmd{next};
}

1;
