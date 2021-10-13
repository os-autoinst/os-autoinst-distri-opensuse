# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test IMA kernel command line for IMA hash
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#48932

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings);
use power_action_utils "power_action";
use version_utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $meas_file = "/sys/kernel/security/ima/ascii_runtime_measurements";

    my @algo_list = (
        {algo => "md5", len => 32},
        {algo => "sha1", len => 40},
        {algo => "sha256", len => 64},
        {algo => "sha512", len => 128},
        {algo => "rmd160", len => 40},
        {algo => "wp512", len => 128},
        {algo => "tgr192", len => 48},
    );

    # Add kernel modules to enable some algorithms
    my $algo_modlist = "rmd160 wp512 tgr192";
    $algo_modlist .= " sha512" if (!is_sle && !is_leap);

    assert_script_run "echo -e $algo_modlist | sed 's/ /\\n/g' > /etc/modules-load.d/hash.conf";
    assert_script_run "echo 'force_drivers+=\"$algo_modlist\"' >/etc/dracut.conf.d/10.hashs.conf";
    assert_script_run "dracut -f";

    add_grub_cmdline_settings('ima_policy=tcb ima_hash=none');
    my $last_algo = "none";

    for my $i (@algo_list) {
        replace_grub_cmdline_settings("ima_hash=$last_algo", "ima_hash=@$i{algo}", update_grub => 1);
        $last_algo = @$i{algo};

        # Grep and output grub settings to the terminal for debugging
        assert_script_run("grep GRUB_CMDLINE_LINUX /etc/default/grub");

        # Reboot to make settings work
        power_action('reboot', textmode => 1);
        $self->wait_boot;
        $self->select_serial_terminal;

        my $meas_tmpfile = "/tmp/ascii_runtime_measurements-" . @$i{algo};
        assert_script_run("cp $meas_file $meas_tmpfile");
        upload_logs "$meas_tmpfile";

        my $out = script_output("grep '^10\\s*[a-fA-F0-9]\\{40\\}\\s*ima-ng\\s*@$i{algo}:[a-fA-F0-9]\\{@$i{len}\\}\\s*\\/' $meas_file |wc -l");
        die('Too few items') if ($out < 100);
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
