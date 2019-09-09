# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test common commands: modinfo, lsmod, modprobe, rmmod,
# depmod. Tests the commands and their output for common words that
# should appear independently of the individual modules loaded in
# each system.
# * modinfo: 'filename ... .ko', 'license ... GPL', 'author ... Qumranet'
# * lsmod: 'Module', 'Size', 'Used by'
# * modprobe: We make sure arc4 module is not active and then we activate it
# * rmmod: We check the exit status and then we enable the disabled module again
# * depmod: 'lib/modules', '.ko', 'kernel'.
# Maintainer: Vasilios Anastasiadis <vasilios.anastasiadis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';

    #test modinfo command
    assert_script_run('OUT="$(modinfo kvm)"');
    #test the output for common words that should always appear
    assert_script_run('grep -o -m 1 \'^filename:.*kvm.ko\' <<< "$OUT"');
    assert_script_run('grep -o -m 1 \'^license:.*GPL\' <<< "$OUT"');
    assert_script_run('grep -o -m 1 \'^author:.*Qumranet\' <<< "$OUT"');
    assert_script_run('grep -o -m 1 \'^parm:.*ignore_msrs:bool\' <<< "$OUT"');

    #test lsmod command
    #test that the output has the expected correct format
    assert_script_run('lsmod | grep \'^Module.*Size.*Used by$\'');

    #test modprobe -v arc4 command
    script_run('rmmod arc4');
    assert_script_run('modprobe -v arc4 | grep \'^insmod.*arc4.ko\'');

    #test rmmod arc4 command
    assert_script_run('rmmod arc4');
    #make sure the command terminated the module by starting it again
    assert_script_run('modprobe -v arc4 | grep \'^insmod.*arc4.ko\'');

    #test depmod
    assert_script_run('OUT="$(depmod -av)"');
    #test the output for common words that should always appear
    assert_script_run('grep -o -m 1 .ko <<< "$OUT"');
    assert_script_run('grep -o -m 1 lib/modules <<< "$OUT"');
    assert_script_run('grep -o -m 1 kernel <<< "$OUT"');
}

1;
