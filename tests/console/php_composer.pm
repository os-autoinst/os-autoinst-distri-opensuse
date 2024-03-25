# SUSE's openQA tests
#
# Copyright 2023-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: php-composer2
# Summary: Test php-composer2
# - Install PHP
# - Download Composer and install it
# - Install and verify the package to use it in a PHP script
# - Run a PHP script and verify it
# Maintainer: QE-Core <qe-core@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_leap is_sle php_version);

sub run {
    select_serial_terminal;

    my ($php, $php_pkg, $php_ver) = php_version();
    zypper_call("in $php_pkg php$php_ver-curl php$php_ver-phar php-composer2");
    # system's php composer2
    my $php_compose2_ver = script_output("rpm -q php-composer2 | awk -F \'-\' \'{print \$3}\'");

    # Download and install the php composer
    # https://getcomposer.org/download/2.2.3/composer.phar
    assert_script_run("curl -sS https://getcomposer.org/installer -o composer-setup.php");
    assert_script_run("php8 composer-setup.php --version=$php_compose2_ver --install-dir=/usr/local/bin --filename=composer2", timeout => 180);
    my $composer2_ver = script_output("composer2  | awk '/Composer version/  {print $3}'");
    if ($composer2_ver =~ $php_compose2_ver) {
        record_info('php_composer2 --version:' . $composer2_ver, 'system composer2:' . $php_compose2_ver);
        # Create a new project folder
        assert_script_run("mkdir brickMath && cd brickMath");
        assert_script_run("composer2 require brick/math");
        validate_script_output('ls -l', sub { m/composer.json/ && m/composer.lock/ && m/vendor/ });
        validate_script_output('cat composer.json', sub { m/brick\/math/ });
        assert_script_run("pwd");
        # Run a PHP script brickmath.php uses the BigInteger class
        # from brick/math to get the sum of two numbers.
        assert_script_run("curl " . data_url("php/brickmath.php") . " -o /root/brickMath/brickmath.php ");
        validate_script_output('php brickmath.php', sub { m/912557/ });
    } else {
        die "Installed composer version doesnt match with system's composer2";
    }
}

sub post_fail_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_run_hook;
}

sub cleanup {
    assert_script_run("composer2 remove brick/math");
    my $out = script_output "cat composer.json", proceed_on_failure => 1;
    die("composer2 failed to remove brick/math package ") if ($out =~ "/brick\/math/");
    assert_script_run("cd /usr/local/bin  && rm -r composer2");
}
1;
