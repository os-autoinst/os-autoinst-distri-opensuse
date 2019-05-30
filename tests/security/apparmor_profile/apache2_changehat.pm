# Copyright (C) 2019 SUSE LLC
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
#
# Summary: Test Web application apache2 using ChangeHat
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#48773, tc#1695946

use base apparmortest;
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);
use registration qw(add_suseconnect_product register_product);

sub run {
    my ($self) = shift;

    my $audit_log    = $apparmortest::audit_log;
    my $prof_dir     = $apparmortest::prof_dir;
    my $adminer_file = $apparmortest::adminer_file;
    my $adminer_dir  = $apparmortest::adminer_dir;
    my $pw           = $apparmortest::pw;

    my $apache2_err_log    = "/var/log/apache2/error_log";
    my $apparmor_conf_file = "/etc/apache2/conf.d/apparmor.conf";
    my $profile_name       = "usr.sbin.httpd-prefork";
    my $named_profile      = "";

    # Disable apparmor in case
    systemctl("stop apparmor");
    if (is_sle('15+') or is_tumbleweed()) {
        assert_script_run("aa-teardown");
    }

    # Install needed modules and Apache packages
    if (is_sle) {
        register_product();
        my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
        if ($version == '15') {
            $version = get_required_var('VERSION') =~ s/([0-9]+)-SP([0-9]+)/$1.$2/r;
        }
        my $arch    = get_required_var('ARCH');
        my $params  = " ";
        my $timeout = 180;
        add_suseconnect_product("sle-module-web-scripting", "$version", "$arch", "$params", "$timeout");
    }
    zypper_call("in apache2 apache2-mod_apparmor apache2-mod_php7 php7 php7-mysql");

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

    # Upload logs for reference
    upload_logs("/var/log/apache2/error_log");
    upload_logs("$audit_log");
}

1;
