# SUSE's Apache tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package apachetest;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw(setup_apache2);

# Setup apache2 service in different mode: SSL, NSS, NSSFIPS
# Example: setup_apache2(mode => 'SSL');
sub setup_apache2 {
    my %args      = @_;
    my $mode      = uc $args{mode} || "";
    my $nsspasswd = "httptest";
    my @packages  = qw(apache2);

    if (($mode eq "NSS") && get_var("FIPS")) {
        $mode = "NSSFIPS";
    }
    if ($mode =~ m/NSS/) {
        push @packages, qw(apache2-mod_nss mozilla-nss-tools);
    }

    # Make sure the packages are installed
    assert_script_run "zypper -n in @packages", 300;

    # Enable the ssl
    if ($mode eq "SSL") {
        assert_script_run 'a2enmod ssl';
    }
    elsif ($mode =~ m/NSS/) {
        # mod_nss is conflict with mod_ssl
        assert_script_run 'a2dismod ssl';
        assert_script_run 'a2enmod nss';
    }
    if ($mode =~ m/SSL|NSS/) {
        assert_script_run "sed -i '/^APACHE_SERVER_FLAGS=/s/^/#/' /etc/sysconfig/apache2";
        assert_script_run 'echo APACHE_SERVER_FLAGS="SSL" >> /etc/sysconfig/apache2';
    }

    # Create x509 certificate for this apache server
    if ($mode eq "SSL") {
        assert_script_run 'gensslcert -n $(hostname) -C $(hostname) -e webmaster@$(hostname)', 600;
        assert_script_run 'ls /etc/apache2/ssl.crt/$(hostname)-server.crt /etc/apache2/ssl.key/$(hostname)-server.key';
    }

    # Check server certificate is available, which should be generated during apache2-mod_nss installation
    if ($mode =~ m/NSS/) {
        assert_script_run 'certutil -d /etc/apache2/mod_nss.d/ -L -n Server-Cert';
    }

    # Prepare vhost file
    script_run 'for x in /etc/apache2/vhosts.d/*.conf; do mv $x ${x}.save; done';
    if ($mode eq "SSL") {
        my $file = '/etc/apache2/vhosts.d/vhost-ssl.conf';
        assert_script_run "cp /etc/apache2/vhosts.d/vhost-ssl.template $file";
        assert_script_run
          'sed -i "s|\(^[[:space:]]*SSLCertificateFile\).*|\1 /etc/apache2/ssl.crt/$(hostname)-server.crt|g" ' . $file;
        assert_script_run
          'sed -i "s|\(^[[:space:]]*SSLCertificateKeyFile\).*|\1 /etc/apache2/ssl.key/$(hostname)-server.key|g" '
          . $file;
    }
    elsif ($mode =~ m/NSS/) {
        script_run
          'grep "^Include .*mod_nss.d" /etc/apache2/conf.d/mod_nss.conf && touch /etc/apache2/mod_nss.d/test.conf';
        assert_script_run 'cp /etc/apache2/vhosts.d/vhost-nss.template /etc/apache2/vhosts.d/vhost-nss.conf';
        if ($mode eq "NSSFIPS") {
            assert_script_run "sed -i '/NSSEngine/a NSSFips on' /etc/apache2/vhosts.d/vhost-nss.conf";
        }
    }
    else {
        assert_script_run 'cp /etc/apache2/vhosts.d/vhost.template /etc/apache2/vhosts.d/vhost.conf';
    }
    my $files = '/etc/apache2/vhosts.d/vhost*.conf';
    assert_script_run
'sed -i -e "/^[[:space:]]*ServerAdmin/s/^/#/g" -e "/^[[:space:]]*ServerName/s/^/#/g" -e "/^[[:space:]]*DocumentRoot/s/^/#/g" '
      . $files;
    assert_script_run
'sed -i "/^<VirtualHost/a ServerAdmin webmaster@$(hostname)\nServerName $(hostname)\nDocumentRoot /srv/www/htdocs/\n" '
      . $files;

    # Start apache service
    script_run 'systemctl stop apache2';
    if ($mode eq "NSS") {
        assert_script_run
"expect -c 'spawn systemctl start apache2; expect \"Enter SSL pass phrase for internal (NSS)\"; send \"$nsspasswd\\n\"; interact'";
    }
    elsif ($mode eq "NSSFIPS") {
        assert_script_run
"expect -c 'spawn systemctl start apache2; expect \"Enter SSL pass phrase for NSS FIPS 140-2 Certificate DB (NSS)\"; send \"$nsspasswd\\n\"; interact'";
    }
    else {
        assert_script_run 'systemctl start apache2';
    }
    assert_script_run 'systemctl is-active apache2';

    # Create a test html page
    assert_script_run 'echo "<html><h2>Hello Linux</h2></html>" > /srv/www/htdocs/hello.html';

    # Verify apache+ssl works
    if ($mode =~ m/SSL|NSS/) {
        validate_script_output 'curl -k https://localhost/hello.html', sub { m/Hello Linux/ };
    }
    else {
        validate_script_output 'curl http://localhost/hello.html', sub { m/Hello Linux/ };
    }
}

1;

# vim: sw=4 et
