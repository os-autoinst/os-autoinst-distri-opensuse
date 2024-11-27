# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Framework to test other Desktop Environments
#    Non-Primary desktop environments are generally installed by means
#    of a pattern. For those tests, we assume a minimal-X based installation
#    where the pattern is being installed on top.
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "consoletest";
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    script_run("mkdir -p ~/.config/sway");
    script_run("cp /etc/sway/config ~/.config/sway/");
    zypper_call("in dmenu");
    assert_script_run(qq(sed -i "s/^set \$menu/set \$menu dmenu_path | dmenu -nb '#173f4f' -sb '#35b9ab' -nf '#73ba25' -sf '#173f4f' -fn 'Source Sans Pro-14' | xargs swaymsg exec --/" ~/.config/sway/config));
    script_run('echo -e "[Desktop]\\nSession=sway" > ~/.dmrc');
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    send_key("super-d");
    assert_screen 'sway-menu-bar';
}

1;
