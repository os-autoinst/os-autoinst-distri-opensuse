# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test dovecot pop3s/imaps services with SSL enabled
# Note: The test case can be run separately for dovecot sanity test,
#       or run as stand-alone mail server (together with postfix)
#       in multi-machine test scenario if MAIL_SERVER var set.
# Maintainer: Qingming Su <qmsu@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi;

sub run {
    my $self             = shift;
    my $dovecot_conf     = "/etc/dovecot/dovecot.conf";
    my $dovecot_conf_dir = "/etc/dovecot/conf.d/";
    my $dovecot_ssl_dir  = "/etc/dovecot/ssl";

    select_console "root-console";

    # Install dovecot package
    zypper_call "in dovecot";

    # Configure dovecot with SSL support
    assert_script_run "mkdir -p $dovecot_ssl_dir";
    assert_script_run "curl " . data_url('openssl/ca-cert.pem') . " -o $dovecot_ssl_dir/ca-cert.pem";
    assert_script_run "curl " . data_url('openssl/mail-server-cert.pem') . " -o $dovecot_ssl_dir/dovecot-cert.pem";
    assert_script_run "curl " . data_url('openssl/mail-server-key.pem') . " -o $dovecot_ssl_dir/dovecot-key.pem";
    assert_script_run "curl " . data_url('dovecot/dovecot.conf') . " -o $dovecot_conf";
    assert_script_run "curl " . data_url('dovecot/10-auth.conf') . " -o $dovecot_conf_dir/10-auth.conf";
    assert_script_run "curl " . data_url('dovecot/10-mail.conf') . " -o $dovecot_conf_dir/10-mail.conf";
    assert_script_run "curl " . data_url('dovecot/10-ssl.conf') . " -o $dovecot_conf_dir/10-ssl.conf";

    # Make sure user dovecot could read the certificate and key files:
    assert_script_run "chmod 640 $dovecot_ssl_dir/*";
    assert_script_run "chgrp dovecot $dovecot_ssl_dir/*";

    # Start dovecot service
    systemctl 'restart dovecot.service';
    systemctl 'is-active dovecot.service';

    # Dovecot will generate SSL parameters at first start up, it takes minutes for long parameters (i.e. 2048)
    script_run "while ! (systemctl -l --no-pager status dovecot.service | grep -q 'SSL parameters regeneration completed'); do sleep 30; done", 900;

    # Print service status for debugging
    systemctl "-l status dovecot.service 2>&1 | tee /dev/$serialdev";
    script_run "(ss -nltp | grep dovecot) 2>&1 | tee /dev/$serialdev";

    # Verify pop3s protocol
    validate_script_output "echo EOF | openssl s_client -connect localhost:995", sub { m/Verify return code: 19/ }, 60;

    # Verify imaps protocol
    validate_script_output "echo EOF | openssl s_client -connect localhost:993", sub { m/Verify return code: 19/ }, 60;

    # Run as stand-alone mail server
    if (get_var('MAIL_SERVER')) {
        mutex_create('mail_server');
        wait_for_children;
    }
}

1;
