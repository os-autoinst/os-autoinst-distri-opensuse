# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module tests glibc-locale
# Test flow:
#           sle15:
#                   1) SUT exits firstrun with english locale settings
#                   2) Verify expected user LANG value
#                   3) Verify that ROOT_USES_LANG="ctype" is set
#                   4) Change user's locale to DE
#                   5) Validate locale
#                   6) Revert change
#                   7) Verify that test glibc string matches original
#           sle12:
#                   1) SUT exits firstrun with german locale settings
#                   2) Verify expected user LANG value
#                   3) Parse and examine /etc/sysconfig/language
#                   4) Change user's locale to en_US
#                   5) Validate locale
#                   6) Verify that test glibc string has been changed
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils qw(zypper_call clear_console ensure_serialdev_permissions);
use version_utils qw(is_opensuse is_sle is_jeos);
use power_action_utils 'power_action';

## Define test data
my $suse_lang_conf = '/etc/sysconfig/language';
my %lc_data        = (en_US => 'en_US.UTF-8', de_DE => 'de_DE.UTF-8');
my %test_lang_data = (en_US => 'For bug reporting', de_DE => 'Eine Anleitung zum Melden');

sub change_locale {
    # if there is no new language to be set, let's return
    my $new_language = shift;
    return unless defined($new_language);

    record_info('Setup', "Changing to $new_language");
    my $rc_lc_setup_const = shift;
    my %rc_lc_modified;

    select_console('root-console', await_console => 0, ensure_tty_selected => 0, skip_set_standard_prompt => 1, skip_setterm => 1);
    ensure_serialdev_permissions;

    if (is_sle('<15')) {
        ## suitable for sles12 family only
        # create a shallow hash copy
        %rc_lc_modified                 = %$rc_lc_setup_const;
        $rc_lc_modified{RC_LANG}        = $new_language;
        $rc_lc_modified{RC_LC_MESSAGES} = $rc_lc_modified{RC_LANG};

        for (qw(RC_LANG RC_LC_MESSAGES)) {
            assert_script_run("sed -ie \'s/$_=\"$rc_lc_setup_const->{$_}\"/$_=\"$rc_lc_modified{$_}\"/\' $suse_lang_conf",
                fail_message => "Update of $suse_lang_conf failed!");
        }
    } else {
        ## suitable for sle15+ only
        assert_script_run("localectl set-locale LANG=$new_language");
        $rc_lc_modified{RC_LANG} = $new_language;
    }

    return \%rc_lc_modified;
}

sub test_users_locale {
    my $rc_lc_udpated   = shift;
    my $ldd_help_string = shift;

    record_info('Check', "Verifying $rc_lc_udpated->{RC_LANG}");
    ## Let's repeat the whole user login process again
    reset_consoles;
    select_console('user-console', ensure_tty_selected => 0, skip_setterm => 1);

    foreach my $line (split(/\n/, script_output("locale"))) {
        next if ($line =~ /^LC_ALL= *$/);
        diag "\nExpected = $rc_lc_udpated->{RC_LANG}\n";
        ($line =~ $rc_lc_udpated->{RC_LANG}) or die "Unexpected locale setting $line!\n";
    }

    my $lang_new_short          = substr($rc_lc_udpated->{RC_LANG}, 0, 5);
    my $ldd_help_string_updated = script_output("ldd --help | grep '^" . $test_lang_data{$lang_new_short} . "'");
    diag "\nOriginal = $ldd_help_string\nUpdated = $ldd_help_string_updated";
    record_info('glibc string', $ldd_help_string_updated);
    ($ldd_help_string ne $ldd_help_string_updated) or die "glibc strings do not differ!\n";
    type_string("exit\n");

    return $ldd_help_string_updated;
}

