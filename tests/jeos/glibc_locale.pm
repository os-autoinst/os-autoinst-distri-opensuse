# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
use testapi;
use utils qw(zypper_call clear_console ensure_serialdev_permissions);
use version_utils qw(is_opensuse is_sle is_tumbleweed is_leap);
use power_action_utils qw(power_action);
use jeos qw(is_translations_preinstalled);

## Define test data
my $suse_lang_conf = '/etc/sysconfig/language';
my %lc_data = (en_US => 'en_US.UTF-8', de_DE => 'de_DE.UTF-8');
my %test_data_lang = (
    en_US => 'For bug reporting instructions, please see:',
    de_DE => 'Eine Anleitung zum Melden von Programmfehlern finden Sie hier:'
);

sub switch_user {
    # In aarch64 the user change takes some time, causing the next command to get
    # lost
    enter_cmd("su - $testapi::username", wait_still_screen => 10);
    validate_script_output('whoami', sub { m/$testapi::username/ });
}

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
        %rc_lc_modified = %$rc_lc_setup_const;
        $rc_lc_modified{LANG} = $new_language;
        $rc_lc_modified{LC_MESSAGES} = $rc_lc_modified{LANG};

        for (qw(LANG LC_MESSAGES)) {
            assert_script_run("sed -ie \'s/$_=\"$rc_lc_setup_const->{$_}\"/$_=\"$rc_lc_modified{$_}\"/\' $suse_lang_conf",
                fail_message => "Update of $suse_lang_conf failed!");
        }
    } else {
        ## suitable for sle15+ only
        assert_script_run("localectl set-locale LANG=$new_language");
        $rc_lc_modified{LANG} = $new_language;
    }

    return \%rc_lc_modified;
}

sub test_users_locale {
    my $rc_lc_udpated = shift;
    my $ldd_help_string_expected = shift;

    record_info('Check', "Verifying $rc_lc_udpated->{LANG}");
    # the whole user login process again should be repeated over here
    # as console switching can be expensive in openQA, it is enough to switch users
    switch_user;

    assert_script_run("locale | tee -a /dev/$serialdev | grep $rc_lc_udpated->{LANG}",
        fail_message => "Expected LANG ($rc_lc_udpated->{LANG}) has not been found!");

    my $ldd_help_string_updated = script_output "ldd --help";
    if ($ldd_help_string_updated =~ /([A-Z]\w+\s.*\w:)/) {
        $ldd_help_string_updated = $1;
    } else {
        die "Test string not found in *ldd* output\n";
    }
    record_info('Compare ldd', "\nExpected = $ldd_help_string_expected\nGot = $ldd_help_string_updated");

    ($ldd_help_string_expected eq $ldd_help_string_updated) or die "Unexpected locale settings, glibc test strings are not the same!\n";
    enter_cmd("exit");
    reset_consoles if is_sle('<15');
    return $ldd_help_string_updated;
}

sub test_lc_collate {
    my ($self, $locale) = @_;
    my $lang_csv = autoinst_url("/data/jeos/glibc_locale/lc_collate/$locale.csv");
    assert_script_run("curl -O $lang_csv");

    my $column_input = 1;
    my $column_expected_output = 2;

    my $dataset_expected_output = script_output("cut -d, -f$column_expected_output $locale.csv | tail -n +2");

    validate_script_output(
        "cut -d, -f$column_input $locale.csv | tail -n +2 | LC_ALL=$locale LC_CTYPE=$locale LC_COLLATE=$locale sort",
        sub {
            my $out = $_;
            $out =~ s/\r//g;
            $out =~ s/\n/,/g;
            $out =~ s/,\z//;

            my $exp = $dataset_expected_output;
            $exp =~ s/\r//g;
            $exp =~ s/\n/,/g;
            $exp =~ s/,\z//;

            $out eq $exp;
        },
        title => "LC_COLLATE (sorting)",
        fail_message => "Sorted order does not match expected CSV"
    );

    assert_script_run("rm -f $locale.csv");
}

sub test_lc_numeric {
    my ($self, $locale) = @_;
    my $url = autoinst_url("/data/jeos/glibc_locale/lc_numeric/$locale.csv");
    assert_script_run("curl -f -O $url");

    my $column_input = 1;
    my $column_expect = 2;

    my $expected = script_output("cut -d'|' -f$column_expect $locale.csv | tail -n +2 | tr -d '\\r'");

    my $cmd = qq{
        cut -d'|' -f$column_input $locale.csv | tail -n +2 | tr -d '\\r' | LC_ALL= LC_NUMERIC=$locale gawk --use-lc-numeric '{printf("%.2f\\n", \$1)}'
    };

    validate_script_output(
        $cmd,
        sub {
            my $out = $_;
            $out =~ s/\r//g; chomp $out;
            (my $exp = $expected) =~ s/\r//g;
            chomp $exp;
            $out eq $exp;
        },
        title => "LC_NUMERIC (decimal formatting)",
        fail_message => "Formatted numbers don't match expected"
    );

    assert_script_run("rm -f $locale.csv");
}

