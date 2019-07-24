# SUSE's Apache regression test
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test various apche2 basic scenarios
#  * Test the default vhost after installation
#  * Test custom vhost domain, custom vhost port
#  * Test if http-prefork works correctly
#  * Test http basic authentication
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils qw(is_sle is_jeos);

sub run {
    select_console 'root-console';

    # Even before the installation there should be htdocs so we can create the index
    assert_script_run 'echo "index" > /srv/www/htdocs/index.html';

    # Ensure apache is installed and stopped
    if (script_run('rpm -qa | grep apache2') == 0) {
        systemctl('stop apache2');
    } elsif (is_jeos) {
        # installation of docs and manpages is excluded in zypp.conf
        zypper_call 'in --download-only apache2';
        assert_script_run('cd /var/cache/zypp/packages/SUSE_Linux_*/' . get_required_var('ARCH'));
        assert_script_run('rpm -Uvh --includedocs ./*');
    } else {
        zypper_call 'in apache2';
    }

    # Check if the unit is enabled (and if not, enable it), started (and if not, start it) and display its status
    systemctl 'enable apache2';
    systemctl 'start apache2';
    systemctl 'status apache2';

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
        # Create directory for the new instance and prepare config
        assert_script_run 'mkdir -p /tmp/prefork';
        assert_script_run 'sed "s_\(/var/log/apache2\|/var/run\)_/tmp/prefork_; s/80/8080/" /usr/share/doc/packages/apache2/httpd.conf.default > /tmp/prefork/httpd.conf';

        # Run and test this new environment
        assert_script_run 'httpd2-prefork -f /tmp/prefork/httpd.conf';
        assert_script_run 'ps aux | grep "\-f /tmp/prefork/httpd.conf" | grep httpd2-prefork';

        # Run and test the old environment too
        assert_script_run 'rm /var/run/httpd.pid';
        systemctl 'start apache2';
        assert_script_run 'ps aux | grep "\-f /etc/apache2/httpd.conf" | grep httpd-prefork';

        # Test both instances
        assert_script_run 'curl -v http://localhost:80/';
        assert_script_run 'curl -v http://localhost:8080/';

        # Stop both instances
        # binary killall is not present in JeOS
        assert_script_run('kill -TERM $(ps aux| grep [h]ttpd2-prefork| awk \'{print $2}\')');
        systemctl 'stop apache2';

        # Test everything is stopped properly
        assert_script_run '! curl -v http://localhost:80/';
        assert_script_run '! curl -v http://localhost:8080/';

        # Clean up
        assert_script_run 'rm -r /tmp/prefork';
    }

    # Create a new directory with the index file
    assert_script_run 'mkdir /srv/www/vhosts/localhost/authtest';
    assert_script_run 'echo "HI, JOE" > /srv/www/vhosts/localhost/authtest/index.html';

    # Make this new directory password protected
    assert_script_run 'touch /srv/www/vhosts/localhost/authtest/.htpasswd';
    assert_script_run 'chmod 640 /srv/www/vhosts/localhost/authtest/.htpasswd';
    assert_script_run 'chown root:www /srv/www/vhosts/localhost/authtest/.htpasswd';
    assert_script_run 'htpasswd2 -s -b /srv/www/vhosts/localhost/authtest/.htpasswd joe secret';

    # Paste the .htaccess file
    assert_script_run "echo 'AuthType Basic
    AuthName \"only joe must get in!\"
    AuthUserFile /srv/www/vhosts/localhost/authtest/.htpasswd
    Require valid-user' > /srv/www/vhosts/localhost/authtest/.htaccess";

    # Paste the config file
    assert_script_run "echo '<Directory \"/srv/www/vhosts/localhost/authtest\">
    AllowOverride AuthConfig
    </Directory>' > /etc/apache2/conf.d/authtest.conf";

    # Start the webserver and test the password access
    systemctl 'start apache2';
    assert_script_run 'curl -vI -u "joe:secret" "http://localhost/authtest/" | grep -A99 -B99 "HTTP/1.1 200 OK"';
    assert_script_run 'curl -v -u "joe:secret" "http://localhost/authtest/" | grep -A99 -B99 "HI, JOE"';

    # Stop the webserver for next testing
    systemctl 'stop apache2';
}

1;

