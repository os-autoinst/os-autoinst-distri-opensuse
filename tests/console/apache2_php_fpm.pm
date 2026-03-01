# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: apache2_mod_fcgid php8-fpm
# Summary: Install and configure Apache FastCGI and PHP-FPM
# Verify the Apache server is working with php-fmp.service
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_leap php_version);
use registration qw(add_suseconnect_product get_addon_fullname is_phub_ready);

sub run {
    select_serial_terminal;
    return if (!is_phub_ready() && is_sle('>=16.0'));

    my ($php, $php_pkg, $php_ver) = php_version();
    record_info("PHP version", $php_pkg);

    # Package 'apache2-mod_fcgid' requires PackageHub is available
    add_suseconnect_product(get_addon_fullname('phub')) if (is_phub_ready() && is_sle('>=16.0'));
    zypper_call("in $php_pkg apache2-mod_$php_pkg");
    # Disable apache2-mod_php8
    assert_script_run "a2dismod $php_pkg";
    # Install and enable apache2-mod_fcgid and php8-fpm
    zypper_call("in apache2-mod_fcgid $php_pkg-fpm $php_pkg-pear");
    assert_script_run 'a2enmod proxy';
    assert_script_run 'a2enmod proxy_fcgi';
    assert_script_run 'a2enmod setenvif';
    assert_script_run 'a2enmod fcgid';

    # Edit Apache FastCGI configuration
    my $mod_fcgi_conf_file = '/etc/apache2/conf.d/mod_fcgid.conf';
    assert_script_run("curl " . data_url("php/mod_fcgid.conf") . " -o $mod_fcgi_conf_file");
    systemctl("restart apache2");

    # Configure php_fpm
    my $php_fpm_configuration_file = "/etc/$php_pkg/fpm/php-fpm.d/www.conf";
    my $conf = <<EOF;
[www]
user = wwwrun
group = www
listen = /run/php-fpm/php-fpm.sock
listen.owner = wwwrun
listen.group = www
listen.mode = 0660
EOF
    script_output("echo '$conf' >> $php_fpm_configuration_file");

    # Create Apache Config for PHP-FPM
    my $apache_config_file = '/etc/apache2/conf.d/php-fpm.conf';
    $conf = <<EOF;
<FilesMatch \\.php\$>
  SetHandler \"proxy:unix:/run/php-fpm/php-fpm.sock|fcgi://localhost\"
</FilesMatch>
EOF
    script_output("echo '$conf' >> $apache_config_file");

    # create a php test file test.php
    my $php_test_file = '/srv/www/htdocs/test.php';
    $conf = <<EOF;
<?php phpinfo(); ?> 
EOF
    script_output("echo '$conf' >> $php_test_file");
    # Start php-fpm and apache2 service
    systemctl("restart php-fpm");

    # Add appArmor allow rule /srv/www/htdocs/* r, to the php-fpm profile
    # and reload the profile
    if (is_sle("=15-sp7")) {
        my $rule = "/srv/www/htdocs/* r,";
        assert_script_run('sed -i  \'s/^}/   \/srv\/www\/htdocs\/*  r,\n}/\' /etc/apparmor.d/php-fpm');
        assert_script_run("apparmor_parser -r /etc/apparmor.d/php-fpm");
    }

    validate_script_output("ls -l /run/php-fpm", sub { m/php-fpm.sock/ });
    systemctl("restart apache2");

    my $php_version = script_output("rpm -q $php_pkg --qf '%{VERSION}'");
    record_info("PHP version", $php_version);
    # Verify the test.php
    validate_script_output("wget -qO- http://localhost/test.php", sub { m/PHP Version $php_version/ });
    cleanup();
}

sub post_fail_hook {
    cleanup();
}

sub cleanup {
    my ($php, $php_pkg, $php_ver) = php_version();
    zypper_call("rm $php_pkg apache2-mod_$php_pkg apache2-mod_fcgid");
    script_run("rm -f /srv/www/htdocs/test.php /etc/apache2/conf.d/php-fpm.conf /etc/apache2/conf.d/mod_fcgid.conf");
    # Disable PHP-FPM configuration
    assert_script_run 'a2dismod proxy_fcgi';
}
1;
