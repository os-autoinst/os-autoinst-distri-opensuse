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

sub run {
    select_serial_terminal;
    my ($php, $php_pkg, $php_ver) = php_version();

    if (is_sle(">=16.0")) {
        if (check_var('BETA', '1')) {
            my $VERSION = get_required_var('VERSION');
            my $ARCH = get_required_var('ARCH');
            my $repo_added = script_output(qq(zypper lr|awk '/Backport_${VERSION}/ {print \$5}'));
            if ($repo_added eq "") {
                zypper_call("--no-gpg-checks ar -f http://updates.suse.de/SUSE/Backports/SLE-${VERSION}_${ARCH}/standard/ 'Backport_${VERSION}'");
                zypper_call("--gpg-auto-import-keys ref", 300);
            }
        }
        else {
            add_suseconnect_product("PackageHub", undef, undef, undef, 300, 1);
        }
    }

    zypper_call("-v in nginx $php_pkg $php_pkg-fpm $php_pkg-pear");
    systemctl("enable --now nginx php-fpm");

    # Read pre-configured www.conf config file from data directory and overwrite running
    # system's config file
    assert_script_run("curl " . data_url("php/www.conf") . " -o /etc/$php_pkg/fpm/php-fpm.d/www.conf");

    # Read pre-configured nginx config file from data directory and overwrite running
    # system's nginx config file
    assert_script_run("curl " . data_url("php/php-www.conf") . " -o /etc/nginx/vhosts.d/nginx_fpm_vhost.conf");

    # Read php code file file from data directory store it in /srv/www/htdocs/
    assert_script_run("curl " . data_url("php/test.php") . " -o /srv/www/htdocs/test.php");

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

    assert_script_run("chown -R wwwrun:www /srv/www/htdocs");
    assert_script_run("usermod -a -G wwwrun,www nginx");
    assert_script_run("setsebool httpd_can_network_connect on");

    # Start php-fpm and nginx service
    systemctl("restart php-fpm nginx");
    systemctl("reload php-fpm nginx");

    validate_script_output("ls -l /run/php-fpm", sub { m/php-fpm.sock/ });

    # Verify test.php
    validate_script_output("wget -qO - http://localhost/test.php", sub { m/PHP is working!/ });
    cleanup();
}

sub post_fail_hook {
    cleanup();
}

sub cleanup {
    my ($php, $php_pkg, $php_ver) = php_version();
    zypper_call("rm nginx $php_pkg $php_pkg-fpm $php_pkg-pear");
    script_run("rm -f /srv/www/htdocs/test.php");
}
1;
