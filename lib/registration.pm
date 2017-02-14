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
use utils 'addon_decline_license';

our @EXPORT = qw(fill_in_registration_data registration_bootloader_params yast_scc_registration skip_registration);

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
        send_key $cmd{next}, 1;
    }
    my @known_untrusted_keys = qw(import-trusted-gpg-key-nvidia-F5113243C66B6EAE);
    unless (get_var('SCC_REGISTER', '') =~ /addon|network/) {
        my @tags = qw(local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection contacting-registration-server);
        if (get_var('SCC_URL') || get_var('SMT_URL')) {
            push @tags, 'untrusted-ca-cert';
            if (get_var('SMT_URL')) {
                push @tags, 'registration-12sp1-check';
            }
        }
        while (check_screen(\@tags, 60)) {
            if (match_has_tag("local-registration-servers")) {
                send_key "alt-o";
                @tags = grep { $_ ne 'local-registration-servers' } @tags;
                next;
            }
            elsif (match_has_tag("import-untrusted-gpg-key")) {
                if (check_var("IMPORT_UNTRUSTED_KEY", 1) || check_screen(\@known_untrusted_keys, 0)) {
                    send_key "alt-t";    # import
                }
                else {
                    send_key "alt-c";
                    ;                    # cancel
                }
                next;
            }
            elsif (match_has_tag("registration-online-repos")) {
                if (!get_var('QAM_MINIMAL')) {
                    send_key "alt-y", 1;    # want updates
                }
                else {
                    send_key $cmd{next}, 1;    # minimal dont want updates
                }

                @tags = grep { $_ ne 'registration-online-repos' } @tags;
                next;
            }
            elsif (match_has_tag('contacting-registration-server')) {
                # sometimes SCC just takes its time - just continue looking after a while
                sleep 5;
                next;
            }
            elsif ((get_var('SCC_URL') || get_var('SMT_URL')) && match_has_tag("untrusted-ca-cert")) {
                record_soft_failure 'bsc#943966' if get_var('SCC_CERT');
                send_key "alt-t", 1;
                # the behavior here of smt registration on 12sp1 is a little different with
                # 12sp0 and 12sp2, normally registration would start automatically after
                # untrusted certification imported, but it would not on 12sp1, and we have to
                # send next manually to start registration.
                if (get_var('SMT_URL')) {
                    if (check_screen('registration-12sp1-check', 5)) {
                        send_key $cmd{next};
                    }
                    @tags = grep { $_ ne 'registration-12sp1-check' } @tags;
                }
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
                    # The actions of selecting scc addons have been changed on SP2 or later in textmode
                    # For online migration, we have to do registration on pre-created HDD, set a flag
                    # to distinguish the sle version of HDD and perform addons selection based on it
                    if (get_var('ONLINE_MIGRATION')) {
                        select_addons_in_textmode($addon, get_var('HDD_SP2ORLATER'));
                    }
                    else {
                        select_addons_in_textmode($addon, get_var('SP2ORLATER'));
                    }
                }
                else {
                    # go to the top of the list before looking for the addon
                    send_key "home";

                    # move the list of addons down until the current addon is found
                    send_key_until_needlematch "scc-module-$addon", "down";

                    # checkmark the requested addon
                    assert_and_click "scc-module-$addon";
                }
            }
            send_key $cmd{next};    # all addons selected
            for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
                # most modules don't have license, skip them
                next unless grep { $addon eq $_ } qw(ha geo sdk we live rt idu ids lgm wsm);
                while (check_screen('scc-downloading-license', 5)) {
                    # wait for SCC to give us the license
                    sleep 5;
                }
                assert_screen("scc-addon-license-$addon");
                addon_decline_license;
                wait_still_screen 2;
                send_key $cmd{next};
            }
            for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
                # no need to input registration code if register via SMT
                last if (get_var('SMT_URL'));
                $uc_addon = uc $addon;    # change to uppercase to match variable
                if (my $regcode = get_var("SCC_REGCODE_$uc_addon")) {
                    # skip addons which doesn't need to input scc code
                    next unless grep { $addon eq $_ } qw(ha geo we live rt ltss);
                    if (check_var('VIDEOMODE', 'text')) {
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
            send_key $cmd{next};
            # start addons/modules registration, it needs longer time if select multiple or all addons/modules
            while (assert_screen(['import-untrusted-gpg-key', 'yast_scc-pkgtoinstall', 'inst-addon'], 120)) {
                if (match_has_tag('import-untrusted-gpg-key')) {
                    if (!check_screen(\@known_untrusted_keys, 0)) {
                        record_soft_failure 'untrusted gpg key';
                    }
                    wait_screen_change {
                        send_key 'alt-t';
                    };
                    next;
                }
                elsif (match_has_tag('yast_scc-pkgtoinstall')) {
                    # if addons where selected yast shows the software install
                    # dialog
                    if (get_var('SCC_ADDONS')) {
                        assert_screen("yast_scc-pkgtoinstall");
                        send_key "alt-a";

                        while (check_screen([qw(yast_scc-license-dialog yast_scc-automatic-changes)])) {
                            if (match_has_tag('yast_scc-license-dialog')) {
                                send_key "alt-a";
                                next;
                            }
                            last;
                        }
                        send_key "alt-o";
                        send_key 'alt-o' if check_screen('unsupported-packages', 2);

                        # yast may pop up a reboot prompt window after addons installation such like ha on sle12 sp0
                        while (assert_screen([qw(yast_scc-prompt-reboot yast_scc-installation-summary)], 900)) {
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
                    else {
                        # yast would display empty pkg install screen if no addon selected on sle12 sp0
                        # set check_screen timeout longer to ensure the screen checked in this case
                        if (check_screen("yast-scc-emptypkg", 15)) {
                            send_key "alt-a";
                        }
                    }
                    last;
                }
                elsif (match_has_tag('inst-addon')) {
                    # it would show Add On Product screen if scc registration correctly during installation
                    # it would show software install dialog if scc registration correctly by yast2 scc
                    last;
                }
            }
        }
        else {
            send_key $cmd{next};
            if (check_var('HDDVERSION', '12')) {
                assert_screen 'yast-scc-emptypkg';
                send_key 'alt-a';
            }
        }
    }
    else {
        if (!get_var('SCC_REGISTER', '') =~ /addon|network/) {
            assert_screen("module-selection");
            send_key $cmd{next};
        }
    }
}

sub select_addons_in_textmode {
    my ($addon, $flag) = @_;
    if ($flag) {
        send_key_until_needlematch 'scc-module-area-selected', 'tab';
        send_key_until_needlematch "scc-module-$addon",        'down';
        send_key 'spc';
        # After selected/deselected an addon, yast scc would automatically bounce the focus
        # back to the top of list on SP2 or later in textmode, remove sendkey up
        # And give a tiny time to wait it back completely to the top of list
        wait_still_screen 1;
    }
    else {
        send_key_until_needlematch "scc-module-$addon", 'tab';
        send_key "spc";
    }
}

sub registration_bootloader_params {
    my ($max_interval) = @_;    # see 'type_string'
    $max_interval //= 13;
    # https://www.suse.com/documentation/smt11/book_yep/data/smt_client_parameters.html
    # SCC_URL=https://smt.example.com
    if (my $url = get_var("SCC_URL") || get_var("SMT_URL")) {
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

    my $ret = wait_serial "yast-scc-done-\\d+-", 30;
    die "yast scc failed" unless (defined $ret && $ret =~ /yast-scc-done-0-/);

    # To check repos validity after registration, call 'validate_repos' as needed
}

sub skip_registration {
    send_key "alt-s", 1;    # skip SCC registration
    assert_screen([qw(scc-skip-reg-warning-yes scc-skip-reg-warning-ok scc-skip-reg-no-warning)]);
    if (match_has_tag('scc-skip-reg-warning-ok')) {
        send_key "alt-o";    # confirmed skip SCC registration
        wait_still_screen;
        send_key $cmd{next};
    }
    elsif (match_has_tag('scc-skip-reg-warning-yes')) {
        send_key "alt-y";    # confirmed skip SCC registration
    }
}

1;
# vim: sw=4 et
