# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Prepare grafana-server for binary coverage measurement
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(write_sut_file zypper_call);

sub run {
    select_serial_terminal;
    my $bin = '/usr/libexec/grafana/grafana';

    # The package preset may have started the service before coverage_setup
    # installed the shim. Stop it so the test starts the traced binary.
    script_run('systemctl stop grafana-server');

    # Drop the unfiltered grafana logs written by coverage_setup; the report
    # unions every functions log, so an empty filtered run must not keep the
    # install-time enumeration of all 356k dependency functions.
    script_run('rm -f /var/coverage/data/grafana_*_functions.log /var/coverage/data/grafana_*_called.log');

    # Restore the pre-shim binary before changing packages; otherwise the
    # uninstall later puts the old binary back over the upgraded one.
    assert_script_run("funkoverage uninstall $bin", timeout => 300);

    # The snapshot debug repo can be newer than the installed binary, and
    # funkoverage needs matching debuginfo. Install the exact version from the
    # job's snapshot debug repo when the versions differ.
    my $ver = script_output("rpm -q --qf '%{VERSION}-%{RELEASE}' grafana");
    $ver =~ s/\s+$//;
    my $dbg = script_output("rpm -q --qf '%{VERSION}-%{RELEASE}' grafana-debuginfo", proceed_on_failure => 1);
    $dbg =~ s/\s+$//;
    if ($dbg ne $ver) {
        my $mirror = get_var('MIRROR_PREFIX') // get_var('MIRROR_HTTPS') // get_var('MIRROR_HTTP');
        my $repo = get_var('REPO_OSS_DEBUG');
        if ($mirror && $repo) {
            record_info('debug repo', "$mirror/$repo");
            script_run('zypper rr snapshot-debug');
            assert_script_run("zypper ar -f -p 1 '$mirror/$repo' snapshot-debug");
            assert_script_run('zypper --gpg-auto-import-keys ref snapshot-debug', timeout => 300);
            zypper_call("in --oldpackage --from snapshot-debug grafana-debuginfo-$ver", timeout => 600, exitcode => [0, 104, 106]);
            script_run('zypper rr snapshot-debug');
        }
        $dbg = script_output("rpm -q --qf '%{VERSION}-%{RELEASE}' grafana-debuginfo", proceed_on_failure => 1);
        $dbg =~ s/\s+$//;

        # The snapshot debug repo may not ship the old debuginfo. In that case
        # install the binary matching the newer debuginfo from the snapshot
        # OSS repo.
        if ($dbg ne $ver) {
            my $oss_repo = get_var('REPO_OSS');
            if ($mirror && $oss_repo) {
                record_info('snapshot OSS repo', "$mirror/$oss_repo");
                script_run('zypper rr snapshot-oss-coverage');
                assert_script_run("zypper ar -f -p 1 '$mirror/$oss_repo' snapshot-oss-coverage");
                assert_script_run('zypper --gpg-auto-import-keys ref snapshot-oss-coverage', timeout => 300);
                zypper_call("in --oldpackage --from snapshot-oss-coverage grafana-$dbg", timeout => 600, exitcode => [0, 104, 106]);
                script_run('zypper rr snapshot-oss-coverage');
            }
            $ver = script_output("rpm -q --qf '%{VERSION}-%{RELEASE}' grafana");
            $ver =~ s/\s+$//;
            $dbg = script_output("rpm -q --qf '%{VERSION}-%{RELEASE}' grafana-debuginfo", proceed_on_failure => 1);
            $dbg =~ s/\s+$//;
        }
        die "grafana-debuginfo $dbg does not match grafana $ver" if $dbg ne $ver;
    }
    record_info('packages', "grafana $ver, grafana-debuginfo $dbg");

    # The binary has 356647 function symbols, mostly dependencies. Trace only
    # Grafana's own code.
    my $count = script_output("funkoverage enumerate --no-libs --include '^github\\.com/grafana/grafana/' $bin | wc -l", timeout => 300);
    record_info('filtered functions', $count);
    assert_script_run("funkoverage install --include '^github\\.com/grafana/grafana/' $bin", timeout => 900);

    # grafana-server.service blocks the shim with an empty capability set and
    # NoNewPrivileges. Its LOG_DIR variable also collides with funkoverage's
    # log directory; a later EnvironmentFile wins over the package one.
    write_sut_file('/etc/sysconfig/grafana-server-coverage', "LOG_DIR=/var/coverage/data\n");
    assert_script_run('mkdir -p /etc/systemd/system/grafana-server.service.d');
    write_sut_file(
        '/etc/systemd/system/grafana-server.service.d/coverage_caps.conf',
        "[Service]\n"
          . "CapabilityBoundingSet=CAP_BPF CAP_PERFMON CAP_DAC_READ_SEARCH CAP_SYS_RESOURCE\n"
          . "NoNewPrivileges=no\n"
          . "TimeoutStartSec=600\n"
          . "TimeoutStopSec=300\n"
          . "KillMode=process\n"
          . "EnvironmentFile=/etc/sysconfig/grafana-server-coverage\n"
    );
    assert_script_run('systemctl daemon-reload');
    script_run('systemctl stop grafana-server');
}

1;
