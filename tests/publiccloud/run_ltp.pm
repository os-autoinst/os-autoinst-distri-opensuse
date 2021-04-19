# SUSE's openQA tests
#
# Copyright © 2018-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: perl-base ltp
# Summary: Use perl script to run LTP on public cloud
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>, qa-c team <qa-c@suse.de>

use base "publiccloud::basetest";
use strict;
use warnings;
use testapi;
use utils;
use repo_tools 'generate_version';
use Mojo::UserAgent;
use LTP::utils "get_ltproot";
use publiccloud::utils qw(is_byos select_host_console);

our $root_dir = '/root';

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

sub instance_log_args
{
    my $self = shift;
    return sprintf('"%s" "%s" "%s" "%s"',
        get_required_var('PUBLIC_CLOUD_PROVIDER'),
        $self->{my_instance}->instance_id,
        $self->{my_instance}->public_ip,
        $self->{provider}->region);
}

sub run {
    my ($self, $args) = @_;
    my $arch     = check_var('PUBLIC_CLOUD_ARCH', 'arm64') ? 'aarch64' : 'x86_64';
    my $ltp_repo = get_var('LTP_REPO', 'https://download.opensuse.org/repositories/benchmark:/ltp:/devel/' . generate_version("_") . '/');
    my $REG_CODE = get_required_var('SCC_REGCODE');
    my $provider;
    my $instance;

    select_host_console();

    if (get_var('PUBLIC_CLOUD_QAM')) {
        $instance = $self->{my_instance} = $args->{my_instance};
        $provider = $self->{provider}    = $args->{my_provider};    # required for cleanup
    } else {
        $provider = $self->provider_factory();
        $instance = $self->{my_instance} = $provider->create_instance();
        $instance->wait_for_guestregister();
    }

    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/restart_instance.sh') . ' -o restart_instance.sh');
    assert_script_run('curl ' . data_url('publiccloud/log_instance.sh') . ' -o log_instance.sh');
    assert_script_run('chmod +x restart_instance.sh');
    assert_script_run('chmod +x log_instance.sh');

    $instance->run_ssh_command(cmd => 'sudo SUSEConnect -r ' . $REG_CODE, timeout => 600) if is_byos();

    # in repo with LTP rpm is internal we need to manually upload package to VM
    if (get_var('LTP_RPM_MANUAL_UPLOAD')) {
        my $ltp_rpm         = get_ltp_rpm($ltp_repo);
        my $source_rpm_path = $root_dir . '/' . $ltp_rpm;
        my $remote_rpm_path = '/tmp/' . $ltp_rpm;
        record_info('LTP RPM', $ltp_repo . $ltp_rpm);
        assert_script_run('wget ' . $ltp_repo . $ltp_rpm . ' -O ' . $source_rpm_path);
        $instance->scp($source_rpm_path, 'remote:' . $remote_rpm_path) if (get_var('LTP_RPM_MANUAL_UPLOAD'));
        $instance->run_ssh_command(cmd => 'sudo zypper --no-gpg-checks --gpg-auto-import-keys -q in -y ' . $remote_rpm_path, timeout => 600);
    }
    else {
        $instance->run_ssh_command(cmd => 'sudo zypper -q addrepo -fG ' . $ltp_repo . ' ltp_repo', timeout => 600);
        $instance->run_ssh_command(cmd => 'sudo zypper -q in -y ltp',                              timeout => 600);
    }

    my $runltp_ng_repo   = get_var("LTP_RUN_NG_REPO",   "https://github.com/metan-ucw/runltp-ng.git");
    my $runltp_ng_branch = get_var("LTP_RUN_NG_BRANCH", "master");
    assert_script_run("git clone -q --single-branch -b $runltp_ng_branch --depth 1 $runltp_ng_repo");
    $instance->run_ssh_command(cmd => 'sudo CREATE_ENTRIES=1 ' . get_ltproot() . '/IDcheck.sh', timeout => 300);
    record_info('Kernel info', $instance->run_ssh_command(cmd => q(rpm -qa 'kernel*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));

    my $reset_cmd     = $root_dir . '/restart_instance.sh ' . $self->instance_log_args();
    my $log_start_cmd = $root_dir . '/log_instance.sh start ' . $self->instance_log_args();

    assert_script_run($log_start_cmd);

    my $cmd = 'perl -I runltp-ng runltp-ng/runltp-ng ';
    $cmd .= '--logname=ltp_log ';
    $cmd .= '--timeout=1200 ';
    $cmd .= '--run ' . get_required_var('COMMAND_FILE') . ' ';
    $cmd .= '--exclude \'' . get_required_var('COMMAND_EXCLUDE') . '\' ';
    $cmd .= '--backend=ssh';
    $cmd .= ':user=' . $instance->username;
    $cmd .= ':key_file=' . $instance->ssh_key;
    $cmd .= ':host=' . $instance->public_ip;
    $cmd .= ':reset_command=\'' . $reset_cmd . '\'';
    $cmd .= ':ssh_opts=\'-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\' ';
    assert_script_run($cmd, timeout => get_var('LTP_TIMEOUT', 30 * 60));
}


sub cleanup {
    my ($self) = @_;

    # Ensure that the ltp script gets killed
    type_string('', terminate_with => 'ETX');

    upload_logs('ltp_log.raw', failok => 1);
    parse_extra_log(LTP => "$root_dir/ltp_log.json") if (script_run("test -f $root_dir/ltp_log.json") == 0);

    if ($self->{my_instance} && script_run("test -f $root_dir/log_instance.sh") == 0) {
        assert_script_run($root_dir . '/log_instance.sh stop ' . $self->instance_log_args());
        assert_script_run("(cd /tmp/log_instance && tar -zcf $root_dir/instance_log.tar.gz *)");
        upload_logs("$root_dir/instance_log.tar.gz", failok => 1);
    }
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
