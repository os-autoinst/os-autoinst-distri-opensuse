# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>

use strict;
use warnings;
use base "consoletest";
use bootloader_setup;
use ipmi_backend_utils;
use testapi;
use utils;

use Mitigation;



sub run {
    my ($self) = shift;
    select_console 'root-console';
    assert_script_run("cat /sys/devices/system/cpu/vulnerabilities/spectre_v1 | grep \"Mitigation: usercopy/swapgs barriers and __user pointer sanitization\"");
    add_grub_cmdline_settings("nospectre_v1");
    update_grub_and_reboot($self, 150);
    assert_script_run("cat /sys/devices/system/cpu/vulnerabilities/spectre_v1 | grep \"Vulnerable: __user pointer sanitization and usercopy barriers only; no swapgs barriers\"");
    remove_grub_cmdline_settings("nospectre_v1");
}

sub update_grub_and_reboot {
    my ($self, $timeout) = @_;
    grub_mkconfig;
    Mitigation::reboot_and_wait($self, $timeout);
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('nospectre_v1');
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
