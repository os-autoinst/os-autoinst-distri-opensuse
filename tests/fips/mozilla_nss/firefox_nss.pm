# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Case #1560076 - FIPS: Firefox Mozilla NSS
#
# Package: MozillaFirefox
# Summary: FIPS mozilla-nss test for firefox : firefox_nss
#
# Maintainer: QE Security <none@suse.de>
# Tag: poo#47018, poo#58079, poo#71458, poo#77140, poo#77143,
#      poo#80754, poo#104314, poo#104989, poo#105343

use base "x11test";
use testapi;
use utils;
use Utils::Architectures;
use version_utils 'is_sle';

sub quit_firefox {
    send_key "alt-f4";
    assert_screen([qw(firefox-save-and-quit generic-desktop)]);
    if (match_has_tag 'firefox-save-and-quit') {
        assert_and_click("firefox-click-close-tabs");
    }
}

sub firefox_crashreporter {

    select_console 'root-console';

    my $firefox_crash_dir = '/home/bernhard/.mozilla/firefox/Crash\ Reports';
    my $crash_report = '/home/bernhard/.mozilla/firefox/Crash\ Reports/crashreporter.ini';

    assert_script_run("ls $firefox_crash_dir");

    # poo#162971 fail if crashreporter.ini not found
    if (script_run "test -f $crash_report") {
        record_soft_failure "bsc#1223724";
        force_soft_failure "bsc#1223724";
    }

    assert_script_run("sed -i -e 's/EmailMe=0/EmailMe=1/g' $crash_report");
    assert_script_run("sed -i -e 's/SubmitReport=0/SubmitReport=1/g' $crash_report");
    assert_script_run("cat $crash_report");
    assert_script_run("cat $crash_report | grep 'EmailMe=1'");
    assert_script_run("cat $crash_report | grep 'SubmitReport=1'");

    upload_logs($crash_report, failok => 1);
}

sub firefox_preferences {
    send_key "alt-e";
    wait_still_screen 5;
    send_key "n";
    assert_screen("firefox-preferences");
    wait_still_screen 2, 4;
}

sub search_certificates {
    type_string "certificates", timeout => 20, max_interval => 40;
    send_key "tab";
    wait_still_screen 2, 4;
}

sub select_master_password_option {
    my ($ff_ver) = @_;

    firefox_preferences;
    # Search "Passwords" section
    if ($ff_ver >= 91) {
        type_string "Use a primary", timeout => 15, max_interval => 40;
    }
    else {
        type_string "Use a master", timeout => 15, max_interval => 40;
    }
    assert_and_click("firefox-master-password-checkbox");
    assert_screen("firefox-passwd-master_setting");
}

sub set_master_password {
    my ($password, $needle_name) = @_;

    type_string $password;
    send_key "tab";
    type_string $password;
    send_key "ret";
    assert_screen("$needle_name");
    send_key "ret";
    wait_still_screen 2;
}

