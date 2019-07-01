# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test libgpiod
#  More information can be found on https://en.opensuse.org/openSUSE:GPIO
# Maintainer: Guillaume Gardet <guillaume@opensuse.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Install libgpiod tools
    zypper_call 'in libgpiod';

    # Record libgpiod version
    record_info('Version', script_output('gpiodetect --version | head -n1'));

    # ARM qemu has already gpiochip0 [ARMH0061:00] (8 lines) for ACPI
    my $gpiochipX = get_var('ARCH') =~ /aarch64/ ? 'gpiochip1' : 'gpiochip0';

    record_info('gpiochip', "$gpiochipX");

    # Create a fake $gpiochipX, with 32 lines
    assert_script_run("modprobe gpio_mockup gpio_mockup_ranges=-1,32");
    # Check that $gpiochipX is found, with 32 lines
    validate_script_output "gpiodetect", sub { m/$gpiochipX \[gpio-mockup-A\] \(32 lines\)/ };
    # Record all gpioinfo
    record_info('gpioinfo', script_output('gpioinfo'));
    validate_script_output "gpioinfo $gpiochipX", sub { m/$gpiochipX - 32 lines/ };
    # Check gpio 31 is an unused input (default)
    validate_script_output "gpioinfo $gpiochipX | grep 31", sub { m/line  31:      unnamed       unused   input  active-high/ };
    # Set GPIO 31, as output, value 1, for 40 seconds
    assert_script_run("gpioset --mode=time -s 45 -b $gpiochipX 31=1");
    # Check it is used by gpioset and set as output
    validate_script_output "gpioinfo $gpiochipX | grep 31", sub { m/line  31:      unnamed    "gpioset"  output  active-high \[used\]/ };
    sleep 45;
    # After 20 seconds, the gpio should be released (but may remain as output)
    validate_script_output "gpioinfo $gpiochipX | grep 31", sub { m/line  31:      unnamed       unused  output  active-high/ };
    # Read gpio 31 (set gpio as input)
    validate_script_output "gpioget $gpiochipX 31", sub { m/0/ };
    # Read gpio 31 again, with 'active low' option
    validate_script_output "gpioget -l $gpiochipX 31", sub { m/1/ };
    # Check gpio is an input again
    validate_script_output "gpioinfo $gpiochipX | grep 31", sub { m/line  31:      unnamed       unused   input  active-high/ };
    # Remove the fake $gpiochipX
    assert_script_run("modprobe -r gpio_mockup");
}

1;
