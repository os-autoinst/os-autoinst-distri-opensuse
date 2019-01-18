# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run steamcmd to bootstrap a game server
#   see https://developer.valvesoftware.com/wiki/SteamCMD for reference,
#   https://developer.valvesoftware.com/wiki/Dedicated_Servers_List#Linux_Dedicated_Servers
#   for a list of dedicated lists on Linux
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('in --auto-agree-with-licenses steamcmd');
    # see https://github.com/ValveSoftware/steam-for-linux/issues/4341
    my $allow_exit_codes = [qw(0 6 7 8)];
    # /usr/bin/steamcmd currently does not forward arguments, see
    # https://build.opensuse.org/request/show/592657
    my $ret = script_run '/usr/lib/steamcmd/steamcmd.sh +login anonymous +app_update 90 validate +quit', 1200;
    die "'steamcmd' failed with exit code $ret" unless (grep { $_ == $ret } @$allow_exit_codes);
    assert_script_run 'test -f Steam/steamapps/common/Half-Life/hlds_run';
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs "/home/bernhard/Steam/logs/stderr.txt";
}

1;
