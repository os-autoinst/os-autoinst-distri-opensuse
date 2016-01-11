# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

sub run() {
    my $self = shift;
    become_root;

    my $script = <<EOS;

# minimal has no packagekit so we need to ignore the error
systemctl stop packagekit.service || :
echo -e "\n\n\n"
zypper -n in alsa-utils alsa
EOS

    validate_script_output $script, sub { m/Installing:.*alsa/ || m/'alsa' is already installed/ }, 120;

    $self->clear_and_verify_console;
    script_run('exit');

    assert_script_run('set_default_volume -f');

    script_run('alsamixer');
    assert_screen 'test-aplay-2', 3;
    send_key "esc";
    $self->clear_and_verify_console;

    start_audiocapture;
    assert_script_run("aplay ~/data/1d5d9dD.wav");
    assert_recorded_sound('DTMF-159D');
}

1;
# vim: set sw=4 et:
