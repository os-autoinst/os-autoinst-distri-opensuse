# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Set-up OpenShift cluster on the host
# There are some requirements that need to be pre-setup on the host:
#  - user bernhard must be existing with default testapi password
#  - user bernhard must have "ALL=(ALL) NOPASSWD: ALL" in visudo to avoid prompt input
#  - HDD must be at least 30 or 35GB in size and min RAM 15GB, and cpu=host
#  - pull secret must be available in some internal repository defined in OPENSHIFT_CONFIG_REPO
#  - the repository must contain 3 things: crc-linux-amd64.tar.xz oc.rpm and ps.json
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;
    my $user = $testapi::username;

    # Make sure user has access to tty group
    my $serial_group = script_output("stat -c %G /dev/$testapi::serialdev");
    assert_script_run("chown $user /dev/$testapi::serialdev && gpasswd -a $user $serial_group");

    # Get packages from repository
    my $config_repo = get_required_var('OPENSHIFT_CONFIG_REPO');
    assert_script_run("git clone -q --depth 1 $config_repo /root/openshift_config");
    assert_script_run('cd /root/openshift_config');

    # CRC client installation
    assert_script_run('tar xvf crc-linux-amd64.tar.xz');
    assert_script_run('cp crc-linux-*-amd64/crc /usr/sbin && chmod +x /usr/sbin/crc');
    my $crc_version = script_output('crc version');
    record_info('crc', $crc_version);
    record_soft_failure('poo#0000000 There is a new version of CRC, please update the RPM') if ($crc_version =~ /A new version/);

    # OC client
    assert_script_run('rpm -i oc.rpm');
    record_info('oc', script_output('oc version'));

    # Pull Secret
    my $config_dir = "/home/$user/.config/";
    assert_script_run("mkdir -p $config_dir");
    assert_script_run("cp ps.json $config_dir");
    assert_script_run("chown -R $user:$user $config_dir");

    # CRC Setup
    #  - OpenShift installation must be done by non-root user
    #  - The config step will need to download some assets and might take some time
    select_console "user-console";
    assert_script_run('set -o pipefail');
    assert_script_run("crc config set consent-telemetry no");
    assert_script_run("crc setup 2>&1 | tee /tmp/crc_setup.log", timeout => 1800);
    assert_script_run("crc start -c 8 -m 16000 -p /home/$user/.config/ps.json 2>&1 | tee /tmp/crc_start.log", timeout => 1800);

    # Check that the deployment works
    assert_script_run('eval $(crc oc-env)');
    assert_script_run('oc login -u developer https://api.crc.testing:6443');
}

sub upload {
    my ($self) = @_;
    upload_logs('/tmp/crc_setup.log', failok => 1);
    upload_logs('/tmp/crc_start.log', failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->upload();
}

sub post_run_hook {
    my ($self) = @_;
    $self->upload();
}

1;
