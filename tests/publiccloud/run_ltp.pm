# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use perl script to run LTP on public cloud
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "publiccloud::basetest";
use strict;
use warnings;
use testapi;
use utils;
use repo_tools 'generate_version';
use Mojo::UserAgent;

sub get_ltp_rpm
{
    my ($url) = @_;
    my $ua    = Mojo::UserAgent->new();
    my $links = $ua->get($url)->res->dom->find('a')->map(attr => 'href');
    for my $link (grep(/^ltp-20.*rpm$/, @{$links})) {
        return $link;
    }
    die('Could not find LTP package in ' . $url);
}

sub run {
    my ($self) = @_;
    my $ltp_repo = get_var('LTP_REPO', 'http://download.suse.de/ibs/QA:/Head/' . generate_version("-") . '/x86_64/');
    my $REG_CODE = get_required_var('SCC_REGCODE');

    $self->select_serial_terminal;

    my $ltp_rpm         = get_ltp_rpm($ltp_repo);
    my $source_rpm_path = '/root/' . $ltp_rpm;
    my $remote_rpm_path = '/tmp/' . $ltp_rpm;
    record_info('LTP RPM', $ltp_repo . $ltp_rpm);
    assert_script_run('wget ' . $ltp_repo . $ltp_rpm . ' -O ' . $source_rpm_path);

    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance();
    $instance->wait_for_guestregister();

    $instance->scp($source_rpm_path, 'remote:' . $remote_rpm_path);

    assert_script_run('curl ' . data_url('publiccloud/restart_instance.sh') . ' -o ~/restart_instance.sh');
    assert_script_run('chmod +x ~/restart_instance.sh');

    assert_script_run('git clone -q --single-branch -b runltp_ng_openqa --depth 1 https://github.com/cfconrad/ltp.git');

    # Install ltp from package on remote
    $instance->run_ssh_command(cmd => 'sudo SUSEConnect -r ' . $REG_CODE, timeout => 600) if (get_required_var('FLAVOR') !~ m/On-Demand/);
    $instance->run_ssh_command(cmd => 'sudo zypper --no-gpg-checks --gpg-auto-import-keys -q in -y ' . $remote_rpm_path, timeout => 600);
    $instance->run_ssh_command(cmd => 'sudo CREATE_ENTRIES=1 /opt/ltp/IDcheck.sh', timeout => 300);

    my $reset_cmd = '~/restart_instance.sh ' . get_required_var('PUBLIC_CLOUD_PROVIDER') . ' ';
    $reset_cmd .= $instance->instance_id . ' ' . $instance->public_ip;

    my $cmd = 'perl -I ltp/tools/runltp-ng ltp/tools/runltp-ng/runltp-ng ';
    $cmd .= '--logname=ltp_log ';
    $cmd .= '--run ' . get_required_var('COMMAND_FILE') . ' ';
    $cmd .= '--exclude \'' . get_required_var('COMMAND_EXCLUDE') . '\' ';
    $cmd .= '--backend=ssh';
    $cmd .= ':user=' . $instance->username;
    $cmd .= ':key_file=' . $instance->ssh_key;
    $cmd .= ':host=' . $instance->public_ip;
    $cmd .= ':reset_command=\'' . $reset_cmd . '\'';
    $cmd .= ':ssh_opts=\'-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\' ';
    $cmd .= '--json-format=openqa ';

    assert_script_run($cmd, timeout => get_var('LTP_TIMEOUT', 30 * 60));
}


sub cleanup {
    my ($self) = @_;

    # Ensure that the ltp script gets killed
    type_string('', terminate_with => 'ETX');

    upload_logs('ltp_log.raw', failok => 1);
    parse_extra_log(LTP => 'ltp_log.json') if (script_run('test -f ltp_log.json') == 0);
}

1;

=head1 Discussion

Test module to run LTP test on publiccloud. The test run on a local qemu instance
and connect to the CSP instance using SSH. This is done via the run_ltp_ssh.pl script.

=head1 Configuration

=head2 COMMAND_FILE

The LTP test command file (e.g. syscalls, cve)

=head2 COMMAND_EXCLUDE

This regex is used to exclude tests from command file.

=head2 LTP_REPO

The repo which will be added and is used to install LTP package.

=head2 PUBLIC_CLOUD_LTP

If set, this test module is added to the job.

=head2 PUBLIC_CLOUD_PROVIDER

The type of the CSP (e.g. AZURE, EC2)

=head2 PUBLIC_CLOUD_IMAGE_LOCATION

The URL where the image gets downloaded from. The name of the image gets extracted
from this URL.

=head2 PUBLIC_CLOUD_KEY_ID

The CSP credentials key-id to used to access API.

=head2 PUBLIC_CLOUD_KEY_SECRET

The CSP credentials secret used to access API.

=head2 PUBLIC_CLOUD_REGION

The region to use. (default-azure: westeurope, default-ec2: eu-central-1)

=head2 PUBLIC_CLOUD_TENANT_ID

This is B<only for azure> and used to create the service account file.

=cut
