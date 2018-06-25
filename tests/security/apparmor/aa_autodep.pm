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
# Summary: Guess basic AppArmor profile requirements with aa_autodep
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36889, tc#1621141

use strict;
use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {

    my $aa_prof     = "/etc/apparmor.d";
    my $aa_tmp_prof = "/tmp/apparmor.d";

    my $aa_autodep_inactive = qr/Inactive local profile/m;
    my $aa_autodep_done     = qr/AUTODEP-DONE/m;
    my $aa_autodep_check    = [$aa_autodep_inactive, $aa_autodep_done];

    my $output;

    select_console 'root-console';

    # Must disable stdout buffering to make pipe works
    if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.8.95
        assert_script_run "sed -i '/use strict;/a \$|=1;' /usr/sbin/aa-autodep";
    }
    else {                                      # apparmor >= 2.8.95
        assert_script_run "export PYTHONUNBUFFERED=1";
    }

    assert_script_run "mkdir $aa_tmp_prof";
    assert_script_run "cp -r $aa_prof/{tunables,abstractions} $aa_tmp_prof/";

    if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.8.95
        assert_script_run "cp -r $aa_prof/program-chunks $aa_tmp_prof/";
    }

    assert_script_run "aa-autodep -d $aa_tmp_prof/ nscd";
    save_screenshot;

    validate_script_output "cat $aa_tmp_prof/usr.sbin.nscd", sub {
        m/
            include\s+<tunables\/global>.*
            \/usr\/sbin\/nscd\s+flags=\(complain\)\s*\{.*
            include\s+<abstractions\/base>.*
            \/usr\/sbin\/nscd\s+mr.*
            \}/sxx
    };

    save_screenshot;

    assert_script_run "rm -f $aa_tmp_prof/usr.sbin.nscd";

    # Test batch profiles generation function
    script_run("(aa-autodep --d $aa_tmp_prof /usr/bin/pam*;echo 'AUTODEP-DONE')|tee /dev/$serialdev", 0);

    {
        do {
            $output = wait_serial($aa_autodep_check, 300);
            if ($output =~ $aa_autodep_inactive) {
                send_key "c";
                send_key "ret";
            }
            elsif ($output =~ $aa_autodep_done) {
                save_screenshot;
                last;
            }
            else {
                die "Unknown options!";
            }
        } while ($output);
    }

    # Output generated profiles list to serial console
    assert_script_run "ls -1 $aa_tmp_prof/*pam* |tee /dev/$serialdev";

    # Clean up
    assert_script_run("rm -rf $aa_tmp_prof");
}

1;
