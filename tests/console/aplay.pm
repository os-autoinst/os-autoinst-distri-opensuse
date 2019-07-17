# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test audio using aplay.
# - stop packagekit daemon and install alsa-utils and alsa, checks output
# for # "Installing:.*alsa" or "'alsa' is already installed"
# - clear console and check
# - change for user console
# - run set_default_volume -f
# - run alsamixer 0
# - send key "ESC"
# - clear console
# - run aplay ~/data/1d5d9dD.wav
# - run check_recorded_sound 'DTMF-159D', otherwise, softfail test (bsc#1048271)
# Maintainer: Rodion Iafarov <aplanas@suse.com>

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils 'ensure_serialdev_permissions';

sub run {
    my $self = shift;
    select_console 'root-console';
    ensure_serialdev_permissions;

    my $script = <<EOS;

# minimal has no packagekit so we need to ignore the error
systemctl stop packagekit.service || :
echo -e "\n\n\n"
zypper -n in alsa-utils alsa
EOS

    validate_script_output $script, sub { m/Installing:.*alsa/ || m/'alsa' is already installed/ }, 120;

    $self->clear_and_verify_console;
    select_console 'user-console';

    assert_script_run('set_default_volume -f');

    script_run('alsamixer', 0);
    assert_screen 'test-aplay-2', 3;
    send_key "esc";
    $self->clear_and_verify_console;

    start_audiocapture;
    assert_script_run("aplay ~/data/1d5d9dD.wav");
    # aplay is extremely unstable due to bsc#1048271, we don't want to invest
    # time in rerunning it, if it fails, so instead of assert, simply soft-fail
    unless (check_recorded_sound 'DTMF-159D') {
        record_soft_failure 'bsc#1048271';
    }
}

1;
