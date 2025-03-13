# SUSE's Apache regression test
#
# Copyright 2019-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: apache2 apache2-mod_php72 php72-php72-curl
# Summary: Test various apche2 basic scenarios
#  * Test the default vhost after installation
#  * Test custom vhost domain, custom vhost port
#  * Test if http-prefork works correctly
#  * Test http basic authentication
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use version_utils qw(is_sle is_jeos has_selinux);

sub run {
    select_serial_terminal;

    # On SLES12-SP5 apache2 and apache2-tls13 are supported
    my $apache2 = get_var('APACHE2_PKG', "apache2");

    # installation of docs and manpages is excluded in zypp.conf
    # enable full package installation, and clean up previous apache2 deployment
    if (is_jeos) {
        assert_script_run('sed -ie \'s/rpm.install.excludedocs = yes/rpm.install.excludedocs = no/\' /etc/zypp/zypp.conf');
        zypper_call('rm apache2', exitcode => [0, 104]);
    }

    # Create index test file
    assert_script_run 'mkdir -p /srv/www/htdocs';
    assert_script_run 'echo "index" > /srv/www/htdocs/index.html';

    # Install and start apache
    zypper_call "in $apache2";
    zypper_call "in apache2-utils" if is_jeos;
    zypper_call "in policycoreutils-python-utils" if (is_jeos && has_selinux);
    systemctl 'enable apache2';    # Note: The systemd service is always apache2, not apache2-tls13.
    systemctl 'restart apache2';    # apache2 could be already running from previous test runs
    systemctl 'status apache2';

    # Check if apache is working when php module is enabled
    # LTSS module test does not have apache2-mod_php72 php72-curl
    # Install apache2-mod_php72 php72-curl for versions smaller than SLE12-SP5, as dependencies for enabling php7 on SLE15+ are fulfilled
    if (get_var('SCC_ADDONS') !~ /ltss/ && is_sle('<=12-SP5')) {
        zypper_call('in apache2-mod_php72 php72-curl');
    }

    # Following the reproducer of bug#1174667, the regression was detected when php7 module enabled and when stopping or reloading apache service
    assert_script_run('a2enmod php7');
    systemctl 'stop apache2';
    systemctl 'start apache2';
    systemctl 'reload apache2';
    systemctl 'status apache2';
    assert_script_run 'a2dismod php7';

    # In order to avoid future conflicts, apache2-mod_php72 php72-curl and their dependencies are removed
    if (get_var('SCC_ADDONS') !~ /ltss/ && is_sle('<=12-SP5')) {
        zypper_call('rm --clean-deps apache2-mod_php72 php72-curl');
    }

    # Check if the server works and serves the right content
    assert_script_run 'curl -v http://localhost/ | grep "index"';

    # Check if the permissions are set correctly
    assert_script_run 'ls -la /srv/www/htdocs | head -n2 | grep "drwxr\-xr\-x"';
    assert_script_run 'ls -la /srv/www/htdocs/index.html | grep "\-rw\-r\-\-r\-\-"';

    # Stop the server and check it's not listening nor running any more
    systemctl 'stop apache2';
    exit 0 if script_run('systemctl is-active apache2') == 0;
    exit 0 if script_run('curl -v http://localhost/') == 0;

    # Start apache again
    systemctl 'start apache2';
    assert_script_run 'curl -v http://[::1]/ | grep "index"';

    # Listen on 85 and create a vhost for it
    assert_script_run 'echo "Listen 85" >> /etc/apache2/listen.conf';
    assert_script_run 'cp /etc/apache2/vhosts.d/vhost.template /etc/apache2/vhosts.d/myvhost.conf';
    assert_script_run 'sed -i "s/<VirtualHost \\*:80>/<VirtualHost \\*:85>/g" /etc/apache2/vhosts.d/myvhost.conf';
    assert_script_run 'mkdir -p /srv/www/vhosts/dummy-host.example.com';
    assert_script_run 'touch /srv/www/vhosts/dummy-host.example.com/listed_test_file';

    # Change SELinux policy for port 85, poo#178240
    assert_script_run 'semanage port -a -t http_port_t -p tcp 85' if has_selinux;

    # Create separate vhost for 'localhost'
    assert_script_run 'cp /etc/apache2/vhosts.d/vhost.template /etc/apache2/vhosts.d/localhost.conf';
    assert_script_run 'sed -i "s/dummy-host.example.com/localhost/g" /etc/apache2/vhosts.d/localhost.conf';
    assert_script_run 'mkdir -p /srv/www/vhosts/localhost';
    assert_script_run 'echo "This is the local host" > /srv/www/vhosts/localhost/index.html';

    # Create separate vhost for 'foo.bar'
    assert_script_run 'cp /etc/apache2/vhosts.d/vhost.template /etc/apache2/vhosts.d/foo.bar.conf';
    assert_script_run 'sed -i "s/dummy-host.example.com/foo.bar/g" /etc/apache2/vhosts.d/foo.bar.conf';
    assert_script_run 'mkdir -p /srv/www/vhosts/foo.bar';
    assert_script_run 'echo "This is the foo host" > /srv/www/vhosts/foo.bar/index.html';
    assert_script_run 'echo "127.0.0.1 foo.bar" >> /etc/hosts';
    assert_script_run 'echo "::1 foo.bar" >> /etc/hosts';

    # Check the syntax and reload the server
    assert_script_run 'apachectl -t';
    systemctl 'reload apache2';

    # Check the 'localhost' vhost via IPv4 and IPv6
    assert_script_run 'curl -vH "Host: localhost" http://[::1]/ | grep "This is the local host"';
    assert_script_run 'curl -v http://localhost/ | grep "This is the local host"';

    # Check the 'foo.bar' vhost via IPv4 and IPv6
    assert_script_run 'curl -v4 http://foo.bar | grep "This is the foo host"';
    assert_script_run 'curl -v6 http://foo.bar/ | grep "This is the foo host"';

    # Works we have also special vhost listening on port 85 both IPv4 and IPv6
    assert_script_run 'curl -v http://localhost:85/ | grep "listed_test_file"';
    assert_script_run 'curl -v http://[::1]:85/ | grep "listed_test_file"';

    # We stop current webserver and prepare another http2-prefork environment
    systemctl 'stop apache2';

    if (is_sle('12-SP2+')) {
        if (check_var('SYSTEM_ROLE', 'kvm') || check_var('SYSTEM_ROLE', 'xen')) {
            record_info('prefork skipped', "The apache prefork tests were skipped due to SYSTEM_ROLE=kvm (see bsc#1156171).");
        }
        else {
            # Create directory for the new instance and prepare config
            my $apache2_default_configuration = is_sle('<15-SP6') ? "/usr/share/doc/packages/$apache2/httpd.conf.default" : "/usr/share/doc/packages/$apache2/conf/httpd.conf";
            assert_script_run 'mkdir -p /tmp/prefork';
            assert_script_run "sed 's_\(/var/log/apache2\|/var/run\)_/tmp/prefork_; s/80/8080/' $apache2_default_configuration > /tmp/prefork/httpd.conf";

            # httpd.default.conf contains wrong service userid and groupid
            assert_script_run q{sed -ie 's/^User daemon$/User wwwrun/' /tmp/prefork/httpd.conf};
            assert_script_run q{sed -ie 's/^Group daemon$/Group www/' /tmp/prefork/httpd.conf};

            # Run and test this new environment
            assert_script_run 'httpd-prefork -f /tmp/prefork/httpd.conf';
            assert_script_run 'until ps aux|grep wwwrun|grep -E httpd\(2\)?-prefork; do echo waiting for httpd-prefork pid; done';
            assert_script_run 'ps aux | grep "\-f /tmp/prefork/httpd.conf" | grep httpd-prefork';

            # Run and test the old environment too
            script_run 'rm /var/run/httpd.pid';
            systemctl 'start apache2';
            assert_script_run 'ps aux | grep "\-f /etc/apache2/httpd.conf" | grep httpd-prefork';

            # Test both instances
            assert_script_run 'curl -v http://localhost:80/';
            assert_script_run 'curl -v http://localhost:8080/';

            # Stop both instances
            # binary killall is not present in JeOS
            assert_script_run('kill -TERM $(ps aux| grep [h]ttpd-prefork| awk \'{print $2}\')');
            systemctl 'stop apache2';

            # Test everything is stopped properly
            assert_script_run '! curl -v http://localhost:80/';
            assert_script_run '! curl -v http://localhost:8080/';

            # Clean up
            assert_script_run 'rm -r /tmp/prefork';
        }
    }

    # Create a new directory with the index file
    assert_script_run 'mkdir /srv/www/vhosts/localhost/authtest';
    assert_script_run 'echo "HI, JOE" > /srv/www/vhosts/localhost/authtest/index.html';

    # Make this new directory password protected
    assert_script_run 'touch /srv/www/vhosts/localhost/authtest/.htpasswd';
    assert_script_run 'chmod 640 /srv/www/vhosts/localhost/authtest/.htpasswd';
    assert_script_run 'chown root:www /srv/www/vhosts/localhost/authtest/.htpasswd';
    assert_script_run 'htpasswd -s -b /srv/www/vhosts/localhost/authtest/.htpasswd joe secret';

    # Paste the .htaccess file
    assert_script_run('curl -o /srv/www/vhosts/localhost/authtest/.htaccess ' . data_url('console/apache_.htaccess'));

    # Paste the config file
    assert_script_run('curl -o /etc/apache2/conf.d/authtest.conf ' . data_url('console/apache_authtest.conf'));

    # Start the webserver and test the password access
    systemctl 'start apache2';
    assert_script_run 'curl -vI -u "joe:secret" "http://localhost/authtest/" | grep -A99 -B99 "HTTP/1.1 200 OK"';
    assert_script_run 'curl -v -u "joe:secret" "http://localhost/authtest/" | grep -A99 -B99 "HI, JOE"';

    # Stop the webserver for next testing
    systemctl 'stop apache2';

    # Revert zypp.conf changes on JeOS
    if (is_jeos) {
        assert_script_run('sed -ie \'s/rpm.install.excludedocs = no/rpm.install.excludedocs = yes/\' /etc/zypp/zypp.conf');
    }
}

1;

