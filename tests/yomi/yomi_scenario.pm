# Yomi's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run a scenario passed via the TEST variable
# Maintainer: Alberto Planas <aplanas@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

my %SCENARIOS = (
    simple => {
        efi             => 'False',
        partition       => "\\'msdos\\'",
        device_type     => "\\'sd\\'",
        root_filesystem => "\\'ext2\\'",
        home_filesystem => 'False',
        snapper         => 'False',
        swap            => 'False',
        mode            => "\\'single\\'",
    },
    'microos-efi' => {
        efi             => 'True',
        partition       => "\\'gpt\\'",
        device_type     => "\\'sd\\'",
        root_filesystem => "\\'btrfs\\'",
        home_filesystem => 'False',
        snapper         => 'True',
        swap            => 'False',
        mode            => "\\'microos\\'",
    },
);

sub assert_script_run_qemu {
    my ($command) = @_;
    assert_script_run "ssh -oStrictHostKeyChecking=no -p 10022 localhost '$command'";
}

sub get_from_qemu {
    my ($file_path) = @_;
    assert_script_run "scp -oStrictHostKeyChecking=no -P 10022 localhost:$file_path .";
}

sub set_pillar_var {
    my ($key, $value) = @_;
    my $sls = '/usr/share/yomi/pillar/installer.sls';
    assert_script_run "sed -i \$'s/{% set $key = .* %}/{% set $key = $value %}/' $sls";
}

sub set_pillar_config_var {
    my ($key, $value) = @_;
    my $sls = '/usr/share/yomi/pillar/installer.sls';
    assert_script_run "sed -i \$'s/  $key: .*/  $key: $value/' $sls";
}

sub configure_scenario {
    my ($scenario) = @_;

    for my $key (keys %{$SCENARIOS{$scenario}}) {
        set_pillar_var $key, $SCENARIOS{$scenario}{$key};
    }

    # Disable reboot, so we can recover the logs later
    set_pillar_config_var('reboot', 'no');

    # Enable console mode
    set_pillar_config_var('grub2_console', 'yes');

    assert_script_run "head -n 40 /usr/share/yomi/pillar/installer.sls";
}

sub run {
    select_console 'root-console';

    # Get the name of the scenario from the test name
    my $scenario = get_var('TEST', 'simple');
    if (!exists $SCENARIOS{$scenario}) {
        die "scenario $scenario is not a valid one";
    }

    configure_scenario $scenario;

    # Install the operating system in the inner QEMU
    type_string "salt -l debug minion state.highstate |& tee -i salt /dev/$serialdev\n";
    wait_serial('Total states run:', 1200);

    # Get the assets and upload then before any assert that can kill
    # the test
    upload_asset 'salt';
    upload_asset '/var/log/salt/master';
    get_from_qemu '/var/log/salt/minion';
    upload_asset 'minion';

    # Validate that there are not errors in the salt output
    assert_script_run "grep 'Failed:[[:space:]]*0' salt";

    # Register that in the logs we do not have errors
    my $errors_in_log = script_run "grep '][ERROR[[:space:]]*]' salt minion";
    if (!$errors_in_log) {
        record_info('Non-related errors in logs',
            "The scenario $scenario have errors in the logs",
            result => 'softfail');
    }

    # Reboot the inner QEMU to validate the boot loader
    assert_script_run_qemu 'systemctl reboot';
    wait_serial('Booting from Hard Disk...', 60)   || die 'not booting from the correct media';
    wait_serial('localhost login:',          1200) || die 'login not found, QEMU not launched';
}

1;
