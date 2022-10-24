# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: clamav
# Summary: check freshclam and clamscan against some fake virus samples
# - refresh the database using freshclam
# - change user vscan to root in clamd.conf (clamd runs as root)
# - start clamd and freshclam using systemctl
# - check that clamscan is able to recognize a fake vim virus
# - check that clamscan is able to recognize an EICAR virus pdf, txt and zip format
# - check that clamdscan is able to recognize an EICAR virus pdf, txt and zip format
#
# NOTE: As the vendor states, clamav needs at least 2GB of RAM to work smooth.
# To avoid interference and overload the openQA, the test is extracted from its
# original location and executed on its own dedicated test suites, qam-clamav
# for maintenance and extra_tests_clamav in functional.
#
# Maintainer: QE Security <none@suse.de>
# Tags: TC1595169, poo#46880, poo#65375, poo#80182

use base "consoletest";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use version_utils qw(is_jeos is_opensuse is_sle);

sub scan_and_parse {
    my $re = 'm/(eicar_test_files\/eicar.(pdf|txt|zip): Eicar-Test-Signature FOUND\n)+(\n.*)+Infected files: 3(\n.*)+/';
    my $cmd = shift;
    my $log_file = "$cmd.log";

    script_run "$cmd -i --log=$log_file eicar_test_files", 300;
    validate_script_output("cat $log_file", sub { $re });
    script_run "rm -f $log_file";
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call('in clamav vim');
    zypper_call('info clamav');

    # Check Clamav version
    # Jira ID SLE-16780: upgrade Clamav SLE
    my $current_ver = script_output("rpm -q --qf '%{version}' clamav");
    record_info("Clamav_ver", "Current Clamav package version: $current_ver");

    if (is_sle('>=15-SP3') && ($current_ver < 0.101)) {
        record_soft_failure("jsc#SLE-16780: upgrade Clamav SLE feature is not yet released");
    }

    # Initialize and download ClamAV database
    # First from local mirror, it's much faster, then from official clamav db
    my $host = is_sle ? 'openqa.suse.de' : 'openqa.opensuse.org';
    assert_script_run("sed -i '/mirror1/i PrivateMirror $host/assets/repo/cvd' /etc/freshclam.conf");
    assert_script_run('freshclam', timeout => 300);

    # clamd takes a lot of memory at startup so a swap partition is needed on JeOS
    # But openSUSE aarch64 JeOS has already a swap and BTRFS does not support swapfile
    if (is_jeos && !(is_opensuse && is_aarch64)) {
        assert_script_run("mkdir -p /var/lib/swap");
        assert_script_run("dd if=/dev/zero of=/var/lib/swap/swapfile bs=1M count=512");
        assert_script_run("mkswap /var/lib/swap/swapfile");
        assert_script_run("swapon /var/lib/swap/swapfile");
        my $swaps = script_output("cat /proc/swaps");
        die "Swapfile was not created succesfully" unless ($swaps =~ "swapfile");
    }

    # Verify the database
    assert_script_run 'sigtool -i /var/lib/clamav/main.cvd';
    assert_script_run 'sigtool -i /var/lib/clamav/bytecode.cvd';
    # CLD files are uncompressed and unsigned versions of the CVD that have had CDIFFs applied
    assert_script_run 'sigtool -i /var/lib/clamav/daily.cvd || sigtool -i /var/lib/clamav/daily.cld';

    # Clamd start timeout sometimes. The default systemd timeout is 90s,
    # override it with a longer duration in runtime.
    my $runtime_dir = '/run/systemd/system/clamd.service.d';
    assert_script_run "mkdir -p $runtime_dir";
    assert_script_run "echo -e \'[Service]\\nTimeoutSec=400\' > $runtime_dir/override.conf";
    systemctl('daemon-reload');

    # Start the deamons
    script_run("sed -i 's/User vscan/User root/g' /etc/clamd.conf");
    systemctl('start clamd', timeout => 400);
    systemctl('start freshclam');

    # Create md5, sha1 and sha256 Hash-based signatures
    # Assume /usr/bin/vim is an virus program and add its
    # signature to viruses database, then scan the virus
    for my $alg (qw(md5 sha1 sha256)) {
        assert_script_run "sigtool --$alg /usr/bin/vim > test.hdb";
        enter_cmd "clamscan -d test.hdb  /usr/bin/vim | tee /dev/$serialdev";
        die "Virus scan result was not expected" unless (wait_serial qr/vim\.UNOFFICIAL FOUND.*Known viruses: 1/ms);
    }

    # test 3 different file formats containing the EICAR signature
    assert_script_run "mkdir eicar_test_files";
    my $rel_path;
    for my $ext (qw(pdf txt zip)) {
        $rel_path = "eicar_test_files/eicar.$ext";
        assert_script_run("curl -o $rel_path " . data_url("$rel_path"));
    }

    scan_and_parse "clamscan";
    scan_and_parse "clamdscan";

    # Clean up
    script_run "rm -f test.hdb";
    script_run "rm -rf eicar_test_files/";
    systemctl('stop clamd freshclam', timeout => 500);
}

sub post_run_hook {
    assert_script_run("swapoff /var/lib/swap/swapfile") if is_jeos && !(is_opensuse && is_aarch64);
    systemctl('stop clamd', timeout => 500);
    systemctl('stop freshclam');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs('/etc/freshclam.conf');

}

sub test_flags {
    return {fatal => 0};
}

1;
