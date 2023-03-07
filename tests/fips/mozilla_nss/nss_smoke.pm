# SUSE's NSSFips tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Smoke test for NSS on FIPS sytems
# Maintainer: qa-c team <qa-c@suse.de>
#             QE Security

use Mojo::Base qw(consoletest);
use testapi;
use version_utils qw(is_sle is_transactional);
use transactional qw(trup_call process_reboot);
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    my $zypper_options;
    my $pass_file = '/root/password.txt';
    my $seed_file = '/root/seedfile.dat';
    my $cert_file = '/root/cert9.cer';
    my $nssdb_dir = '/root/nssdb';
    my $details = "\"CN=Daniel Duesentrieb3,O=Example Corp,L=Mountain View,ST=California,C=DE\" -d \"$nssdb_dir\" -o $cert_file -f $pass_file -z $seed_file";

    if (my $devel_repo = get_var('MOZILLA_NSS_DEVEL_REPO')) {
        zypper_call("ar $devel_repo nss_dev_repo");
        zypper_call("--gpg-auto-import-keys ref", 180);
        record_info('repos', script_output('zypper lr -u'));
        $zypper_options = "--from nss_dev_repo";
    }

    if (is_transactional) {
        trup_call("pkg install $zypper_options mozilla-nss mozilla-nss-tools");
        process_reboot(trigger => 1);
    } else {
        zypper_call("in $zypper_options mozilla-nss mozilla-nss-tools");
    }
    record_info('mozilla-nss', script_output('rpm -q mozilla-nss'));
    record_info('mozilla-nss-tools', script_output('rpm -q mozilla-nss-tools'));

    assert_script_run('cat /dev/urandom | head -n 120 > /root/seedfile.dat');
    record_info('seedfile', script_output('cat /root/seedfile.dat'));
    assert_script_run('touch ' . $pass_file);
    assert_script_run('mkdir -p /root/nssdb');
    assert_script_run('certutil -N -d "/root/nssdb" --empty-password');
    assert_script_run('export NSS_FIPS=1');
    enter_cmd('modutil -fips true -dbdir "/root/nssdb"');
    wait_serial(qr/'q <enter>' to abort, or <enter> to continue:/, timeout => 60) or die "Didn't get any output from moduitl";
    send_key 'ret';

    # This should fail on FIPS
    validate_script_output('certutil -R -k rsa -g 1024 -s ' . $details, sub { m/SEC_ERROR_INVALID_ARGS/ }, proceed_on_failure => 1);
    record_info('cert file', script_output("file $cert_file"));
    script_run("[ -s $cert_file ]") != 0 or die("The certification file $cert_file should be empty.");

    # This should work on FIPS
    assert_script_run('certutil -R -k rsa -g 2048 -s ' . $details);
    record_info('cert file', script_output("file $cert_file"));
    script_run("[ -s $cert_file ]") == 0 or die("The certification file $cert_file should contain data.");
}

1;
