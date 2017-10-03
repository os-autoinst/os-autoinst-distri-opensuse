# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager Server
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use 5.018;
use parent 'consoletest';
use testapi;
use utils 'zypper_call';
use mm_network;

sub post_fail_hook() {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    assert_script_run 'sed -i \'s/^tar \(.*$\)/tar --warning=no-file-changed -\1 || true/\' /usr/sbin/save_y2logs';
    assert_script_run "save_y2logs /tmp/y2logs.tar.bz2";
    upload_logs "/tmp/y2logs.tar.bz2";
    assert_script_run 'df -h';
    assert_script_run 'df > /tmp/df.txt';
    upload_logs '/tmp/df.txt';

    save_screenshot;
}

sub run {
    my ($self) = @_;
    select_console('root-console');

    #$self->configure_networks('10.0.2.10', get_var('HOSTNAME', 'master'));
    my $ip = '10.0.2.10';
    my $hostname = get_var('HOSTNAME', 'master');
    configure_default_gateway();
    configure_static_ip("$ip/24");
    configure_hostname($hostname);
    assert_script_run "echo \"$ip $hostname.openqa.suse.de $hostname\" >> /etc/hosts";
    assert_script_run 'cat /etc/hosts';
    configure_static_dns(get_host_resolv_conf());

    # check working hostname -f
    assert_script_run "hostname -f|grep $hostname";

    # suma config
    type_string("yast2 susemanager_setup; echo 'SUMA_SETUP_DONE' > /dev/$serialdev\n");

    while (assert_screen(['suma_install_start', 'suma_install_nomem', 'suma_install_nospace'])) {
        if (match_has_tag('suma_install_nomem') or match_has_tag('suma_install_nospace')) {
            send_key('alt-c');
        }
        elsif (match_has_tag('suma_install_start')) {
            send_key('alt-n');
            last;
        }
    }

    assert_screen('suma_emailsetup');
    send_key('backspace') for (1 .. 50);
    type_string('susemanager@suma.openqa.suse.de');
    send_key('alt-n');

    # type in certificate data
    assert_screen('suma_casetup');
    type_string('SUSE');
    send_key('tab');
    type_string('openQA');
    send_key('tab');
    type_string('Nue');
    send_key('tab');
    type_string('DE');
    send_key('tab');
    send_key('tab');
    type_password;
    send_key('tab');
    type_password;
    send_key('alt-n');

    # DB password
    assert_screen('suma_dbsetup');
    send_key('tab');
    # db password check is strict one and consider default $password dictionary based
    type_password('d8w4nts3cr3T');
    send_key('tab');
    type_password('d8w4nts3cr3T');
    send_key('tab');
    send_key('alt-n');

    # SCC details
    assert_screen('suma_sccsetup');
    send_key('tab');
    type_string(get_var('SCC_MIRROR_ID', 'X'));
    send_key('tab');
    type_string(get_var('SCC_MIRROR_PASS', 'X'));
    send_key('alt-n');

    assert_screen('suma_install_ready');
    send_key('ret');
    assert_screen('sume_install_finished', 300);
    send_key('alt-n');
    assert_screen('suma_install-finished-with-link');
    send_key('alt-f');

    wait_serial('SUMA_SETUP_DONE');

    #install generated certificate for HTTPS
    zypper_call('--no-gpg-checks in /srv/www/htdocs/pub/rhn-org-trusted-ssl-cert-*.noarch.rpm');
}

sub test_flags {
    return {fatal => 1};
}

1;
