# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libgpiod
# Summary: Test libgpiod
# More information can be found on https://en.opensuse.org/openSUSE:GPIO
# Maintainer: Guillaume Gardet <guillaume@opensuse.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use version_utils qw(is_sle is_leap);

sub run {
    select_console 'root-console';

    # Install libgpiod tools
    zypper_call 'in libgpiod-utils';

    # Record libgpiod version
    record_info('Version', script_output('gpiodetect --version | head -n1'));

    # ARM qemu _may_ have already gpiochip0 [ARMH0061:00] (8 lines) for ACPI (depends on qemu version)
    my $gpiochipX = 'gpiochip0';
    if (script_run('gpioinfo | grep gpiochip0') == 0) {
        $gpiochipX = 'gpiochip1';
        # Some boards (RPi3/4) have 2 gpiochips already
        if (script_run('gpioinfo | grep gpiochip1') == 0) {
            $gpiochipX = 'gpiochip2';
        }
    }

    record_info('gpiochip', "$gpiochipX");

    my $version = get_var('VERSION', '');
    if (is_sle || is_leap('>15.2') || $version =~ /^Jump/) {
        record_info('kernel extra', 'boo#1176090 install kernel-default-extra');
        zypper_call 'in kernel-default-extra';
    }
    # Create a fake $gpiochipX, with 32 lines
    assert_script_run("modprobe gpio_mockup gpio_mockup_ranges=-1,32");
    # Check that $gpiochipX is found, with 32 lines
    validate_script_output "gpiodetect", sub { m/$gpiochipX \[gpio-mockup-A\] \(32 lines\)/ };
    # Record all gpioinfo
    record_info('gpioinfo', script_output('gpioinfo'));
    validate_script_output "gpioinfo -c $gpiochipX", sub { m/$gpiochipX - 32 lines/ };
    # Check gpio 31 is an unused input (default)
    validate_script_output "gpioinfo -c $gpiochipX | grep 31", sub { m/line  31:	unnamed         	input/ };
    # Set GPIO 31, as output, value 1, for 40 seconds
    assert_script_run("gpioset --daemonize -c $gpiochipX 31=1");
    # Check it is used by gpioset and set as output
    validate_script_output "gpioinfo -c $gpiochipX | grep 31", sub { m/line  31:	unnamed         	output consumer=gpioset/ };
    # Stop daemonized gpioset
    assert_script_run("pkill gpioset");
    # Now, the gpio should be released (but remains as output)
    validate_script_output "gpioinfo -c $gpiochipX | grep 31", sub { m/line  31:	unnamed         	output/ };
    # Read gpio 31 (set gpio as input)
    validate_script_output "gpioget -c $gpiochipX 31", sub { m/"31"=inactive/ };
    # Read gpio 31 again, with 'active low' option
    validate_script_output "gpioget -l -c $gpiochipX 31", sub { m/"31"=active/ };
    # Check gpio is an input again
    validate_script_output "gpioinfo -c $gpiochipX | grep 31", sub { m/line  31:	unnamed         	input/ };
    # Remove the fake $gpiochipX
    assert_script_run("modprobe -r gpio_mockup");
}

1;