sub run {
    my ($self) = @_;
    # C<$lang_ref> denotes what kind of lang setting is expected from test suite perspective
    # sle15+ does not enable locale change during firstboot
    my $lang_ref = (is_sle('15+')) ? 'en_US' : get_var('JEOSINSTLANG', 'en_US');
    my $lang_new = ((get_required_var('TEST') =~ /de_DE/) && (is_sle('<15'))) ? 'en_US' : 'de_DE';
    my $rc_expected_data = {
        ROOT_USES_LANG => 'ctype',
        RC_LC_ALL      => qr/^ *$/,
        RC_LANG        => (is_sle('15+')) ? qr/^ *$/ : $lc_data{$lang_ref}
    };

    ## Retrieve user's $LANG env variable after JeOS firstboot
    select_console('user-console');
    clear_console;

    my $lang_booted       = script_output('echo $LANG');
    my $lang_booted_short = substr($lang_booted, 0, 5);

    diag "\nExpected = $lc_data{$lang_ref}\nGot = $lang_booted";
    die "User's language variable is set to $lang_booted, expected $lc_data{$lang_ref}!" if ($lc_data{$lang_ref} ne $lang_booted);

    ## Check glibc locale, should be the same as in firstrun module
    my $original_glibc_string = script_output("ldd --help | grep '^" . $test_lang_data{$lang_booted_short} . "'");
    record_info('glibc string', $original_glibc_string);
    type_string("exit\n");

    ## Check system wide locale configuration; general notes
    # 1) Verify RC_LC_ variables defined in the file /etc/sysconfig/language
    # 2) ROOT_USES_LANG specifies how to treat root locale setup; default value = 'ctype'
    # 3) RC_LC_ALL should be empty, otherwise overwrites the values of the above variables
    # 4) RC_LANG is fallback in case other RC_LC_* aren't set; Root uses this variable only if ROOT_USES_LANG="yes"
    # 5) Activate new settings:
    # bash reads /etc/profile which runs /etc/profile.d/lang.sh which analyzes /etc/sysconfig/language
    ## sle15+ perks
    # 1) RC_LC_* options are expected to be empty
    # 2) ROOT_USES_LANG="ctype"
    select_console('root-console');
    # it is expected that SLE12 has glibc preinstalled
    zypper_call('in glibc-locale') if (is_sle('15+'));

    my $output = script_output("localectl list-locales | grep $lang_new.utf8");
    die "Test locale not found in the available ones" unless ($output =~ $lang_new);

    # Parse and evaluate /etc/sysconfig/language
    die 'SUSE language config file is missing!' if (script_run("test -f $suse_lang_conf") != 0);
    my %rc_lc_setup = map {
        s/["']//g;
        s/\s+//g;
        my ($k, $v) = split(/=/, $_, 2);
        ($k => $v);
    } grep { /^\w+(_\w+)+/ } split(/\n/, script_output("cat $suse_lang_conf"));

    my $record_info_result = ($rc_lc_setup{RC_LC_ALL} =~ /^ *$/);
    my $total_result += $record_info_result;
    record_info('LC_ALL',
        "Expected to be empty\nRC_LC_ALL = $rc_lc_setup{RC_LC_ALL}\n",
        result => $record_info_result ? 'ok' : 'fail'
    );

    $record_info_result = ($rc_lc_setup{RC_LANG} =~ $rc_expected_data->{RC_LANG});
    $total_result += $record_info_result;
    record_info('LANG',
        "Expected to be $rc_expected_data->{RC_LANG}\nRC_LANG = $rc_lc_setup{RC_LANG}\n",
        result => $record_info_result ? 'ok' : 'fail'
    );

    $record_info_result = ($rc_lc_setup{ROOT_USES_LANG} eq $rc_expected_data->{ROOT_USES_LANG});
    $total_result += $record_info_result;
    record_info('ROOT_USES_LANG',
        "Expected to be \'ctype\'\nROOT_USES_LANG = $rc_lc_setup{ROOT_USES_LANG}\n",
        result => $record_info_result ? 'ok' : 'fail'
    );

    $record_info_result = ($rc_lc_setup{RC_LC_MESSAGES} =~ $rc_expected_data->{RC_LANG});
    $total_result += $record_info_result;
    record_info('LANG == LC_MESSAGES',
        "Expected to be the same\nRC_LANG=$rc_lc_setup{RC_LANG}\nLC_MESSAGES=$rc_lc_setup{RC_LC_MESSAGES}\n",
        result => $record_info_result ? 'ok' : 'fail'
    );

    $self->result('fail') unless ($total_result);

    my $rc_lc_changed        = change_locale($lc_data{$lang_new}, \%rc_lc_setup);
    my $updated_glibc_string = test_users_locale($rc_lc_changed, $original_glibc_string);

    ## Reboot and double check if the locale settings haven't changed
    power_action('reboot', textmode => 1);
    record_info('Rebooting', "Expected locale set=$rc_lc_changed->{RC_LANG}");
    $self->wait_boot;
    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1);
    ensure_serialdev_permissions;
    (test_users_locale($rc_lc_changed, $original_glibc_string) eq $updated_glibc_string) or die "Locale has changed after reboot!\n";

    if ($lang_new eq 'de_DE') {
        # Revert changes back to english
        $updated_glibc_string = test_users_locale(change_locale($lang_booted, $rc_lc_changed), $updated_glibc_string);
    }

    reset_consoles;
    ($updated_glibc_string =~ /$test_lang_data{en_US}/) or die "Exit locale settings have not been changed to english!\n";
}

1;
