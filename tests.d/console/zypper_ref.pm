# Copyright (C) 2014 SUSE Linux Products GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "basetest";
use strict;
use bmwqemu;

sub run {
    become_root();
    type_string "PS1=\"# \"\n";

    type_string "zypper lr\n";
    save_screenshot;

    if ( $vars{SCCCREDS} ) { # compat, remove
        ($vars{SCC_EMAIL}, $vars{SCC_REGCODE}) = split( ":", $vars{SCCCREDS} );
    }

    if ($vars{SCC_EMAIL} && $vars{SCC_REGCODE} && (!$vars{SCC_REGISTER} || $vars{SCC_REGISTER} eq 'console')) {
        type_string "yast scc; echo yast-scc-done-\$? > /dev/$serialdev\n";

        assert_screen( "scc-registration", 30 );

        send_key "alt-e";    # select email field
        type_string $vars{SCC_EMAIL};
        send_key "tab";
        type_string $vars{SCC_REGCODE};
        send_key $cmd{"next"}, 1;
        my @tags = qw/local-registration-servers registration-online-repos module-selection/;
        while ( my $ret = check_screen(\@tags, 60 )) {
            if ($ret->{needle}->has_tag("local-registration-servers")) {
                send_key $cmd{ok};
                shift @tags;
                next;
            }
            elsif ($ret->{needle}->has_tag("import-untrusted-gpg-key")) {
                send_key "alt-c", 1;
                next;
            }
            last;
        }

        assert_screen("module-selection", 10);
        send_key $cmd{"next"}, 1;

        wait_serial("yast-scc-done-0") || die "yast scc failed";

        type_string "zypper lr\n";
        assert_screen "scc-repos-listed";
    }

    script_run("zypper ref; echo zypper-ref-\$? > /dev/$serialdev");
    # don't trust graphic driver repo
    if ( check_screen("new-repo-need-key", 20) ) {
        type_string "r\n";
    }
    wait_serial("zypper-ref-0") || die "zypper failed";
    assert_screen("zypper_ref");
    type_string "exit\n";
}

1;

# vim: set sw=4 et:
