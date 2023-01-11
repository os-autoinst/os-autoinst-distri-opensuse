# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-parser apache2-mod_apparmor apparmor-utils
# Summary: Test Web application apache2 using ChangeHat.
# - Stops apparmor daemon
# - if sle 15+ or tumbleweed, runs aa-teardown
# - if sle, add sle-module-web-scripting module
# - Install apache2 apache2-mod_apparmor apache2-mod_php7 php7 php7-mysql
# - Restarts apparmor daemon
# - Setup mariadb using mariadb_setup function
# - Setup Web environment for Adminer using adminer_setup
# - Run a2enmod apparmor
# - run "echo '<Directory /srv/www/htdocs/adminer>' >
# /etc/apache2/conf.d/apparmor.conf"
# - run "echo 'AAHatName adminer' >> /etc/apache2/conf.d/apparmor.conf"
# - run "echo '</Directory>' >> /etc/apache2/conf.d/apparmor.conf"
# - restart apache daemon
# - if sle is 12+, to $profile_name (usr.sbin.httpd-prefork) "-sle12" will be added
# - Download a pre-build profile (using the rule above) from data_dir and save it in /etc/apparmor.d
# - restart apparmor daemon
# - Check if apparmor was properly activated
# - run aa-enforce $profile_name, check for "Setting .*$profile_name to enforce
# mode" output
# - get test profile name by calling get_named_profile
# - check if profile is running in enforce mode by calling aa_status_stdout_check
# - restart apache2
# - drop adminer database by calling adminer_database_delete
# - Opens audit.log and check for messages:
#   - if "type=AVC .*apparmor=.*DENIED.* operation=.*change_hat.*" is found,
#   record error message in log: "ERROR", "There are denied change_hat records
#   found in $audit_log" and fail test.
#   - if "type=AVC .*apparmor=.*DENIED.* operation=.*profile_replace.*
#   profile=.*httpd-prefork.*adminer.*" is found, record error message in test
#   log: ""ERROR", "There are denied profile_replace records found in
#   $audit_log" and fail test.
# - upload /var/log/apache2/error_log and audit.log
# Maintainer: QE Security <none@suse.de>
# Tags: poo#48773, tc#1695946, poo#111036


use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_alp is_tumbleweed);
use registration qw(add_suseconnect_product register_product);

sub run {
    my ($self) = shift;

    my $audit_log = $apparmortest::audit_log;
    my $prof_dir = $apparmortest::prof_dir;
    my $adminer_file = $apparmortest::adminer_file;
    my $adminer_dir = $apparmortest::adminer_dir;
    my $pw = $apparmortest::pw;

    my $apache2_err_log = "/var/log/apache2/error_log";
    my $apparmor_conf_file = "/etc/apache2/conf.d/apparmor.conf";
    my $profile_name = "usr.sbin.httpd-prefork";
    my $named_profile = "";

    # Disable apparmor in case
    systemctl("stop apparmor");
    if (is_sle('15+') or is_tumbleweed()) {
        assert_script_run("aa-teardown");
    }

    # Install needed modules and Apache packages
    if (is_sle && get_var('FLAVOR') !~ /Updates|Incidents/) {
        register_product();
        my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
        if ($version == '15') {
            $version = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
        }
        my $arch = get_required_var('ARCH');
        my $params = " ";
        my $timeout = 180;
        add_suseconnect_product("sle-module-web-scripting", "$version", "$arch", "$params", "$timeout");
        add_suseconnect_product("sle-module-legacy", "$version", "$arch", "$params", "$timeout");
    }

    if (is_sle(">=15-SP4") || is_leap(">15.4") || is_tumbleweed() || is_alp()) {
        zypper_call("in apache2 apache2-mod_apparmor apache2-mod_php8 php8 php8-mysql");
    } else {
        zypper_call("in apache2 apache2-mod_apparmor apache2-mod_php7 php7 php7-mysql");
    }

    # Restart apparmor
    systemctl("restart apparmor");

    # Install Mariadb and setup database test account
    $self->mariadb_setup();

    # Set up Web environment for running Adminer
    $self->adminer_setup();

    # Configure Apache's mod_apparmor, so that AppArmor can detect
    # accesses to Adminer and change to the specific “hat”
    assert_script_run("a2enmod apparmor");
    assert_script_run("echo '<Directory /srv/www/htdocs/adminer>' > $apparmor_conf_file");
    assert_script_run("echo 'AAHatName adminer' >> $apparmor_conf_file");
    assert_script_run("echo '</Directory>' >> $apparmor_conf_file");
    # Then, restart Apache
    systemctl("restart apache2");

    # Apache now knows about the Adminer and changing a “hat” for it,
    # It is time to create the related hat for Adminer,
    # NOTE: Apache's main binary is /usr/sbin/httpd-prefork on this testing OS

    # Download Apache's main binary's profile and copy it to "/etc/apparmor.d/"
    my $profile_name_new;
    if (is_sle('12+')) {
        $profile_name_new = $profile_name . "-sle12";
    }
    else {
        $profile_name_new = $profile_name . "";
    }
    assert_script_run("wget --quiet " . data_url("apparmor/$profile_name_new") . " -O $prof_dir/$profile_name");

    # Restart apparmor
    systemctl("restart apparmor");
    validate_script_output("systemctl is-active apparmor", sub { m/active/ });
    # Output status for debug
    systemctl("status apparmor");

    # Set the AppArmor security profile to enforce mode
    validate_script_output("aa-enforce $profile_name", sub { m/Setting .*$profile_name to enforce mode./ });
    # Recalculate profile name in case
    $named_profile = $self->get_named_profile($profile_name);
    # Check if $profile_name is in "enforce" mode
    $self->aa_status_stdout_check($named_profile, "enforce");

    # Cleanup audit log
    assert_script_run("echo > $audit_log");
    assert_script_run("echo '=== separation line for reference ===' >> /var/log/apache2/error_log");

    # Then, restart Apache
    systemctl("restart apache2");

    # Do some operations on Adminer web, e.g., log in, select/delete a database
    $self->adminer_database_delete();

    # Verify audit log contains no "DENIED" "adminer" change hat opertions.
    # NOTE: There may have some "DENIED" records but we only interest in
    # "change_hat" and "profile_replace" ones
    my $script_output = script_output("cat $audit_log");
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* operation=.*change_hat.*/sx) {
        record_info("ERROR", "There are denied change_hat records found in $audit_log", result => 'fail');
        $self->result('fail');
    }
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* operation=.*profile_replace.* profile=.*httpd-prefork.*adminer.*/sx) {
        record_info("ERROR", "There are denied profile_replace records found in $audit_log", result => 'fail');
        $self->result('fail');
    }
    # Due to bsc#1191684, add following check points as well
    my @check_list = ('file_receive', 'open', 'signal', 'mknod');
    foreach my $check_point (@check_list) {
        if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* operation=.*$check_point.* profile=.*httpd-prefork.*/sx) {
            if (is_sle('>15-SP4')) {
                record_info("ERROR", "There are denied $check_point records found in $audit_log", result => 'fail');
                $self->result('fail');
            }
            else {
                record_soft_failure('bsc#1191684 - Apparmor profile test case "apache2_changehat" found some "DENIED" audit records');
            }
        }
    }

    # Upload logs for reference
    upload_logs("/var/log/apache2/error_log");
    upload_logs("$audit_log");
}

1;
