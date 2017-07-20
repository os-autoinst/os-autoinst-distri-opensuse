# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Sets up the mac80211_hwsim module and configures hostapd/NM to create a wpa2 enterprise test infrastructure
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    select_console 'root-console';
    assert_script_run "modprobe mac80211_hwsim radios=2 |& tee /dev/$serialdev";
    save_screenshot;

    $self->install_packages;
    $self->prepare_NM;
    $self->generate_certs;
    $self->configure_hostapd;
    $self->reload_services;
    select_console 'x11';
}

sub install_packages {
    my $required_packages = 'NetworkManager hostapd';
    type_string "# installing required packages\n";
    pkcon_quit;
    zypper_call("in $required_packages");
}

sub prepare_NM {
    type_string "# configure NetworkManager to ignore one of the hwsim interfaces\n";
    release_key 'shift';    # workaround for stuck key

    my $nm_conf = '/etc/NetworkManager/NetworkManager.conf';
    assert_script_run "echo \"[keyfile]\" >> $nm_conf";
    assert_script_run "echo \"unmanaged-devices=interface-name:wlan0,interface-name:hwsim*\" >> $nm_conf";
}

sub generate_certs {
    assert_script_run 'mkdir -p wpa_enterprise_certificates/{CA,server}';
    assert_script_run 'cd wpa_enterprise_certificates';

    type_string "# generate private keys\n";
    assert_script_run 'openssl genrsa -out CA/CA.key 4096';
    assert_script_run 'openssl genrsa -out server/server.key 4096';
    save_screenshot;

    type_string "# generate certificate for CA\n";
    assert_script_run 'openssl req -x509 -new -nodes -key CA/CA.key -sha256 -days 3650 -out CA/CA.crt -subj "/"';

    type_string "# generate certificate signing request for server\n";
    assert_script_run 'openssl req -new -key server/server.key -out server/server.csr -subj "/"';
    save_screenshot;

    type_string "# sign csr with the key/cert from the CA\n";
    assert_script_run 'openssl x509 -req -in server/server.csr -CA CA/CA.crt -CAkey CA/CA.key -CAcreateserial -out server/server.crt -days 3650 -sha256';
    save_screenshot;
}

sub configure_hostapd {
    type_string "# configure hostapd\n";
    assert_script_run 'wget -O /etc/hostapd.conf ' . data_url('hostapd_wpa2-enterprise.conf');

    type_string "# create wpa2 enterprise user\n";
    assert_script_run 'echo \"franz.nord@example.com\" PEAP >> /etc/hostapd.eap_user';
    assert_script_run 'echo \"franz.nord@example.com\" MSCHAPV2 \"nots3cr3t\" [2]>> /etc/hostapd.eap_user';
}

sub reload_services {
    type_string "# reload required services\n";
    assert_script_run 'systemctl restart NetworkManager';
    assert_script_run 'systemctl restart hostapd';
    assert_script_run 'systemctl is-active hostapd';
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    # TODO: collect dmesg (already done by super post fail hook?)
    # TODO: collect hostapd logs
    assert_script_run 'systemctl status hostapd';
    $self->SUPER::post_fail_hook;
}

1;