sub test_lc_monetary {
    my ($self, $locale) = @_;

    my $csv_url = autoinst_url("/data/jeos/glibc_locale/lc_monetary/$locale.csv");
    assert_script_run("curl -f -O $csv_url");

    my $expected_output = script_output("cat $locale.csv");

    validate_script_output(
        "LC_ALL=$locale LC_CTYPE=$locale LC_MONETARY=$locale locale currency_symbol",
        sub { m/$expected_output/ },
        title => "LC_MONETARY currency_symbol",
        fail_message => "Expected currency symbol '$expected_output' not found, got '$_'"
    );

    assert_script_run("rm -f $locale.csv");
}

sub test_lc_time {
    my ($self, $locale) = @_;

    my $csv_url = autoinst_url("/data/jeos/glibc_locale/lc_time/$locale.csv");
    assert_script_run("curl -f -O $csv_url");

    my $csv = script_output("tr -d '\\r' < $locale.csv");
    my @lines = grep { length } split /\n/, $csv;
    my $header = shift @lines;

    my $sep = (index($header, '|') >= 0) ? qr/\|/ : qr/,/;

    for my $i (0 .. $#lines) {
        my ($epoch, $fmt, $expected) = split $sep, $lines[$i], 3;

        my $cmd = qq{LC_ALL=$locale LC_CTYPE=$locale LC_TIME=$locale TZ=UTC date -u -d '\@$epoch' +"$fmt"};

        validate_script_output(
            $cmd,
            sub {
                my $out = $_; $out =~ s/\r//g;
                chomp $out;
                $out eq $expected;
            },
            title => "LC_TIME $fmt (line " . ($i + 2) . ")",
            fail_message => "Line " . ($i + 2) . ": expected '$expected', got '$_'"
        );
    }

    assert_script_run("rm -f $locale.csv");
}

sub run_lc_tests_for_locale {
    my ($self, $locale) = @_;
    record_info($locale);
    $self->test_lc_collate($locale);
    $self->test_lc_monetary($locale);
    $self->test_lc_time($locale);
    $self->test_lc_numeric($locale);
}

sub run_lc_tests {
    my ($self) = @_;
    for my $locale (qw(en_US.UTF-8 de_DE.UTF-8 sv_SE.UTF-8 da_DK.UTF-8 zh_CN.UTF-8)) {
        $self->run_lc_tests_for_locale($locale);
    }
}

