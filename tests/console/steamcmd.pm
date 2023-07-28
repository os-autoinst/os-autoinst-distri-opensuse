# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: steamcmd
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
    my $ret = script_run '/usr/bin/steamcmd +login anonymous +app_update 90 validate +quit', 1200;
    if ($ret == 8) {
        # Steam bug: HL needs multiple download attempts:
        # https://developer.valvesoftware.com/wiki/SteamCMD#Downloading_an_app
        $ret = script_run '/usr/bin/steamcmd +login anonymous +app_update 90 validate +quit', 1200;
    }
    if ($ret == 139) {
        record_soft_failure("boo#1212977 steamcmd segfaults");
        return 1;
    }
    die "'steamcmd' failed with exit code $ret" unless (grep { $_ == $ret } @$allow_exit_codes);
    assert_script_run 'test -f Steam/steamapps/common/Half-Life/hlds_run';
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs "/home/bernhard/Steam/logs/stderr.txt";
}

1;
