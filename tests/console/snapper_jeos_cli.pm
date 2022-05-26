# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper coreutils
# Summary: Snapshot creation and rollback on JeOS
# Maintainer: Ciprian Cret <ccret@suse.com>

use Mojo::Base qw(consoletest);
use testapi;
use Utils::Architectures;
use utils;
use power_action_utils qw(power_action);
use Utils::Systemd qw(systemctl);

sub check_package
{
    my ($not_installed, $pkgname, $check_path) = @_;
    my $error = 'Package is ' . ($not_installed ? ' ' : ' not ') . ' installed';
    my $ret = script_run("rpm -q $pkgname");
    die($error) if ($not_installed) ? !$ret : $ret;
    $ret = script_run("ls -l $check_path");
    die($error) if ($not_installed) ? !$ret : $ret;
    $ret = script_run("$pkgname --help");
    die($error) if ($not_installed) ? !$ret : $ret;
}

=head2 rollback_and_reboot

    End2end flow for snapper to rollback

=cut
sub rollback_and_reboot {
    my ($self, $rollback_id) = @_;
    assert_script_run("snapper rollback $rollback_id");
    assert_script_run("snapper list");
    power_action('reboot');
    if (is_aarch64) {
        $self->wait_boot(bootloader_time => 300);
    }
    else {
        $self->wait_boot;
    }
    select_console('root-console');
    assert_script_run("snapper list");
    # check whether SUSEConnect --rollback is running executed by rollback-reset-registration
    # this might cause a system management lock by zypper
    for (my $runs = 1; $runs < 11; $runs++) {
        if (script_run('test -f /var/lib/rollback/check-registration') == 1) {
            return 1;
        }
        record_info('ps', script_output('ps -ef'));
        systemctl 'status rollback.service';
        bmwqemu::diag("SUSEConnect --rollback is still running, or failing [$runs/10]");
        sleep 60;
    }
    die "SUSEConnect --rollback is running longer than expected";
}

sub run {
    my ($self) = @_;

    select_console('root-console');
    my $file = '/etc/openQA_snapper_test';
    my $pkgname = 'zsh';
    my $check_path = '/usr/share/zsh/functions';
    my $openqainit = script_output("snapper create -p -d openqainit");

    assert_script_run("head -c 10000 < /dev/urandom > $file");
    my $checksum_orig = script_output("sha256sum $file");
    check_package(1, $pkgname, $check_path);
    zypper_call("in $pkgname");
    check_package(0, $pkgname, $check_path);
    my $openqalatest = script_output("snapper create -p -d openqalatest");
    assert_script_run("snapper list");

    $self->rollback_and_reboot($openqainit);
    assert_script_run("! ls -l $file");
    check_package(1, $pkgname, $check_path);

    $self->rollback_and_reboot($openqalatest);
    my $checksum = script_output("sha256sum $file");
    die("Restored file sha256 checksum didn't match") if $checksum_orig ne $checksum;
    assert_script_run("rm -v $file");

    $self->rollback_and_reboot($openqainit);
    assert_script_run("! ls -l $file");
    check_package(1, $pkgname, $check_path);

}

1;
