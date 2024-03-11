# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: firewalld xrdp gnome-session-core
# Summary: setup xrdp on a fips enabled system
# Maintainer: QE Security <none@suse.de>

use base qw(opensusebasetest x11test);
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use mm_tests;
use utils qw(systemctl zypper_call);
use x11utils qw(turn_off_gnome_screensaver);
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;

    select_console 'root-console';

    my $firewall = $self->firewall;

    turn_off_gnome_screensaver;

    configure_static_network('10.0.2.17/24');

    assert_script_run 'firewall-cmd --zone=public --permanent --add-port=3389/tcp';
    assert_script_run 'firewall-cmd --zone=public --permanent --add-port=3350/tcp';
    assert_script_run 'firewall-cmd --reload';

    zypper_call('in xrdp');

    # Configure XRDP for FIPS
    my $xrdp_cfg = "/etc/xrdp/xrdp.ini";
    assert_script_run "sed -i 's/^security_layer=[^ ]*/security_layer=tls/' $xrdp_cfg";
    assert_script_run "sed -i 's/^#tls_ciphers=[^ ]*/tls_ciphers=FIPS:-eNULL:-aNULL/' $xrdp_cfg";
    assert_script_run "cp /dev/null /etc/xrdp/rsakeys.ini";
    assert_script_run q(openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 365 -subj "/C=DE/ST=Nueremberg/L=Nueremberg/O=QA/OU=security/CN=susetest.example.com");

    systemctl 'start xrdp';

    select_console 'x11';
    x11_start_program('gnome-session-quit --logout --force', valid => 0);

    # Notice xrdp server is ready for remote access
    mutex_create 'xrdp_server_ready';

    # Wait until xrdp client finishes remote access
    wait_for_children;

    # We have to click on the mouse before on ppc64le (bug?)
    mouse_click if get_var('OFW');
    send_key_until_needlematch 'displaymanager', 'esc';

    send_key 'ret';
    assert_screen "displaymanager-password-prompt";
    type_password;
    wait_still_screen 3;
    send_key "ret";
    assert_screen "multiple-logins-notsupport";

    # Force restart on gdm to check if the active session number is correct
    assert_and_click "status-bar";
    assert_and_click "power-button";
    if (is_sle('>=15-SP4')) {
        assert_and_click('reboot-click-restart');
    } else {
        assert_screen([qw(other-users-logged-in-1user other-users-logged-in-2users)]);
        if (match_has_tag('other-users-logged-in-2users')) {
            record_soft_failure 'bsc#1116281 GDM didnt behave correctly when the error message Multiple logins are not supported. is triggered';
        }
    }

    assert_and_click "force-restart";
    type_password;
    send_key "ret";

    $self->wait_boot;
}

1;
