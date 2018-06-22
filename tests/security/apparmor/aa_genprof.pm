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
# Summary: Test the profile generation utility of Apparmor
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36886, tc#1621140

use strict;
use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {

    my $aa_tmp_prof       = "/tmp/apparmor.d";
    my $aa_genprof_allow  = qr/\(A\)llow.*\(D\)eny/m;
    my $aa_genprof_scan   = qr/\(S\)can system/m;
    my $aa_genprof_finish = $aa_genprof_scan;
    my $aa_genprof_save   = qr/\(S\)ave Changes/m;
    my $aa_genprof_filter = [$aa_genprof_allow, $aa_genprof_finish, $aa_genprof_save];

    select_console 'root-console';

    systemctl('restart apparmor');
    systemctl('start auditd');

    save_screenshot;

    # Must disable stdout buffering to make pipe works
    if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.8.95
        assert_script_run "sed -i '/use strict;/a \$|=1;' /usr/sbin/aa-genprof";
    }
    else {                                      # apparmor >= 2.8.95
        assert_script_run "export PYTHONUNBUFFERED=1";
    }

    # Test in a separate profile directory to avoid messing up
    assert_script_run("cp -r /etc/apparmor.d $aa_tmp_prof");
    assert_script_run("rm -f  $aa_tmp_prof/usr.sbin.nscd");

    # Run the command in background so that we could run other commands
    script_run("(aa-genprof -d $aa_tmp_prof nscd|tee /dev/$serialdev) &", 0);
    sleep 3;
    send_key 'ret';                             # Back to the shell prompt

    systemctl('restart nscd');

    # Call the job to the front ground
    script_run("fg", 0);
    send_key 'ret';                             # Work around for Tumblweed

    my $output = wait_serial($aa_genprof_scan);

    # Interactive prompt capture
    die "UI - Scan failed!" unless $output =~ $aa_genprof_scan;
    send_key 's';                               #(S)can

    {
        do {
            $output = wait_serial($aa_genprof_filter);
            if ($output =~ $aa_genprof_allow) {
                send_key 'a';                   #(A)llow
            }
            elsif ($output =~ $aa_genprof_finish) {
                send_key 'f';                   #(F)inish
                wait_serial('Finished generating profile for')
                  || die "Not finish in time";
                save_screenshot;
                last;
            }
            elsif ($output =~ $aa_genprof_save) {
                send_key 's';                   #(S)ave
            }
            else {
                die "Unknown options!";
            }
        } while ($output);
    }

    # Not all rules will be checked here, only the critical ones.
    validate_script_output "cat $aa_tmp_prof/usr.sbin.nscd", sub {
        m/
		    include\s+<tunables\/global>.*
            \/usr\/sbin\/nscd\s*{.*
            include\s+<abstractions\/base>.*
            \/usr\/sbin\/nscd\s+mr.*
            }/sxx
    };

    # Verify nscd could start with new generated profile
    assert_script_run("aa-enforce -d $aa_tmp_prof /usr/sbin/nscd");
    systemctl('restart nscd');

    # Clean up and restore
    assert_script_run("aa-disable -d $aa_tmp_prof /usr/sbin/nscd");
    assert_script_run("rm -rf $aa_tmp_prof");
    systemctl('restart nscd');
}

1;
