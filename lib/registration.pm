# Copyright (C) 2015 SUSE Linux GmbH
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

package registration;

use base Exporter;
use Exporter;

use strict;

use testapi;

our @EXPORT = qw/fill_in_registration_data registration_bootloader_params/;

sub fill_in_registration_data {

    send_key "alt-e";    # select email field
    type_string get_var("SCC_EMAIL");
    send_key "tab";
    type_string get_var("SCC_REGCODE");
    save_screenshot;
    send_key "alt-n", 1;
    my @tags = qw/local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection/;
    push @tags, 'untrusted-ca-cert' if get_var('SCC_URL');
    while (check_screen(\@tags, 60 )) {
        if (match_has_tag("local-registration-servers")) {
            send_key "alt-o";
            @tags = grep { $_ ne 'local-registration-servers' } @tags;
            next;
        }
        elsif (match_has_tag("import-untrusted-gpg-key")) {
            if (check_var("IMPORT_UNTRUSTED_KEY", 1)) {
                send_key "alt-t", 1; # import
            }
            else {
                send_key "alt-c", 1; # cancel
            }
            next;
        }
        elsif (match_has_tag("registration-online-repos")) {
            send_key "alt-y", 1; # want updates
            @tags = grep { $_ ne 'registration-online-repos' } @tags;
            next;
        }
        elsif (get_var('SCC_URL') && match_has_tag("untrusted-ca-cert")) {
            # bsc#943966
            record_soft_failure if get_var('SCC_CERT');
            send_key "alt-t", 1; # trust
            @tags = grep { $_ ne 'untrusted-ca-cert' } @tags;
            next;
        }
        last;
    }

    assert_screen("module-selection");
    if (get_var('SCC_ADDONS')) {
        send_key 'tab'; # jump to beginning of addon selection
        for $a (split(/,/, get_var('SCC_ADDONS'))) {
            my $counter = 30;
            while ($counter > 0) {
                if (check_screen("scc-help-selected", 5 )) {
                    send_key 'tab'; # end of addon fields, jump over control buttons
                    send_key 'tab';
                    send_key 'tab';
                    send_key 'tab';
                    send_key 'tab';
                }
                else {
                    send_key ' ';   # select checkbox for needle match
                    if (check_screen("scc-marked-$a", 5 )) {
                        last;   # match, go to next addon
                    }
                    else {
                        send_key ' ';   # unselect addon if it's not expected one
                        send_key 'tab'; # go to next field
                    }
                }
                $counter--;
            }
        }
        send_key 'alt-n';   # next, all addons selected
        for $a (split(/,/, get_var('SCC_ADDONS'))) {
            assert_screen("scc-addon-license-$a");
            send_key "alt-a";   # accept license
            send_key "alt-n";   # next
        }
        for $a (split(/,/, get_var('SCC_ADDONS'))) {
            $a = uc $a;     # change to uppercase to match variable
            if (my $regcode = get_var("SCC_REGCODE_$a")) {
                assert_screen("scc-addon-regcode-$a");
                send_key 'tab'; # jump to code field
                type_string $regcode;
                send_key "alt-n";   # next
            }
        }
    }
    else {
        send_key "alt-n";   # next
    }
    sleep 10;   # scc registration need some time
}

sub registration_bootloader_params
{
    # https://www.suse.com/documentation/smt11/book_yep/data/smt_client_parameters.html
    # SCC_URL=https://smt.example.com
    if (my $url = get_var("SCC_URL")) {
        type_string " regurl=$url/connect", 13;
        if ($url = get_var("SCC_CERT")) {
            type_string " regcert=$url", 13;
        }
        save_screenshot;
    }
}

1;
# vim: sw=4 et
