# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test common commands: modinfo, lsmod, modprobe, rmmod,
# depmod. Tests the commands and their output for common words.
# Module used for testing: ip_set.
# * modinfo: 'filename ... .ko', 'license: ...', 'depends: ...'
# * lsmod: 'Module', 'Size', 'Used by'
# * modprobe: We make sure ip_set module is not active and then we activate it
# * rmmod: We check the exit status and then we enable the disabled module again
# * depmod: 'lib/modules', '.ko', 'kernel'.
# Maintainer: Vasilios Anastasiadis <vasilios.anastasiadis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Test modinfo command
    assert_script_run("OUT=\"\$(modinfo ip_set)\"");
    # Test the output for common words that should always appear
    assert_script_run('grep -o -m 1 \'^filename:.*.ko\' <<< "$OUT"');
    assert_script_run('grep -o -m 1 \'^license:.*GPL\' <<< "$OUT"');
    assert_script_run('grep -o -m 1 \'^depends:.*\' <<< "$OUT"');

    # Test lsmod command
    # Test that the output has the expected correct format
    assert_script_run('lsmod | grep \'^Module.*Size.*Used by$\'');

    # Test modprobe -v command
    my $status = script_run("rmmod ip_set");
    assert_script_run("modprobe -v --allow-unsupported-modules ip_set");

    # Test rmmod command
    assert_script_run("rmmod ip_set");
    # Make sure the command terminated the module by starting it again
    assert_script_run("modprobe -v --allow-unsupported-modules ip_set");
    # Remove the tested module if it was not loaded in the first place
    if ($status != 0) {
        script_run("rmmod ip_set");
    }

    # Test depmod command
    assert_script_run('OUT="$(depmod -av)"');
    # Test the output for common words that should always appear
    assert_script_run('grep -o -m 1 .ko <<< "$OUT"');
    assert_script_run('grep -o -m 1 lib/modules <<< "$OUT"');
    assert_script_run('grep -o -m 1 kernel <<< "$OUT"');
}

1;
