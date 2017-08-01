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
use utils qw(addon_decline_license assert_screen_with_soft_timeout);

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
        wait_screen_change { send_key $cmd{next} };
    }
    my @known_untrusted_keys = qw(import-trusted-gpg-key-nvidia-F5113243C66B6EAE import-trusted-gpg-key-phub-9C214D4065176565);
    unless (get_var('SCC_REGISTER', '') =~ /addon|network/) {
        my @tags = qw(local-registration-servers registration-online-repos import-untrusted-gpg-key module-selection contacting-registration-server);
        if (get_var('SCC_URL') || get_var('SMT_URL')) {
            push @tags, 'untrusted-ca-cert';
        }
        while (check_screen(\@tags, 60)) {
            if (match_has_tag("import-untrusted-gpg-key")) {
                if (check_var("IMPORT_UNTRUSTED_KEY", 1) || check_screen(\@known_untrusted_keys, 0)) {
                    send_key "alt-t";    # import
                }
                else {
                    send_key "alt-c";    # cancel
                }
                next;
            }
            elsif (match_has_tag('contacting-registration-server')) {
                # sometimes SCC just takes its time - just continue looking after a while
                sleep 5;
                next;
            }
            elsif ((get_var('SCC_URL') || get_var('SMT_URL')) && match_has_tag("untrusted-ca-cert")) {
                record_soft_failure 'bsc#943966' if get_var('SCC_CERT');
                send_key 'alt-t';
                wait_still_screen 5;
                # the behavior here of smt registration on 12sp1 is a little different with
                # 12sp0 and 12sp2, normally registration would start automatically after
                # untrusted certification imported, but it would not on 12sp1, and we have to
                # send next manually to start registration.
                if (get_var('SMT_URL') && (check_var('VERSION', '12-SP1') || check_var('HDDVERSION', '12-SP1'))) {
                    send_key $cmd{next};
                }
                @tags = grep { $_ ne 'untrusted-ca-cert' } @tags;
                next;
            }
            elsif (match_has_tag('registration-online-repos')) {
                if (!get_var('QAM_MINIMAL')) {
                    wait_screen_change { send_key 'alt-y' };    # want updates
                }
                else {
                    wait_screen_change { send_key $cmd{next} };    # minimal dont want updates
                }
                next;
            }
            elsif (match_has_tag('module-selection')) {
                last;
            }
        }
    }

    if (check_var('SCC_REGISTER', 'installation') || check_var('SCC_REGISTER', 'yast') || check_var('SCC_REGISTER', 'console')) {
        # The value of SCC_ADDONS is a list of abbreviation of addons/modules
        # Following are abbreviations defined for modules and some addons
        #
        # live - Live Patching
        # asmm - Advanced System Management Module
        # certm - Certifications Module
        # contm - Containers Module
        # hpcm - HPC Module
        # lgm - Legacy Module
        # pcm - Public Cloud Module
        # tcm - Toolchain Module
        # wsm - Web and Scripting Module
        # idu - IBM DLPAR Utils (ppc64le only)
        # ids - IBM DLPAR sdk (ppc64le only)
        # phub - PackageHub
        if (get_var('SCC_ADDONS')) {
            if (check_screen('scc-beta-filter-checkbox', 5)) {
                if (get_var('SP3ORLATER')) {
                    send_key 'alt-i';    # uncheck 'Hide Beta Versions'
                }
                else {
                    send_key 'alt-f';    # uncheck 'Filter Out Beta Version'
                }
            }
            my @scc_addons = split(/,/, get_var('SCC_ADDONS', ''));
            for my $addon (@scc_addons) {
                if (check_var('VIDEOMODE', 'text') || check_var('SCC_REGISTER', 'console')) {
                    # The actions of selecting scc addons have been changed on SP2 or later in textmode
                    # For online migration, we have to do registration on pre-created HDD, set a flag
                    # to distinguish the sle version of HDD and perform addons selection based on it
                    if (get_var('ONLINE_MIGRATION') || get_var('PATCH')) {
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
            # go back and forward, checked checkboxes have to remember state poo#17840
            if (check_var('SCC_REGISTER', 'yast')) {
                wait_screen_change { send_key 'alt-b' };
                assert_screen 'scc-registration-already-registered';
                wait_screen_change { send_key $cmd{next} };
                for my $addon (@scc_addons) {
                    assert_screen "scc-module-$addon-selected";
                }
            }
            send_key $cmd{next};    # all addons selected
            for my $addon (@scc_addons) {
                # most modules don't have license, skip them
                next unless grep { $addon eq $_ } qw(ha geo sdk we live rt idu ids lgm wsm hpcm);
                while (check_screen('scc-downloading-license', 5)) {
                    # wait for SCC to give us the license
                    sleep 5;
                }
                assert_screen "scc-addon-license-$addon", 60;
                addon_decline_license;
                wait_still_screen 2;
                send_key $cmd{next};
            }
            for my $addon (@scc_addons) {
                # no need to input registration code if register via SMT
                last if (get_var('SMT_URL'));
                $uc_addon = uc $addon;    # change to uppercase to match variable
                if ($addon eq 'phub') {
                    record_soft_failure 'bsc#1046172';
                    set_var('SCC_REGCODE_PHUB', get_required_var('SCC_REGCODE'));
                }
                if (my $regcode = get_var("SCC_REGCODE_$uc_addon")) {
                    # skip addons which doesn't need to input scc code
                    next unless grep { $addon eq $_ } qw(ha geo we live rt ltss phub);
                    if (check_var('VIDEOMODE', 'text')) {
                        send_key_until_needlematch "scc-code-field-$addon", 'tab';
                    }
                    else {
                        assert_and_click "scc-code-field-$addon";
                    }
                    type_string $regcode;
                    save_screenshot;
                }
            }
            wait_screen_change { send_key $cmd{next} };
            # start addons/modules registration, it needs longer time if select multiple or all addons/modules
            while (assert_screen(['import-untrusted-gpg-key', 'yast_scc-pkgtoinstall', 'yast-scc-emptypkg', 'inst-addon'], 120)) {
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
                    # yast shows the software install dialog
                    wait_screen_change { send_key 'alt-a' };
                    while (
                        assert_screen(
                            ['yast_scc-license-dialog', 'yast_scc-automatic-changes', 'yast_scc-prompt-reboot', 'yast_scc-installation-summary'], 900
                        ))
                    {
                        if (match_has_tag('yast_scc-license-dialog')) {
                            send_key 'alt-a';
                            next;
                        }
                        # yast may pop up dependencies or reboot prompt window
                        if (match_has_tag('yast_scc-automatic-changes') or match_has_tag('unsupported-packages') or match_has_tag('yast_scc-prompt-reboot')) {
                            send_key 'alt-o';
                            next;
                        }
                        if (match_has_tag('yast_scc-installation-summary')) {
                            send_key 'alt-f';
                            last;
                        }
                    }
                    last;
                }
                # yast would display empty pkg install screen if no addon selected on sle12 sp0
                # set check_screen timeout longer to ensure the screen checked in this case
                elsif (match_has_tag('yast-scc-emptypkg')) {
                    if (check_screen('yast-scc-emptypkg', 5)) {
                        send_key 'alt-a';
                        last;    # Exit yast scc register, no package need be install
                    }
                    else {
                        record_soft_failure 'bsc#1040758';
                        next;    # Yast may popup dependencies or software install dialog, enter determine statement again.
                    }
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
            send_key $cmd{next};
        }
    }
}

sub select_addons_in_textmode {
    my ($addon, $flag) = @_;
    if ($flag) {
        send_key_until_needlematch 'scc-module-area-selected', 'tab';
        send_key_until_needlematch "scc-module-$addon",        'down';
        if (check_var('ARCH', 'aarch64') && check_var('HDDVERSION', '12-SP2') && check_screen('scc-module-tcm-selected', 5)) {
            record_info('Workaround',
                "Toolchain module is selected and installed by default on sles12sp2 aarch64\nSee: https://progress.opensuse.org/issues/19852");
        }
        else {
            send_key 'spc';
        }
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
        type_string " regurl=$url", $max_interval;
        if ($url = get_var("SCC_CERT")) {
            type_string " regcert=$url", $max_interval;
        }
        save_screenshot;
    }
}

sub yast_scc_registration {

    type_string "yast2 scc; echo yast-scc-done-\$?- > /dev/$serialdev\n";
    assert_screen_with_soft_timeout(
        'scc-registration',
        timeout      => 90,
        soft_timeout => 30,
        bugref       => 'wait longer time to start yast2 scc in case of multiple jobs start to execute it in parallel on a same worker'
    );

    fill_in_registration_data;

    my $ret = wait_serial "yast-scc-done-\\d+-";
    die "yast scc failed" unless (defined $ret && $ret =~ /yast-scc-done-0-/);

    # To check repos validity after registration, call 'validate_repos' as needed
}

sub skip_registration {
    wait_screen_change { send_key "alt-s" };    # skip SCC registration
    assert_screen([qw(scc-skip-reg-warning-yes scc-skip-reg-warning-ok scc-skip-reg-no-warning)]);
    if (match_has_tag('scc-skip-reg-warning-ok')) {
        send_key "alt-o";                       # confirmed skip SCC registration
        wait_still_screen;
        send_key $cmd{next};
    }
    elsif (match_has_tag('scc-skip-reg-warning-yes')) {
        send_key "alt-y";                       # confirmed skip SCC registration
    }
}

1;
# vim: sw=4 et
