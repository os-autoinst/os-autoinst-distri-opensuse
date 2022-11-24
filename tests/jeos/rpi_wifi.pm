# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check RPi Wifi: Connect to openQA-worker wifi and do a ping.
#          PSK is set via RPI_WIFI_PSK and ping target via RPI_WIFI_WORKER_IP.
# Maintainer: qe-core team <qe-core@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use Utils::Logging 'save_and_upload_log';

sub run {
    my ($self) = @_;

    assert_script_run 'ip l';
    assert_script_run 'ip a';
    assert_script_run 'rfkill list';
    assert_script_run 'ip l set wlan0 up';
    # This would be a more modern approach but
    # iw is not installed by default:
    # iw dev wlan0 scan | grep -e "^\(BSS\|\sSSID:\)"
    assert_script_run 'iwlist wlan0 scan | grep -e "^\s*\(Cell\|Frequency\|Quality\|ESSID\)"';
    assert_script_run 'ip l set wlan0 down';

    select_console 'root-console';
    enter_cmd 'jeos-config raspberrywifi';
    assert_screen 'jeos-rpiwifi-select';

    # press key until openQA-worker wifi is selected
    send_key_until_needlematch('jeos-rpwifi-select-list-workerwifi-selected', 'o');
    send_key 'ret';

    assert_screen 'jeos-rpiwifi-select-auth-mode-wpapsk';
    send_key 'ret';

    assert_screen 'jeos-rpiwifi-enter-psk';
    enter_cmd(get_required_var('RPI_WIFI_PSK'));

    assert_screen 'text-logged-in-root';
    script_run 'clear';

    assert_script_run 'ip a';
    assert_script_run('ping -c1 ' . get_required_var('RPI_WIFI_WORKER_IP'));
}

sub post_fail_hook {
    my ($self) = @_;
    save_and_upload_log('cat /etc/sysconfig/network/ifcfg-wlan0', 'ifcfg-wlan0.txt');
}

1;
