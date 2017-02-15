# SUSE's openQA tests
#
# Copyright (c) 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: snapper without DBus service running tests / POO#15944 FATE#321049
# Maintainer: Michal Nowak <mnowak@suse.com>

use strict;
use base "consoletest";
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    my @snapper_runs = 'snapper';
    push @snapper_runs, 'snapper --no-dbus' if get_var('SNAPPER_NODBUS');

    foreach my $snapper (@snapper_runs) {
        service_action('dbus', {type => ['socket', 'service'], action => ['stop', 'mask']}) if ($snapper =~ /dbus/);
        my @snapper_cmd = "$snapper create";
        my @snap_numbers;
        foreach my $type ('single', 'command', 'pre', 'post') {
            my $type_arg = "--type $type";
            $type_arg = "--command \"$snapper list | tail -n1\"" if ($type eq 'command');
            push @snapper_cmd, $type_arg;
            foreach my $cleanup_algorithm ('number', 'timeline', 'empty-pre-post') {
                push @snapper_cmd, '--pre-number ' . pop @snap_numbers if ($type eq 'post');
                push @snapper_cmd, "--cleanup-algorithm $cleanup_algorithm";
                my $description = "type=$type,cleanup_algorithm=$cleanup_algorithm";
                push @snapper_cmd, "--print-number --description \"$description\"";
                push @snapper_cmd, "--userdata \"$description\"";
                assert_script_run(join ' ', @snapper_cmd);
                assert_script_run("$snapper list | tail -n1");
                for (1 .. 3) { pop @snapper_cmd; }
                if ($type eq 'pre') {
                    type_string("( $snapper list | tail -n1 | awk \'{ print \$3 }\'; echo snapper-post-\$?; ) > /dev/$serialdev\n");
                    my @snap_number = split('\n', wait_serial('snapper-post-0'));
                    push @snap_numbers, substr($snap_number[0], 0, -1);    # strip \n
                }
            }
            pop @snapper_cmd if ($type eq 'post');
            pop @snapper_cmd;
        }
        service_action('dbus', {type => ['socket', 'service'], action => ['unmask', 'start']}) if ($snapper =~ /dbus/);
        assert_script_run("$snapper list");
    }
}

sub post_fail_hook() {
    my ($self) = @_;

    upload_logs('/var/log/snapper.log');
}

1;

# vim: set sw=4 et:
