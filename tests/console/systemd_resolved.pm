# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd_resolved
# Summary: Check that the network daemon in use is the expected one
# - setup the nss resolved in /etc/nsswitch.conf
# - test some DNS queries
# - test systemd-resolved with DNSOverTLS and DNSSEC
# - setting up systemd resolved locally, switch /etc/resolv.conf to it
# Maintainer: qe-core <qe-core@suse.com>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub clean_up {
    assert_script_run("rm /etc/resolv.conf");
    assert_script_run("rm /etc/systemd/resolved.conf.d/dnssec.conf");
    assert_script_run("rm /etc/systemd/resolved.conf.d/dns_over_tls.conf");
    assert_script_run("mv /etc/resolv.conf{.bak,}");
    assert_script_run("rm /etc/nsswitch.conf");
    systemctl 'disable --now systemd-resolved', timeout => 30;
    zypper_call 'rm systemd-resolved';
    systemctl 'restart NetworkManager', timeout => 30;

}

sub run {
    select_serial_terminal;

    zypper_call 'in systemd-resolved';
    systemctl 'stop NetworkManager', timeout => 30;
    assert_script_run("mv /etc/resolv.conf{,.bak}");
    # Add workaround for bsc#1248501
    assert_script_run("touch /usr/share/dbus-1/system.d/org.freedesktop.resolve1.conf");
    systemctl 'enable --now systemd-resolved', timeout => 30;
    assert_script_run 'ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf';
    assert_script_run "cp /usr/etc/nsswitch.conf /etc/nsswitch.conf";
    assert_script_run "sed -i 's/^hosts:.*files/hosts: files resolve [!UNAVAIL=return]/' /etc/nsswitch.conf";
    script_run 'cat /etc/nsswitch.conf';
    systemctl 'start NetworkManager', timeout => 30;
    validate_script_output("resolvectl status", sub { m/Global/ });
    validate_script_output("resolvectl query www.suse.com", sub { m/\d+\.\d+\.\d+\.\d+/ });

    # Test systemd-resolved with DNSOverTLS and DNSSEC
    assert_script_run("touch /etc/systemd/resolved.conf.d/dnssec.conf");
    assert_script_run("echo '[Resolve]' >> /etc/systemd/resolved.conf.d/dnssec.conf");
    assert_script_run("echo 'DNSSEC=true' >> /etc/systemd/resolved.conf.d/dnssec.conf");
    script_run 'cat /etc/systemd/resolved.conf.d/dnssec.conf';
    assert_script_run("touch /etc/systemd/resolved.conf.d/dns_over_tls.conf");
    assert_script_run("echo '[Resolve]' >> /etc/systemd/resolved.conf.d/dns_over_tls.conf");
    assert_script_run("echo 'DNSOverTLS=yes' >> /etc/systemd/resolved.conf.d/dns_over_tls.conf");
    assert_script_run("echo 'DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net' >> /etc/systemd/resolved.conf.d/dns_over_tls.conf");
    assert_script_run("echo 'FallbackDNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com' >> /etc/systemd/resolved.conf.d/dns_over_tls.conf");
    script_run 'cat /etc/systemd/resolved.conf.d/dns_over_tls.conf';
    systemctl 'restart systemd-resolved', timeout => 30;
    # Validate systemd-resolved with DNSSEC
    validate_script_output("resolvectl query go.dnscheck.tools", sub { m/Data is authenticated: yes/ });
    # Validate systemd-resolved with DNSOverTLS
    validate_script_output("resolvectl query go.dnscheck.tools", sub { m/Data was acquired via local or encrypted transport: yes/ });
}

sub post_run_hook {
    my ($self) = shift;
    clean_up();
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    clean_up();
}

1;
