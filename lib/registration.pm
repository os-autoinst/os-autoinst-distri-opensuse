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

our @EXPORT = qw/fill_in_registration_data registration_bootloader_params yast_scc_registration/;

sub fill_in_registration_data {
    my ($addon, $uc_addon);
    send_key "alt-m";        # select email field if yast2 add-on
    send_key "alt-e";        # select email field if installation
    send_key "backspace";    # delete m or e
    type_string get_var("SCC_EMAIL");
    send_key "alt-c";        # select registration code field
    type_string get_var("SCC_REGCODE");
    save_screenshot;
    send_key "alt-n", 1;
    unless (get_var('SCC_REGISTER', '') =~ /addon|network/) {
        my @tags = qw/local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection/;
        push @tags, 'untrusted-ca-cert' if get_var('SCC_URL');
        while (check_screen(\@tags, 60)) {
            if (match_has_tag("local-registration-servers")) {
                send_key "alt-o";
                @tags = grep { $_ ne 'local-registration-servers' } @tags;
                next;
            }
            elsif (match_has_tag("import-untrusted-gpg-key")) {
                if (check_var("IMPORT_UNTRUSTED_KEY", 1)) {
                    send_key "alt-t", 1;    # import
                }
                else {
                    send_key "alt-c", 1;    # cancel
                }
                next;
            }
            elsif (match_has_tag("registration-online-repos")) {
                send_key "alt-y", 1;        # want updates
                @tags = grep { $_ ne 'registration-online-repos' } @tags;
                next;
            }
            elsif (get_var('SCC_URL') && match_has_tag("untrusted-ca-cert")) {
                # bsc#943966
                record_soft_failure if get_var('SCC_CERT');
                send_key "alt-t", 1;        # trust
                @tags = grep { $_ ne 'untrusted-ca-cert' } @tags;
                next;
            }
            last;
        }
    }

    if (check_var('SCC_REGISTER', 'installation')) {
        if (get_var('SCC_ADDONS')) {
            for $addon (get_var_array('SCC_ADDONS')) {
                if (check_var('DESKTOP', 'textmode')) {
                    send_key_until_needlematch "scc-module-$addon", 'tab';
                    send_key "spc";
                }
                else {
                    assert_and_click "scc-module-$addon";
                }
            }
            send_key 'alt-n';    # next, all addons selected
            for $addon (get_var_array('SCC_ADDONS')) {
                assert_screen("scc-addon-license-$addon");
                send_key "alt-a", 1;    # accept license
                send_key "alt-n", 1;    # next
            }
            for $addon (get_var_array('SCC_ADDONS')) {
                $uc_addon = uc $addon;    # change to uppercase to match variable
                if (my $regcode = get_var("SCC_REGCODE_$uc_addon")) {
                    next if ($addon =~ /sdk|rt/);    # bsc#956726
                    if (check_var('DESKTOP', 'textmode')) {
                        send_key_until_needlematch "scc-code-field-$addon", 'tab';
                    }
                    else {
                        assert_and_click "scc-code-field-$addon";
                    }
                    type_string $regcode;
                    sleep 1;
                    save_screenshot;
                }
            }
            send_key 'alt-n', 2;
            if (check_screen('import-untrusted-gpg-key', 10)) {
                record_soft_failure;
                send_key 'alt-t', 2;
            }
            sleep 20;    # scc registration need some time
        }
        else {
            send_key 'alt-n';    # next
        }
    }
    else {
        if (!get_var('SCC_REGISTER', '') =~ /addon|network/) {
            assert_screen("module-selection");
            send_key "alt-n";    # next
        }
    }
}

sub registration_bootloader_params {
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

sub yast_scc_registration {

    script_run "yast2 scc; echo yast-scc-done-\$?- > /dev/$serialdev";
    assert_screen 'scc-registration', 30;

    fill_in_registration_data;

    my $timeout = 30;

    # if addons where selected yast shows the software install
    # dialog
    if (get_var('SCC_ADDONS')) {
        assert_screen("yast_scc-pkgtoinstall");
        send_key "alt-a";

        while (check_screen([qw/yast_scc-license-dialog yast_scc-automatic-changes/])) {
            if (match_has_tag('yast_scc-license-dialog')) {
                send_key "alt-a";
                next;
            }
            last;
        }
        send_key "alt-o";
        # Upgrade tests and the old distributions eg. SLE11 don't
        # show the summary
        if (get_var("YAST_SW_NO_SUMMARY")) {
            $timeout = 900;    # installation of an addon may take long
        }
        else {
            assert_screen 'yast_scc-installation-summary', 900;
            send_key "alt-f";
        }
    }

    my $ret = wait_serial "yast-scc-done-\\d+-", $timeout;
    die "yast scc failed" unless (defined $ret && $ret =~ /yast-scc-done-0-/);

    script_run 'zypper lr';
    assert_screen 'scc-repos-listed';
}

1;
# vim: sw=4 et
