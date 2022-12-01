# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: NetworkManager hostapd openssl
# Summary: Sets up the mac80211_hwsim module and configures hostapd/NM to create a wpa2 enterprise test infrastructure
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Logging 'save_and_upload_systemd_unit_log';

sub run {
    my $self = shift;
    select_console('root-console');
    assert_script_run "modprobe mac80211_hwsim radios=2 |& tee /dev/$serialdev";

    $self->install_packages;
    $self->prepare_NM;
    $self->generate_certs;
    $self->configure_hostapd;
    $self->adopt_apparmor;
    $self->reload_services;
    select_console 'x11';
}

sub install_packages {
    my $required_packages = 'NetworkManager hostapd';
    enter_cmd 'echo "# installing required packages"';
    quit_packagekit;
    zypper_call("in $required_packages");
}

sub prepare_NM {
    enter_cmd 'echo "# configure NetworkManager to ignore one of the hwsim interfaces"';

    my $nm_conf = '/etc/NetworkManager/NetworkManager.conf';
    assert_script_run "echo \"[keyfile]\" >> $nm_conf";
    assert_script_run "echo \"unmanaged-devices=interface-name:wlan0,interface-name:hwsim*\" >> $nm_conf";
}

sub generate_certs {
    assert_script_run 'mkdir -p /etc/wpa_enterprise_certificates/{CA,server}';
    assert_script_run 'cd /etc/wpa_enterprise_certificates';

    enter_cmd 'echo "# generate private keys"';
    assert_script_run 'openssl genrsa -out CA/CA.key 4096';
    assert_script_run 'openssl genrsa -out server/server.key 4096';

    enter_cmd 'echo "# generate certificate for CA"';
    assert_script_run 'openssl req -x509 -new -nodes -key CA/CA.key -sha256 -days 3650 -out CA/CA.crt -subj "/"';

    enter_cmd 'echo "# generate certificate signing request for server"';
    assert_script_run 'openssl req -new -key server/server.key -out server/server.csr -subj "/"';

    enter_cmd 'echo "# sign csr with the key/cert from the CA"';
    assert_script_run 'openssl x509 -req -in server/server.csr -CA CA/CA.crt -CAkey CA/CA.key -CAcreateserial -out server/server.crt -days 3650 -sha256';
}

sub configure_hostapd {
    enter_cmd 'echo "# configure hostapd"';
    assert_script_run 'wget -O /etc/hostapd.conf ' . data_url('hostapd_wpa2-enterprise.conf');

    enter_cmd 'echo "# create wpa2 enterprise user"';
    assert_script_run 'echo \"franz.nord@example.com\" PEAP >> /etc/hostapd.eap_user';
    assert_script_run 'echo \"franz.nord@example.com\" MSCHAPV2 \"nots3cr3t\" [2]>> /etc/hostapd.eap_user';
}

sub adopt_apparmor {
    if (script_output('systemctl is-active apparmor', proceed_on_failure => 1) eq 'active') {
        enter_cmd 'echo "# adopt AppArmor"';
        enter_cmd q(test ! -e /etc/apparmor.d/usr.sbin.hostapd || sed -i -E 's/^}$/  \/etc\/wpa_enterprise_certificates\/** r,\n}/' /etc/apparmor.d/usr.sbin.hostapd);
        systemctl 'reload apparmor';
    }
}

sub reload_services {
    enter_cmd 'echo "# reload required services"';
    systemctl 'restart NetworkManager';
    systemctl 'restart hostapd';
    systemctl 'is-active hostapd';
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    save_and_upload_systemd_unit_log('hostapd');
    systemctl 'status hostapd';
    $self->SUPER::post_fail_hook;
}

# followup modules rely on the setup conducted here
sub test_flags {
    return {fatal => 1};
}

1;
