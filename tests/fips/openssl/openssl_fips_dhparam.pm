# openssl fips test
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: testing openSSL dhparam and
# s_client/s_server with DHE when in FIPS mode.
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_sle is_sle_micro is_transactional);
use security::openssl_misc_utils;

sub create_user {
    my $user = $testapi::username;
    my $password = $testapi::password;
    if (script_run("getent passwd $user") != 0) {
        assert_script_run "useradd -m $user";
        assert_script_run "echo '$user:$password' | chpasswd";
    }
    # Make sure user has access to tty group
    my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
    assert_script_run "grep '^${serial_group}:.*:${user}\$' /etc/group || (chown $user /dev/$testapi::serialdev && gpasswd -a $user $serial_group)";
}

sub run_fips_dhparam_tests {
    my $openssl_binary = shift // "openssl";
    my $openssl_output = '/tmp/openssl_output';
    # SLE Micro doesn't have user created by default
    create_user if is_transactional;

    assert_script_run "$openssl_binary req -newkey rsa:2048 -nodes -keyout generatedkey.key -x509 -days 365 -out generatedcert.crt -subj \"/C=DE/L=Nue/O=SUSE/CN=security.suse.de\"", timeout => 300;
    assert_script_run "$openssl_binary dhparam -out dhparams_2048.pem 2048";
    clear_console;

    my $server_pid = background_script_run("$openssl_binary s_server -key generatedkey.key -cert generatedcert.crt -dhparam dhparams_2048.pem -cipher DHE --accept 44330");

    clear_console;
    validate_script_output "echo | $openssl_binary s_client -connect localhost:44330", sub { m/CONNECTED.*/ };

    assert_script_run("kill $server_pid");
}

sub run {
    select_console 'root-console';
    install_openssl;
    my $ver = get_openssl_full_version;
    record_info("Testing OpenSSL $ver");
    run_fips_dhparam_tests;
    if (is_sle('>=15-SP6') && is_sle('<16')) {
        $ver = get_openssl_full_version(OPENSSL1_BINARY);
        record_info("Testing OpenSSL $ver");
        run_fips_dhparam_tests(OPENSSL1_BINARY);
    }
}

sub test_flags {
    return {
        #poo160197 workaround since rollback seems not working with swTPM
        no_rollback => is_transactional ? 1 : 0,
        fatal => 0
    };
}

1;
