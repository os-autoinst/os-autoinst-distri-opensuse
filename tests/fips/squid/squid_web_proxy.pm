# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: SquidWebProxy
# Summary: FIPS tests for squid, test squid as a web proxy
#
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use testapi;
use utils qw(systemctl);

sub configure_squid {
    # configure squid as a web proxy cache
    assert_script_run 'curl ' . data_url('squid/squid_authdigest.conf') . ' -o /etc/squid/squid.conf';
    # digest is for proxyuser:proxypassword with realm SUSE
    assert_script_run 'echo "proxyuser:SUSE:7935d7d2f866548295f9b3c5400b97e6" > /etc/squid/passwd.txt';
    systemctl('restart squid', timeout => 600);
    systemctl 'status squid';
    # ensure squid is ready to serve requests before proceeding
    assert_script_run('lsof -i :3128 | grep squid');
}

sub run {
    select_console 'root-console';
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

sub post_fail_hook {
    upload_logs('/var/log/squid/access.log', log_name => 'squid_access.log');
    upload_logs('/var/log/squid/cache.log', log_name => 'squid_cache.log');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
