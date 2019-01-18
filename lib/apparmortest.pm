# Copyright (C) 2017-2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Base module for AppArmor test cases
# Maintainer: Wes <whdu@suse.com>

package apparmortest;

use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

use base 'consoletest';

our @EXPORT = qw (
  $audit_log
);

our $audit_log = "/var/log/audit/audit.log";

# Disable stdout buffering to make pipe works
sub aa_disable_stdout_buf {
    my ($self, $app) = @_;
    if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.8.95
        assert_script_run "sed -i '/use strict;/a \$|=1;' $app";
    }
    else {                                      # apparmor >= 2.8.95
        assert_script_run "export PYTHONUNBUFFERED=1";
    }
}

# $prof_dir_tmp: The target temporary directory
# $type:
# 0  - Copy only the basic structure of profile directory
# != 0 (default) - Copy full contents under the profile directory
sub aa_tmp_prof_prepare {
    my ($self, $prof_dir_tmp, $type) = @_;
    my $prof_dir = "/etc/apparmor.d";
    $type //= 1;

    if ($type == 0) {
        assert_script_run "mkdir $prof_dir_tmp";
        assert_script_run "cp -r $prof_dir/{tunables,abstractions} $prof_dir_tmp/";
        if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.8.95
            assert_script_run "cp -r $prof_dir/program-chunks $prof_dir_tmp/";
        }
    }
    else {
        assert_script_run "cp -r $prof_dir $prof_dir_tmp";
    }
}

# Verify the program could start with the temporary profiles
# Then restore it to the enforce status with normal profiles
sub aa_tmp_prof_verify {
    my ($self, $prof_dir_tmp, $prog) = @_;

    assert_script_run("aa-disable $prog");

    assert_script_run("aa-enforce -d $prof_dir_tmp $prog");
    systemctl("restart $prog");
    assert_script_run("aa-disable -d $prof_dir_tmp $prog");

    assert_script_run("aa-enforce $prog");
    systemctl("restart $prog");
}

sub aa_tmp_prof_clean {
    my ($self, $prof_dir_tmp) = @_;

    assert_script_run "rm -rf $prof_dir_tmp";
}

# For interactive command, answer the question according to the contents
# matched. Need an arrayref to pass the contents to be filtered and the
# Answer send_key
sub aa_interactive_run {
    my ($self, $cmd, $scan, $timeout) = @_;
    my $output;
    my @words;
    $timeout //= 180;

    for my $k (@$scan) {
        push(@words, $k->{word});
    }

    if ($cmd) {
        script_run("(" . $cmd . ")| tee /dev/$serialdev", 0);
    }

  LOOP: {
        do {
            $output = wait_serial(\@words, $timeout) || die "Uknown Options!";
            for my $i (@$scan) {
                if ($output =~ $i->{word}) {
                    if ($i->{key}) {
                        send_key $i->{key};
                        last LOOP if ($i->{end});
                        last;
                    }
                    elsif ($i->{end}) {
                        last LOOP;
                    }
                    else {
                        die "$i->{word} - 'key' or 'end' should be specified";
                    }
                }
            }
        } while ($output);
    }
}

# Get the named profile for an executable program
sub get_named_profile {
    my ($self, $profile_name) = @_;

    # Recalculate profile name in case
    $profile_name = script_output("grep ' {\$' /etc/apparmor.d/$profile_name | sed 's/ {//'");
    if ($profile_name =~ m/profile /) {
        $profile_name = script_output("echo $profile_name | cut -d ' ' -f2");
    }
    return $profile_name;
}

# Check the output of aa-status: if a given profile belongs to a given mode
sub aa_status_stdout_check {
    my ($self, $profile_name, $profile_mode) = @_;

    my $start_line = script_output("aa-status | grep -n 'profiles are in' | grep $profile_mode | cut -d ':' -f1");
    my $total_line = script_output("aa-status | grep 'profiles are in' | grep $profile_mode | cut -d ' ' -f1");
    my $lines      = $start_line + $total_line;

    assert_script_run("aa-status | head -$lines | tail -$total_line | sed 's/[ \t]*//g' | grep -x $profile_name");
}

sub pre_run_hook {
    my ($self) = @_;

    select_console 'root-console';
    systemctl('restart auditd');
    systemctl('restart apparmor');
}

sub post_fail_hook {
    my ($self) = shift;
    upload_logs("$audit_log");
    $self->SUPER::post_fail_hook;
}

1;
