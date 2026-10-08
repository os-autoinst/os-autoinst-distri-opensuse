# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked (WPA-PSK with DHCP)
#          If a connection is established, the AP will went down and a other
#          SSID appear. Check if the wpa_supplicant also connect to the new one.
#
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(random_string);

has wicked_version => '>=0.6.66';
has ssid => 'First SSID';
has ssid_1 => 'Second SSID';
has ssid_2 => 'Third SSID';
has ssid_3 => 'Fourth SSID';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    hw_mode=g
    ieee80211n=1

    ssid={{ssid}}

    bss={{ref_bss1}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_1}}
 
    bss={{ref_bss2}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_2}}
   
    bss={{ref_bss3}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_3}}
  );


has ifcfg_wlan => sub { [
        q(
            WIRELESS='yes'
        ),
        q(
            WIRELESS_AP_SCANMODE='1'
        ),
        q(
            WIRELESS_WPA_DRIVER='nl80211'
        ),
] };



sub run {
    my $self = shift;
    select_serial_terminal;
    return if ($self->skip_by_wicked_version());

    $self->setup_ref();

    for my $ifcfg (@{$self->ifcfg_wlan}) {

        $self->ssid(random_string(undef, 8));
        $self->ssid_1(random_string(undef, 8));
        $self->ssid_2(random_string(undef, 8));
        $self->ssid_3(random_string(undef, 8));
        $self->hostapd_start($self->hostapd_conf());

        $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $ifcfg);
        $self->wicked_command('ifup --timeout 20', $self->sut_ifc);

        record_info('show-xml', script_output('wicked show-xml ' . $self->sut_ifc));
        record_info('show-config', script_output('wicked show-config ' . $self->sut_ifc));
        record_info('scan-results', script_output('wicked show-xml ' . $self->sut_ifc . q( | wicked xpath --reference 'object/wireless/scan-results/bss' 'bssid:%{bssid} ssid:%{ssid} age:%{age}')));

        my $cmd_scanresult = sprintf(q(wicked show-xml %s | wicked xpath --reference 'object/wireless/scan-results/bss' '%%{ssid}' | sort), $self->sut_ifc);
        validate_script_output($cmd_scanresult, sub {
                my @got = sort(split(/\r?\n/));
                my @exp = sort($self->ssid, $self->ssid_1, $self->ssid_2, $self->ssid_3);

                for my $exp_ssid (@exp) {
                    return undef unless grep { qr/^$exp_ssid$/ } @got;
                }
                return 1;
        });

        $self->wicked_command('ifdown', $self->sut_ifc);
        $self->hostapd_kill();
    }
}

1;
