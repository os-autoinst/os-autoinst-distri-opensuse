# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: SquidWebProxy
# Summary: FIPS tests for squid, test squid as a web proxy
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#207477

use Mojo::Base 'consoletest';
use testapi;
use utils qw(systemctl script_retry);
use version_utils 'is_sle';
use serial_terminal 'select_text_console';

sub cleanup_squid {
    # run() leaves squid serving on :3128 with a generated config and credentials file.
    # squid is slow to settle, so allow the same timeout used for the restart above
    systemctl('stop squid', ignore_failure => 1, timeout => 600);
    script_run 'test -e /etc/squid/squid.conf.orig && mv -f /etc/squid/squid.conf.orig /etc/squid/squid.conf';
    script_run 'rm -f /etc/squid/passwd.txt';
}

sub configure_squid {
    # keep the packaged configuration so it can be restored afterwards
    script_run 'cp -a /etc/squid/squid.conf /etc/squid/squid.conf.orig';
    # configure squid as a web proxy cache
    assert_script_run 'curl ' . data_url('squid/squid_authdigest.conf') . ' -o /etc/squid/squid.conf';
    # on Tumbleweed and SLE16.x the auth helper path is different
    assert_script_run 'sed -i "s|/usr/lib/squid/digest_file_auth|/usr/libexec/squid/digest_file_auth|" /etc/squid/squid.conf' unless is_sle('<16.0');
    # digest is for proxyuser:proxypassword with realm SUSE
    assert_script_run 'echo "proxyuser:SUSE:7935d7d2f866548295f9b3c5400b97e6" > /etc/squid/passwd.txt';
    systemctl('restart squid', timeout => 600);
    systemctl 'status squid';
    # ensure squid is ready to serve requests before proceeding, serial console is too fast, retry
    script_retry 'lsof -i :3128 | grep squid', delay => 30, retry => 3, timeout => 600, fail_message => 'squid is not listening on :3128';
    # SLE16 needs to set selinux
    assert_script_run('semanage port -a -t http_port_t -p tcp ' . (get_required_var('QEMUPORT') + 1)) if is_sle('>=16.0');
}

sub run {
    select_text_console;
    configure_squid;
    my $testfile = data_url('squid/hello.html');
    # try to download file without authentication, should fail
    validate_script_output('curl --no-styled-output --head --proxy http://localhost:3128 ' . $testfile,
        sub { m/HTTP\/1.1 407 Proxy Authentication Required.+Server: squid/s },
        proceed_on_failure => 1);
    # try to download file with authentication, should success
    validate_script_output 'curl --no-styled-output --head --proxy-digest -U proxyuser:proxypassword --proxy http://localhost:3128 ' . $testfile,
      sub { m/HTTP\/1.1 200 OK/ };
}

sub post_run_hook {
    my ($self) = @_;
    cleanup_squid;
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    upload_logs('/var/log/squid/access.log', log_name => 'squid_access.log');
    upload_logs('/var/log/squid/cache.log', log_name => 'squid_cache.log');
    cleanup_squid;
}

1;
