# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary: run performance cases
# Maintainer: Joyce Na <jna@suse.de>

package full_run;
use ipmi_backend_utils;
use strict;
use power_action_utils 'power_action';
use warnings;
use testapi;
use base 'y2_installbase';
use File::Basename;
use Utils::Backends 'use_ssh_serial_console';

sub full_run {
    my $time_out //= 6;
    my $list_path   = "/root/qaset";
    my $remote_list = get_var("FULL_LIST");
    my $hostname    = script_output "hostname";
    #setup run list
    assert_script_run("wget -N -P $list_path $remote_list 2>&1");
    assert_script_run("cp $list_path/default.list $list_path/list");

    assert_script_run("/usr/share/qa/qaset/qaset reset");
    assert_script_run("/usr/share/qa/qaset/run/performance-run.upload_Beijing");
    while (1) {
        if (script_run("cat /var/log/qaset/control/NEXT_RUN | grep '_'") == 0) {
            last;
        }
        if ($time_out == 0) {
            die "Full run failed,please rerun.";
        }
        sleep 30;
        --$time_out;
    }
}

sub run {
    full_run;
}

sub post_fail_hook {
    my ($self) = @_;
    my $screenlog = script_output("ls -rt /var/log/qaset/calls | tail -n 1");
    upload_logs "/var/log/qaset/calls/$screenlog";
}

sub test_flags {
    return {fatal => 1};
}

1;
