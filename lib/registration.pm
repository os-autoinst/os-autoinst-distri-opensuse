# Copyright (C) 2015-2016 SUSE LLC
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
    if (!get_var("HDD_SCC_REGISTERED")) {
        send_key "alt-m";        # select email field if yast2 add-on
        send_key "alt-e";        # select email field if installation
        send_key "backspace";    # delete m or e
        type_string get_var("SCC_EMAIL");
        send_key "alt-c";        # select registration code field
        type_string get_var("SCC_REGCODE");
        save_screenshot;
        send_key "alt-n", 1;
    }
    unless (get_var('SCC_REGISTER', '') =~ /addon|network/) {
        my @tags = qw/local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection contacting-registration-server/;
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
                if (!get_var('QAM_MINIMAL')) {
                    send_key "alt-y", 1;    # want updates
                }
                else {
                    send_key "alt-n", 1;    # minimal dont want updates
                }

                @tags = grep { $_ ne 'registration-online-repos' } @tags;
                next;
            }
            elsif (match_has_tag('contacting-registration-server')) {
                # sometimes SCC just takes its time - just continue looking after a while
                sleep 5;
                next;
            }
            elsif (get_var('SCC_URL') && match_has_tag("untrusted-ca-cert")) {
                record_soft_failure 'bsc#943966' if get_var('SCC_CERT');
                send_key "alt-t", 1;    # trust
                @tags = grep { $_ ne 'untrusted-ca-cert' } @tags;
                next;
            }
            last;
        }
    }

    if (check_var('SCC_REGISTER', 'installation')) {
        if (check_screen("local-registration-servers", 10)) {
            send_key $cmd{ok};
        }
        if (check_screen('scc-beta-filter-checkbox', 5)) {
            send_key 'alt-f';    # uncheck 'Filter Out Beta Version'
        }
        # The value of SCC_ADDONS is a list of abbreviation of addons/modules
        # Following are abbreviations defined for modules and some addons
        #
        # live - Live Patching
        # asmm - Advanced System Management Module
        # certm - Certifications Module
        # contm - Containers Module
        # lgm - Legacy Module
        # pcm - Public Cloud Module
        # tcm - Toolchain Module
        # wsm - Web and Scripting Module
        # idu - IBM DLPAR Utils (ppc64le only)
        # ids - IBM DLPAR sdk (ppc64le only)
        if (get_var('SCC_ADDONS')) {
            for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
                if (check_var('VIDEOMODE', 'text')) {
                    send_key_until_needlematch "scc-module-$addon", 'tab';
                    send_key "spc";
                }
                else {
                    wait_still_screen(1);
                    wait_screen_change { assert_and_click "scc-module-$addon" };
                    # don't confuse later upcoming dialogs with mouse cursor
                    # near the middle of screen
                    mouse_hide(1);
                }
                save_screenshot;
            }
            send_key 'alt-n';    # next, all addons selected
            for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
                # most modules don't have license, skip them
                next unless grep { $addon eq $_ } qw(ha geo sdk we live rt ids lgm wsm);
                while (check_screen('scc-downloading-license', 5)) {
                    # wait for SCC to give us the license
                    sleep 5;
                }
                assert_screen("scc-addon-license-$addon");
                send_key "alt-a", 1;    # accept license
                send_key "alt-n", 1;    # next
            }
            for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
                $uc_addon = uc $addon;    # change to uppercase to match variable
                if (my $regcode = get_var("SCC_REGCODE_$uc_addon")) {
                    # skip addons which doesn't need to input scc code
                    next unless grep { $addon eq $_ } qw(ha geo we live rt);
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
            send_key 'alt-n';
            # start addons/modules registration, it needs longer time if select multiple or all addons/modules
            while (assert_screen(['import-untrusted-gpg-key', 'yast_scc-pkgtoinstall', 'inst-addon'], 120)) {
                if (match_has_tag('import-untrusted-gpg-key')) {
                    record_soft_failure 'untrusted gpg key';
                    send_key 'alt-t';
                    next;
                }
                elsif (match_has_tag('inst-addon') || match_has_tag('yast_scc-pkgtoinstall')) {
                    # it would show Add On Product screen if scc registration correctly during installation
                    # it would show software install dialog if scc registration correctly by yast2 scc
                    last;
                }
            }
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
    my ($max_interval) = @_;     # see 'type_string'
    $max_interval //= 13;
    # https://www.suse.com/documentation/smt11/book_yep/data/smt_client_parameters.html
    # SCC_URL=https://smt.example.com
    if (my $url = get_var("SCC_URL")) {
        type_string " regurl=$url/connect", $max_interval;
        if ($url = get_var("SCC_CERT")) {
            type_string " regcert=$url", $max_interval;
        }
        save_screenshot;
    }
}

sub yast_scc_registration {

    type_string "yast2 scc; echo yast-scc-done-\$?- > /dev/$serialdev\n";
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
            # yast may pop up a reboot prompt window after addons installation such like ha on sle12 sp0
            while (assert_screen([qw/yast_scc-prompt-reboot yast_scc-installation-summary/], 900)) {
                if (match_has_tag('yast_scc-prompt-reboot')) {
                    send_key "alt-o", 1;
                    next;
                }
                elsif (match_has_tag('yast_scc-installation-summary')) {
                    send_key "alt-f";
                    last;
                }
            }
        }
    }
    else {
        # yast would display empty pkg install screen if no addon selected on sle12 sp0
        # set check_screen timeout 5 to reduce check time on sle12 sp1 or higher
        if (check_screen("yast-scc-emptypkg", 5)) {
            send_key "alt-a";
        }
    }

    my $ret = wait_serial "yast-scc-done-\\d+-", $timeout;
    die "yast scc failed" unless (defined $ret && $ret =~ /yast-scc-done-0-/);

    script_run 'zypper lr';
    assert_screen 'scc-repos-listed';
}

1;
# vim: sw=4 et
