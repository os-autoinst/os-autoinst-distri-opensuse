# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: verify expected setroubleshootd behavior
#  - Install the package setroubleshoot-server, check that it installs setroubleshoot-plugins
#  - Check setroubleshootd DBus activation only via systemd service.
#  - Check if is-active shows inactive at first, then after restart shows active at first
#    but after about 15 seconds it should be no longer active again.
#  - Check setroubleshootd invoking via polkit as root, see
#    /usr/share/dbus-1/system.d/org.fedoraproject.SetroubleshootFixit.conf
#  - verify sealert working (sealert is part of setroubleshoot-server pkg)
# Maintainer: QE Security <none@suse.de>
# Tags: poo#174175, poo#174178

use base "selinuxtest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';

sub ensure_setroubleshootd_cannot_be_directly_run_as_root {
    # ensure current test is run as root user
    validate_script_output 'id', sub { m/uid=0\(root\)/ };
    # ensure setroubleshootd cannot be run as root
    my $errmsg = 'org.freedesktop.DBus.Error.AccessDenied: Request to own name refused by policy';
    validate_script_output('setroubleshootd -d -f 2>&1', sub { m/$errmsg/ }, proceed_on_failure => 1);
}

# ensure service is inactive; then after restart should be active, and inactive again after some time
sub validate_service_restart {
    validate_script_output('systemctl is-active setroubleshootd.service', sub { m/inactive/ }, proceed_on_failure => 1);
    validate_script_output('systemctl restart setroubleshootd; systemctl is-active setroubleshootd.service', sub { m/active/s }, proceed_on_failure => 1);
    script_retry("journalctl  --lines 10 | grep 'setroubleshootd.service: Deactivated successfully'", retry => 10, delay => 3, fail_message => 'setroubleshootd took too long to stop');
    validate_script_output('systemctl is-active setroubleshootd.service', sub { m/inactive/s }, proceed_on_failure => 1);
}

sub validate_invocation_via_polkit {
    # check for invoking via polkit as root
    my $cmd = 'pkcheck -p $$ -a org.fedoraproject.setroubleshootfixit.write';
    assert_script_run qq{runuser root -c "$cmd"};
    # should fail when run as non-privileged user
    validate_script_output(qq{runuser bernhard -c "$cmd"},
        sub { m/GDBus.Error:org.freedesktop.PolicyKit1.Error.NotAuthorized: Only trusted callers/ },
        proceed_on_failure => 1);
}

sub valid_sealert_output {
    my $output_to_validate = shift;
    my @validations = (
        qr /SELinux is preventing runcon from using the transition access on a process./,
        qr /Selinux Enabled\s+True/,
        qr /Policy Type\s+targeted/,
        qr /Enforcing Mode\s+Enforcing/,
        qr /Hash: runcon,unconfined_t,user_tmp_t,process,transition/,
    );
    foreach my $regex (@validations) {
        return 0 if ($output_to_validate !~ $regex);
    }
    return 1;
}

sub check_sealert() {
    # initially there should be no alerts (command should output nothing)
    validate_script_output "sealert -l '*'", sub { m /^$/ };
    # create a sample file and give it wrong http_content type on purpose
    my $sample_file = '/tmp/sealert_test';
    assert_script_run "touch $sample_file && chcon -t httpd_sys_content_t $sample_file";
    # ensure there are no alerts about that file as well
    validate_script_output "sealert -l '*'", sub { m /^$/ };
    # using user_tmp context, try to access the file (should fail)
    die "Should deny permission" unless script_run("runcon -t user_tmp_t -- cat $sample_file");
    # sealert should show deny message
    my $sealert_l_output;
    my $sealert_a_output;
    my $retries = 10;
    while ($retries--) {
        $sealert_l_output = script_output "sealert -l '*'";
        $sealert_a_output = script_output "sealert -a /var/log/audit/audit.log";
        last if valid_sealert_output($sealert_a_output) || valid_sealert_output($sealert_l_output);
        sleep 1;
    }
    die "sealert -l '*' Does not validate" unless $retries;
    # extract event id from the output
    my $local_id;
    if ($sealert_a_output =~ /Local ID\s+([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})/s) {
        $local_id = $1;
    } else {
        die "alert event ID not found";
    }
    # https://bugzilla.suse.com/show_bug.cgi?id=1237388
    # run same validations against specific ID output
    record_soft_failure('bsc#1237388 -- sealert -l ID') unless valid_sealert_output(script_output "sealert -l $local_id", proceed_on_failure => 1);
    # we should find deny message in journal as well
    record_soft_failure('bsc#1237388 - journalctl') if script_run "journalctl -u setroubleshootd.service | grep 'SELinux is preventing runcon from using the transition access'";
}

sub run {
    my ($self) = shift;
    select_serial_terminal;
    if (is_sle) {    # bail out on SLE
        record_info 'TEST SKIPPED', 'setroubleshootd is not yet implemented on SLE';
        return;
    }
    # ensure selinux is in enforcing mode
    validate_script_output 'getenforce', sub { m/Enforcing/ };
    # ensure pkg installation
    zypper_call 'in setroubleshoot-server setroubleshoot';
    assert_script_run 'rpm -q setroubleshoot-plugins';
    ensure_setroubleshootd_cannot_be_directly_run_as_root;
    validate_service_restart;
    validate_invocation_via_polkit;
    check_sealert;
}

1;
