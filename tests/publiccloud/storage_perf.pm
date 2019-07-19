# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use FIO tool to run storage performance test
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use db_utils;
use Mojo::JSON;

use constant NUMJOBS => 4;
use constant IODEPTH => 4;


sub run {
    my ($self) = @_;
    my $reg_code = get_var('SCC_REGCODE');
    my $runtime = get_var('PUBLIC_CLOUD_FIO_RUNTIME',  300);
    my $size    = get_var('PUBLIC_CLOUD_FIO_SSD_SIZE', 100);
    my $url     = get_var('PUBLIC_CLOUD_PERF_DB_URI');

    my @scenario = (
        {
            name      => 'reference',
            rw        => 'randread',
            rwmixread => '100',
            bs        => '8k'
        },
        {
            name      => 'reallife',
            rw        => 'randrw',
            rwmixread => '65',
            bs        => '8k'
        },
        {
            name      => 'writeintensive',
            rw        => 'randwrite',
            rwmixread => '10',
            bs        => '8k'

        },
        {
            name      => 'maxthroughput',
            rw        => 'read',
            rwmixread => '100',
            bs        => '64k'
        }
    );

    my $tags = {
        instance_type     => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
        os_flavor         => get_required_var('FLAVOR'),
        os_version        => get_required_var('VERSION'),
        os_build          => get_required_var('BUILD'),
        os_pc_build       => get_required_var('PUBLIC_CLOUD_BUILD'),
        os_pc_kiwi_build  => get_required_var('PUBLIC_CLOUD_BUILD_KIWI'),
        os_kernel_release => undef,
        os_kernel_version => undef,
    };

    $self->select_serial_terminal;

    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance(use_extra_disk => {size => 100});

    $tags->{os_kernel_release} = $instance->run_ssh_command(cmd => 'uname -r');
    $tags->{os_kernel_version} = $instance->run_ssh_command(cmd => 'uname -v');

    $instance->run_ssh_command(cmd => 'sudo SUSEConnect -r ' . $reg_code, timeout => 600) if $reg_code;
    $instance->run_ssh_command(cmd => 'sudo zypper --gpg-auto-import-keys -q in -y fio', timeout => 600);

    my $block_device = '/dev/' . $instance->run_ssh_command(cmd => 'lsblk|grep ' . $size . '|cut -f 1 -d " "');
    record_info('dev', "Block device under test: $block_device");

    for my $href (@scenario) {
        my $values = {};
        record_info('FIO', 'Running test case "' . $href->{name} . '"');

        my $cmd = 'sudo fio --name=' . $href->{name};
        $cmd .= ' --direct=1';
        $cmd .= ' --ioengine=libaio';
        $cmd .= ' --rw=' . $href->{rw};
        $cmd .= ' --rwmixread=' . $href->{rwmixread};
        $cmd .= ' --bs=' . $href->{bs};
        $cmd .= ' --runtime=' . $runtime;
        $cmd .= ' --filename=' . $block_device;
        $cmd .= ' --iodepth=' . IODEPTH;
        $cmd .= ' --numjobs=' . NUMJOBS;
        $cmd .= ' --output-format=json';
        $cmd .= ' --group_reporting';

        record_info('cmd', $cmd);
        my $output = $instance->run_ssh_command(cmd => $cmd, timeout => $runtime + 60);
        record_info('Result', $output);

        $tags->{scenario} = $href->{name};

        # Parse results
        my $json = Mojo::JSON::decode_json($output);
        $values->{read_throughput}  = $json->{jobs}[0]->{read}->{bw};
        $values->{read_iops}        = $json->{jobs}[0]->{read}->{iops};
        $values->{read_latency}     = $json->{jobs}[0]->{read}->{lat_ns}->{mean} / 1000;
        $values->{write_throughput} = $json->{jobs}[0]->{write}->{bw};
        $values->{write_iops}       = $json->{jobs}[0]->{write}->{iops};
        $values->{write_latency}    = $json->{jobs}[0]->{write}->{lat_ns}->{mean} / 1000;

        # Store values in influx-db
        if ($url) {
            my $data = {
                table  => 'storage',
                tags   => $tags,
                values => $values
            };
            $data = influxdb_push_data($url, 'publiccloud', $data);
        }
    }
}

1;

=head1 Discussion

Test module to run Storage Performance using FIO on publiccloud.
4 Scenarios are defined:
 - Reference: random reads with 8 KB blocks.
       See how the disk behaves with only random reads.
 - Real life: 65% random reads with 8 KB blocks.
       Approximate to real applications with balance between reads and writes.
 - Write Intensive: 90% random writes with 8 KB blocks.
       See how the disk behaves with intestive block writting.
 - Max Throughput: 100% sequential reads with big block size.
       Try to reach maximum throughput of the block devices.

Results to be reported for each scenario:
 - throughput
 - latency
 - IOPS

=head1 Configuration

=head2 PUBLIC_CLOUD_FIO

If set, this test module is added to the job.


=head2 PUBLIC_CLOUD_FIO_RUNTIME

Set the execution time for each FIO tests. 300s by default.


=head2 PUBLIC_CLOUD_FIO_SSD_SIZE

Set the additional disk size for the FIO tests. 100GB by default.


=head2 PUBLIC_CLOUD_PERF_DB_URI

Optional variable. If set, the bootup times get stored in the influx
database. The database name is 'publiccloud'.
(e.g. PUBLIC_CLOUD_PERF_DB_URI=http://openqa-perf.qa.suse.de:8086)

=cut
