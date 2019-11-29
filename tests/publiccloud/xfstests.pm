# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: XFStests on Public Cloud images
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "publiccloud::basetest";
use strict;
use warnings;
use testapi;
use utils;
use repo_tools 'generate_version';
use Mojo::UserAgent;

our $root_dir = '/root';

sub run {
    my ($self)       = @_;
    my $REG_CODE     = get_required_var('SCC_REGCODE');
    my $disk_size    = get_var('PUBLIC_CLOUD_DISK_SIZE', '20');
    my $black_list   = get_var('XFSTESTS_BLACKLIST');
    my $xfstests_dir = '/tmp/xfstests-dev';

    $self->select_serial_terminal;

    assert_script_run('curl ' . data_url('publiccloud/xfstests/partitions.sh') . ' -o /tmp/partitions.sh');
    assert_script_run('curl ' . data_url('publiccloud/xfstests/run.sh') . ' -o /tmp/run.sh');

    my $provider = $self->provider_factory();
    my $instance = $self->{my_instance} = $provider->create_instance(use_extra_disk => {size => $disk_size});
    $instance->wait_for_guestregister();

    $instance->scp('/tmp/partitions.sh', 'remote:' . '/tmp/partitions.sh');
    $instance->scp('/tmp/run.sh',        'remote:' . '/tmp/run.sh');
    $instance->run_ssh_command(cmd => "sudo chmod +x  /tmp/partitions.sh");
    $instance->run_ssh_command(cmd => "sudo chmod +x  /tmp/run.sh");

    $instance->run_ssh_command(cmd => 'sudo SUSEConnect -r ' . $REG_CODE,         timeout => 600) if (get_required_var('FLAVOR') !~ m/On-Demand/);
    $instance->run_ssh_command(cmd => 'sudo SUSEConnect -p sle-sdk/12.5/x86_64 ', timeout => 300);
    $instance->run_ssh_command(cmd => 'sudo zypper -n -q in git-core e2fsprogs automake gcc libuuid1 quota attr make xfsprogs libgdbm4 gawk uuid-runtime acl bc dump indent libtool lvm2 psmisc sed xfsdump libacl-devel libattr-devel libaio-devel libuuid-devel openssl-devel xfsprogs-devel yp-tools libcap-progs');

    my $devices  = $instance->run_ssh_command(cmd => 'sudo lsblk');
    my $dev_line = $instance->run_ssh_command(cmd => 'sudo lsblk|grep disk|grep ' . $disk_size);
    (my $dev = $dev_line) =~ s/(\w+).*/$1/;
    record_info('lsblk', $devices);
    record_info('dev',   $dev);

    $instance->run_ssh_command(cmd => "sudo /tmp/partitions.sh $dev", timeout => 600);

    # Install XFSTESTS
    $instance->run_ssh_command(cmd => "git clone git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git $xfstests_dir", timeout => 300);
    $instance->run_ssh_command(cmd => "cd $xfstests_dir && sudo make && sudo make install",                           timeout => 600);
    $instance->run_ssh_command(cmd => "sudo groupadd fsgqa && sudo useradd fsgqa -g fsgqa -s /bin/bash -m && sudo mkdir /mnt/test /mnt/scratch");

    # Apply Blacklist
    if ($black_list) {
        $black_list =~ s/,/ /g;    # this variable is a list separated by commas
        $instance->run_ssh_command(cmd => "cd $xfstests_dir/tests && rm -f $black_list");
    }

    $instance->run_ssh_command(cmd => "sudo /tmp/run.sh $dev $xfstests_dir", timeout => 18000);
}

1;
