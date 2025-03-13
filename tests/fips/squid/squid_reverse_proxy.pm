# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: SquidReverseProxy
# Summary: FIPS tests for squid as reverse web proxy providing SSL encrypt connection for HTTP web site
#
# Maintainer: QE Security <none@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils qw(systemctl zypper_call script_retry);
use serial_terminal qw(select_serial_terminal);

sub configure_apache {
    zypper_call 'in apache2';
    # configure apache as a webserver on port 8080
    assert_script_run 'mkdir -p /srv/www/vhosts/Test';
    assert_script_run 'curl ' . data_url('squid/apache_vhost.conf') . ' -o /etc/apache2/vhosts.d/vhost.conf';
    assert_script_run 'curl ' . data_url('squid/hello.html') . ' -o /srv/www/vhosts/Test/hello.html';
    assert_script_run "sed -i -e 's/^Listen 80.*/Listen 8080/' /etc/apache2/listen.conf";
    systemctl 'restart apache2';
    systemctl 'status apache2';
    # ensure apache is working
    validate_script_output 'curl http://localhost:8080/hello.html', sub { m/Hello/ };
}

sub configure_squid {
    # generate self-signed X509 cert for squid https
    assert_script_run("openssl req -x509 -nodes -days 365 -newkey rsa:2048"
          . " -subj '/C=DE/ST=Bayern/L=Nuremberg/O=Suse/OU=QA/CN=localhost/emailAddress=admin\@localhost'"
          . " -keyout /etc/squid/squid.key -out /etc/squid/squid.cert ");
    # install certificate system-wide
    assert_script_run 'cp /etc/squid/squid.cert /usr/share/pki/trust/anchors ; update-ca-certificates';
    # configure squid as reverse proxy
    assert_script_run 'curl ' . data_url('squid/squid_reverse.conf') . ' -o /etc/squid/squid.conf';
    systemctl('restart squid', timeout => 600);
    systemctl 'status squid';
    # ensure squid is ready to serve requests before proceeding
    script_retry 'lsof -i :3128 | grep squid', delay => 30, retry => 3, timeout => 600;
}

sub run {
    select_serial_terminal;
    configure_apache;
    configure_squid;
    # use squid as https reverse proxy to access content served by apache.
    # Ensure reply contains certificate info, HTTP 200 and test page content
    # note we redirect stderr to stdout, because some info from --verbose are on stderr
    validate_script_output 'curl --proxy-insecure --no-styled-output --verbose --proxy https://localhost:8443 http://localhost:8080/hello.html 2>&1',
      sub { m/subject:.+O=Suse.+HTTP\/1.1 200 OK.+Hello/s };
}

sub post_fail_hook {
    upload_logs('/var/log/squid/access.log', log_name => 'squid_access.log');
    upload_logs('/var/log/squid/cache.log', log_name => 'squid_cache.log');
}


sub test_flags {
    return {always_rollback => 1};
}

1;
