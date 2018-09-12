# Copyright (C) 2017-2018 SUSE LLC
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
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

use base 'consoletest';

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

sub pre_run_hook {
    my ($self) = @_;

    select_console 'root-console';
    systemctl('restart apparmor');
}

1;
