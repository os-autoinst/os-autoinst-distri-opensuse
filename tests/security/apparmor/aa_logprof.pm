# Copyright (C) 2018 SUSE LLC
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
#
# Summary: Test the utility for updating AppArmor security profiles
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36892, tc#1621143

use strict;
use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {

    my $output;
    my $aa_prof     = "/etc/apparmor.d";
    my $aa_tmp_prof = "/tmp/apparmor.d";

    my $aa_logprof_allow = qr/\(A\)llow/m;
    my $aa_logprof_save  = qr/\(S\)ave Changes/m;

    select_console 'root-console';

    systemctl('restart apparmor');
    systemctl('stop nscd');
    systemctl('restart auditd');

    # Must disable stdout buffering to make pipe works
    if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.8.95
        assert_script_run "sed -i '/use strict;/a \$|=1;' /usr/sbin/aa-logprof";
    }
    else {                                      # apparmor >= 2.8.95
        assert_script_run "export PYTHONUNBUFFERED=1";
    }

    assert_script_run "cp -r $aa_prof $aa_tmp_prof";

    my @aa_logprof_items = ('capability setuid', '\/var\/log\/nscd.log');

    # Remove some rules from profile
    foreach my $item (@aa_logprof_items) {
        assert_script_run "sed -i '/$item/d' $aa_tmp_prof/usr.sbin.nscd";
    }

    validate_script_output "aa-complain -d $aa_tmp_prof usr.sbin.nscd", sub { m/Setting.*complain/ };

    systemctl('start nscd');

    script_run("aa-logprof -d $aa_tmp_prof|tee /dev/$serialdev", 0);

    # Interactive prompt capture
    {
        do {
            $output = wait_serial([$aa_logprof_allow, $aa_logprof_save]);
            if ($output =~ $aa_logprof_allow) {
                send_key 'a';
            }
            elsif ($output =~ $aa_logprof_save) {
                send_key 's';
                last;
            }
            else {
                die "Unknown options!";
            }
        } while ($output);
    }

    validate_script_output "cat $aa_tmp_prof/usr.sbin.nscd", sub {
        m/
            include\s+<tunables\/global>.*
            \/usr\/sbin\/nscd\s+flags=\(complain\)\s*\{.*
            \/etc\/nscd\.conf\s+r.*
            \/usr\/sbin\/nscd\s+mrix.*
            \}/sxx
    };

    # Verify nscd could start with new generated profile
    assert_script_run("aa-enforce -d $aa_tmp_prof /usr/sbin/nscd");
    systemctl('restart nscd');

    # Restore
    assert_script_run("aa-disable -d $aa_tmp_prof /usr/sbin/nscd");
    assert_script_run("aa-enforce /usr/sbin/nscd");
    systemctl('restart nscd');

    # Clean up
    assert_script_run("rm -rf $aa_tmp_prof");
}

1;
