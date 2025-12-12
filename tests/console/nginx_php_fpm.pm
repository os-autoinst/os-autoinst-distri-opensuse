# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nginx php8-fpm
# Summary: Install and configure nginx FastCGI and PHP-FPM
# Verify the nginx server is working with php-fmp.service
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_leap php_version);
use registration qw(add_suseconnect_product get_addon_fullname);
use services::nginx;

sub run {
    select_serial_terminal;
    my ($php, $php_pkg, $php_ver) = php_version();

    if (is_sle(">=16.0")) {
        if (check_var('BETA', '1')) {
            my $VERSION = get_required_var('VERSION');
            my $ARCH = get_required_var('ARCH');
            zypper_call("--no-gpg-checks ar -f http://updates.suse.de/SUSE/Backports/SLE-${VERSION}_${ARCH}/standard/ 'Backport_${VERSION}'");
            zypper_call("--gpg-auto-import-keys ref", 300);
        }
        else {
            add_suseconnect_product("PackageHub", undef, undef, undef, 300, 1);
        }
    }

    services::nginx::install_service();
    services::nginx::enable_service();
    services::nginx::start_service();

    zypper_call("in $php_pkg $php_pkg-fpm $php_pkg-pear");
    systemctl("enable --now php-fpm");

    # Configure php_fpm
    my $php_fpm_configuration_file = "/etc/$php_pkg/fpm/php-fpm.d/www.conf";
    my $conf = <<EOF;
[www]
user = wwwrun
group = www
listen = 127.0.0.1:9000
listen.owner = wwwrun
listen.group = www
listen.mode = 0660
EOF
    script_output("echo '$conf' >> $php_fpm_configuration_file");

    # Create nginx Config for PHP-FPM
    my $nginx_config_file = '/etc/nginx/nginx.conf';

    assert_script_run("curl " . data_url("php/nginx_fcgid.conf") . " -o $nginx_config_file");

    # create a php test file test.php
    my $php_test_file = '/srv/www/htdocs/test.php';
    $conf = <<EOF;
<?php 
echo "PHP is working!";
?> 
EOF
    script_output("echo '$conf' >> $php_test_file");
    validate_script_output("nginx -t", sub { m/syntax is ok\n.*test is successful/ });
    validate_script_output("php-fpm --test", sub { m/test is successful/ });

    # Add appArmor allow rule /srv/www/htdocs/* r, to the php-fpm profile
    # and reload the profile
    if (is_sle("=15-sp7")) {
        my $rule = "/srv/www/htdocs/* r,";
        assert_script_run("sed -i  \'s/^}/   \/srv\/www\/htdocs\/*  r,\n}/\' /etc/apparmor.d/php-fpm");
        assert_script_run("apparmor_parser -r /etc/apparmor.d/php-fpm");
    }

    # Check and remove /var/log/php-fpm.log to avoid failed to open
    # error_log (/var/log/php-fpm.log): Permission denied error
    if (script_run("test -e /var/log/php-fpm.log") == 0) {
        script_run("rm -vf /var/log/php-fpm.log");
    }

    # assert_script_run("usermod -a -G www nginx");

    # Start php-fpm and nginx service
    systemctl("restart php-fpm nginx");

    # validate_script_output("ls -l /run/php-fpm", sub { m/php-fpm.sock/ });

    my $php_version = script_output("rpm -q $php_pkg --qf '%{VERSION}'");
    record_info("PHP ver:", $php_version);
    # Verify test.php
    validate_script_output("wget -4 -qO - http://localhost/test.php", sub { m/PHP is working!/ });
    cleanup();
}

sub post_fail_hook {
    script_run("journalctl -o short-precise > /tmp/journal.log");
    upload_logs("/tmp/journal.log", failok => 1);
    upload_logs("/var/log/messages", failok => 1);
    upload_logs("/var/log/nginx/access.log", failok => 1);
    upload_logs("/var/log/nginx/error.log", failok => 1);
    cleanup();
}

sub cleanup {
    my ($php, $php_pkg, $php_ver) = php_version();
    zypper_call("rm nginx $php_pkg $php_pkg-fpm $php_pkg-pear");
    script_run("rm -f /srv/www/htdocs/test.php");
}
1;