sub run {
    my ($self) = @_;
    # C<$lang_ref> denotes what kind of lang setting is expected from test suite perspective
    # sle15+ does not enable locale change during firstboot
    my $lang_ref = (is_translations_preinstalled() && !get_var("JEOSINSTLANG_FORCE_LANG_EN_US", 0)) ? get_var('JEOSINSTLANG', 'en_US') : 'en_US';
    my $lang_new_short = ((get_required_var('TEST') =~ /de_DE/) && (is_sle('<15'))) ? 'en_US' : 'de_DE';
    my $rc_expected_data = {
        ROOT_USES_LANG => 'ctype',
        LC_ALL => qr/^ *$/,
        LANG => (is_sle('15+') || is_leap) ? qr/^ *$/ : $lc_data{$lang_ref}
    };

    ## Retrieve user's $LANG env variable after JeOS firstboot
    select_console('user-console');
    clear_console;

    my $lang_booted = script_output('echo $LANG');
    my $lang_booted_short = substr($lang_booted, 0, 5);

    diag "\nExpected = $lc_data{$lang_ref}\nGot = $lang_booted";
    die "User's language variable is set to $lang_booted, expected $lc_data{$lang_ref}!" if ($lc_data{$lang_ref} ne $lang_booted);

    ## Check glibc locale, should be the same as in firstrun module
    my $original_glibc_string = script_output("ldd --help | grep '^" . $test_data_lang{$lang_booted_short} . "'");
    record_info('Original', $original_glibc_string);
    enter_cmd("exit");

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
    my @pkgs = qw(glibc-locale);
    push @pkgs, 'glibc-lang' if (is_tumbleweed || is_sle('>15-sp2') || is_leap('>15.2'));
    zypper_call("install @pkgs") if (is_sle('15+') || is_opensuse);

    my $output = script_output("localectl list-locales | tee -a /dev/$serialdev | grep -E '$lang_new_short\.(UTF-8|utf8)'");
    die "Test locale not found in the available ones" unless ($output =~ $lang_new_short);

    $self->run_lc_tests();

    # Parse and evaluate /etc/sysconfig/language
    # /etc/sysconfig/language is no longer used in Tumbleweed
    my @locale_conf;
    if (is_tumbleweed) {
        @locale_conf = split('\n', script_output('locale'));
    } else {
        die 'SUSE language config file is missing!' if (script_run("test -f $suse_lang_conf") != 0);
        # keep only uncommented lines
        @locale_conf = grep { /^[A-Z].*$/ } split('\n', script_output("cat $suse_lang_conf"));
    }

    my %rc_lc_defaults = map {
        s/["']//g;
        s/\s+//g;
        s/RC_//g;
        my ($k, $v) = split(/=/, $_, 2);
        "$k" => $v;
    } @locale_conf;

    my $checks = 1;
    my $total_result = 0;
    my $record_info_result = (exists($rc_lc_defaults{LC_ALL}) && $rc_lc_defaults{LC_ALL} =~ /^ *$/);
    my $total_result += $record_info_result;
    record_info('LC_ALL',
        "Expected to be empty\nRC_LC_ALL = $rc_lc_defaults{LC_ALL}\n",
        result => $record_info_result ? 'ok' : 'fail'
    );

    $record_info_result = (exists($rc_lc_defaults{LANG}) && $rc_lc_defaults{LANG} =~ $rc_expected_data->{LANG});
    $total_result += $record_info_result;
    $checks++;
    record_info('LANG',
        "Expected to be $rc_expected_data->{LANG}\nRC_LANG = $rc_lc_defaults{LANG}\n",
        result => $record_info_result ? 'ok' : 'fail'
    );

    # ROOT_USES_LANG is not defined any more for TW
    if (!is_tumbleweed) {
        $checks++;
        $record_info_result = (exists($rc_lc_defaults{ROOT_USES_LANG}) && $rc_lc_defaults{ROOT_USES_LANG} eq $rc_expected_data->{ROOT_USES_LANG});
        $total_result += $record_info_result;

        record_info('ROOT_USES_LANG',
            "Expected to be \'ctype\'\nROOT_USES_LANG = $rc_lc_defaults{ROOT_USES_LANG}\n",
            result => $record_info_result ? 'ok' : 'fail'
        );
    }

    $record_info_result = (exists($rc_lc_defaults{LC_MESSAGES}) && $rc_lc_defaults{LC_MESSAGES} =~ $rc_expected_data->{LANG});
    $total_result += $record_info_result;
    $checks++;
    record_info('LANG == LC_MESSAGES',
        "Expected to be the same\nRC_LANG=$rc_lc_defaults{LANG}\nLC_MESSAGES=$rc_lc_defaults{LC_MESSAGES}\n",
        result => $record_info_result ? 'ok' : 'fail'
    );

    if (my $r = $checks - $total_result) {
        $self->result('fail');
        record_info("Fails", "Number of failed checks: $r", result => 'fail');
    }

    ## Modify default locale, verify new setup, reboot and repeat verification
    my $rc_lc_changed = change_locale($lc_data{$lang_new_short}, \%rc_lc_defaults);
    my $updated_glibc_string = test_users_locale($rc_lc_changed, $test_data_lang{$lang_new_short});
    power_action('reboot', textmode => 1);
    record_info('Rebooting', "Expected locale set=$rc_lc_changed->{LANG}");
    $self->wait_boot;
    select_console('root-console', skip_set_standard_prompt => 1, skip_setterm => 1);
    ensure_serialdev_permissions;
    (test_users_locale($rc_lc_changed, $test_data_lang{$lang_new_short}) eq $updated_glibc_string) or die "Locale has changed after reboot!\n";

    return if (is_sle('<15'));

    ## Revert locales to default and verify
    my $rc_lc_reverted = change_locale($lc_data{$lang_booted_short}, $rc_lc_changed);
    my $reverted_glibc_string = test_users_locale($rc_lc_reverted, $test_data_lang{$lang_ref});
    power_action('reboot', textmode => 1);
    record_info('Rebooting', "Expected locale set=$rc_lc_reverted->{LANG}");
    $self->wait_boot;
    select_console('root-console');
    ensure_serialdev_permissions;
    (test_users_locale($rc_lc_reverted, $test_data_lang{$lang_ref}) eq $original_glibc_string) or die "Locale has changed after reboot!\n";
    reset_consoles;
}

sub post_fail_hook {
    # print debug info
    enter_cmd 'locale';
    enter_cmd 'localectl';
    enter_cmd 'loginctl';
    shift->SUPER::post_fail_hook;
}

1;