sub run {
    my ($self) = @_;
    select_console 'root-console';

    my $firefox_version = script_output(q(rpm -q MozillaFirefox | awk -F '-' '{ split($2, a, "."); print a[1]; }'));
    record_info('MozillaFirefox version', "Version of Current MozillaFirefox package: $firefox_version");

    # mozilla-nss version check
    my $pkg_list = {
        'mozilla-nss' => '3.68',
        'mozilla-nss-certs' => '3.68',
    };

    if (get_var('FIPS_ENABLED') && !is_sle('<15-sp4')) {
        zypper_call("in " . join(' ', keys %$pkg_list));
        package_upgrade_check($pkg_list);
    }
    else {
        my $mozilla_nss_ver = script_output("rpm -q --qf '%{version}\n' mozilla-nss");
        record_info('mozilla-nss version', "Version of Current package: $mozilla_nss_ver");
    }
    clear_console;
    select_console 'x11';
    x11_start_program('firefox https://html5test.opensuse.org', target_match => 'firefox-html-test', match_timeout => 360);

    # Define FIPS password for firefox, and it should be consisted by:
    # - at least 8 characters
    # - at least one upper case
    # - at least one non-alphabet-non-number character (like: @-.=%)
    my $fips_strong_password = 'openqa@SUSE';
    my $fips_weak_password = 'asdasd';

    # Set the Master Password and check behaviour when a weak pwd is set (poo#125420)
    select_master_password_option $firefox_version;
    set_master_password("$fips_weak_password", "firefox-weak-password-error");

    select_master_password_option $firefox_version;
    set_master_password("$fips_strong_password", "firefox-password-change-succeeded");

    send_key "ctrl-f";
    send_key "ctrl-a";

    # Search "Certificates" section
    search_certificates;

    # Change from "alt-shift-d" hotkey to needles match Security Device
    # send_key "alt-shift-d" is fail to react in s390x/aarch64 usually
    assert_and_click("firefox-click-security-device");
    assert_screen "firefox-device-manager";
    save_screenshot;
    # on s390x the dialog with Security Modules and Devices is colored wrong
    # https://bugzilla.suse.com/show_bug.cgi?id=1203578
    record_soft_failure("bsc#1209107") if is_s390x;

    # Add condition in FIPS_ENV_MODE & Remove hotkey
    if (get_var('FIPS_ENV_MODE')) {
        assert_and_click("firefox-click-enable-fips", timeout => 2);
    }

    # Enable FIPS mode
    # Remove send_key "alt-shift-f";
    assert_screen("firefox-confirm-fips_enabled");
    send_key "esc";    # Quit device manager

    # Close Firefox
    quit_firefox;

    # Add more time for aarch64 due to worker performance problem
    my $waittime = 60;
    $waittime += 60 if is_aarch64;
    assert_screen("generic-desktop", $waittime);

    # Use the ps check if the bug happened bsc#1178552
    # Add the ps to list which process is not closed while timeout
    select_console 'root-console';

    my $ret = script_run("ps -ef | grep firefox | grep childID | wc -l | grep '0'");
    diag "---$ret---";
    if ($ret == 1) {
        script_run('ps -ef | grep firefox');
        diag "---ret_pass---";
        record_info('Firefox_ps', "Firefox process is already closed.");
    }
    else {
        script_run('ps -ef | grep firefox | grep childID');
        diag "---ret_fail---";
        die 'firefox is not correctly closed';
    }

    select_console 'x11', await_console => 0;    # Go back to X11
    wait_still_screen 2;    # wait sec after switch before pressing keys

    # "start_firefox" will be not used, since the master password is
    # required when firefox launching in FIPS mode
    # x11_start_program('firefox --setDefaultBrowser https://html5test.opensuse.org', target_match => 'firefox-fips-password-inputfiled', match_timeout => 180);
    # Adjust the 2nd Firefox launch via xterm as workaround to avoid the race condition during password interaction while internet connection busy
    x11_start_program('xterm');
    mouse_hide(1);
    enter_cmd("firefox --setDefaultBrowser https://html5test.opensuse.org");
    wait_still_screen 10;
    if (check_screen("firefox-passowrd-typefield")) {
        wait_still_screen 4;

        # Add max_interval while type password and extend time of click needle match
        type_string($fips_strong_password, timeout => 10, max_interval => 30);
        send_key 'ret', wait_screen_change => 1;    # Confirm password

        wait_still_screen 30;

        # Add a condition to avoid the password missed input
        # Retype password again once the password missed input
        # The problem frequently happened in aarch64
        if (check_screen("firefox-password-typefield-miss")) {
            record_info("aarch64 type_missing", "Firefox password is missing to input, please refer to bsc#1179749 & poo#105343");
            type_string($fips_strong_password, timeout => 10, max_interval => 30);
            send_key "ret";
        }
    }
    else {

        firefox_crashreporter;
    }

    if (is_sle('<=15-SP3') && check_screen("firefox-password-required-prompt")) {
        type_string($fips_strong_password, timeout => 10, max_interval => 30);
        send_key "ret";
    }

    assert_screen("firefox-url-loaded", $waittime);

    # Firefox Preferences
    firefox_preferences;
    # Search "Certificates" section
    search_certificates;

    # Change from "alt-shift-d" hotkey to needles match Security Device
    # send_key "alt-shift-d" is fail to react in s390x/aarch64 usually
    assert_and_click("firefox-click-security-device");
    assert_screen("firefox-device-manager");
    # on s390x the dialog with Security Modules and Devices is colored wrong
    # https://bugzilla.suse.com/show_bug.cgi?id=1203578
    if (is_s390x) {
        record_soft_failure("bsc#1209107");
    } else {
        assert_screen("firefox-confirm-fips_enabled");
    }
    save_screenshot;
    # Close Firefox
    quit_firefox;
    assert_screen("generic-desktop", $waittime);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}
1;
