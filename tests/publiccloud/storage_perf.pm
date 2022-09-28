# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: fio
# Summary: Use FIO tool to run storage performance test
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use db_utils;
use Mojo::JSON;
use publiccloud::utils qw(is_byos registercloudguest);

use constant NUMJOBS => 4;
use constant IODEPTH => 4;

=head2  get_mean_from_db

    Calculates the mean value for given C<load_type> , C<scenario> , C<os_flavor> , C<os_version>.
    C<limit> suppose to define the scope ( e.g. "limit 5" or "limit 5 offset 5")
    In case getting empty response from InfluxDB will return C<undef> or mean value calculated by InfluxDB otherwise.

=cut
sub get_mean_from_db {
    my ($args, $limit) = @_;

    my $query = sprintf("SELECT MEAN(*) FROM (SELECT %s FROM storage WHERE scenario='%s' and os_flavor='%s' and os_version='%s' %s)", $args->{load_type}, $args->{scenario}, $args->{os_flavor}, $args->{os_version}, $limit);

    my $json_res = influxdb_read_data($args->{url}, $args->{db}, $query);
    # when there is no results , "series" section is not returned :
    # { 'results' =>
    #      [{
    #        'statement_id' => 0
    #      }]
    #  };
    unless (defined($json_res->{results}->[0]->{series})) {
        record_info('NO RESULTS', sprintf("No results for load_type=%s, scenario=%s, Flavor=%s, Version=%s\n", $args->{load_type}, $args->{scenario}, $args->{os_flavor}, $args->{os_version}));
        return undef;
    }

    # example of response when this is some data :
    #{ 'results' =>
    #    [{
    #      'statement_id' => 0,
    #      'series' => [{
    #        'values' => [[ '1970-01-01T00:00:00Z', 0 ]],
    #        'name' => 'storage',
    #        'columns' => ['time','mean_write_throughput']
    #                  }]
    #     }]
    #};
    # we want to return **value** of "mean_write_throughput" (from example above)
    my $series = $json_res->{results}->[0]->{series};
    my @values = @{$series}[0]->{values};
    return $values[0][0][1];
}

=head2 db_has_data

  Using same as in get_mean_from_db  where clause ( C<scenario>, C<os_flavor>, C<os_version>) we just verify that
  there is enough data for analysis by doing count() of all available rows

=cut
sub db_has_data {
    my (%args) = @_;

    my $query = sprintf("SELECT count(*) FROM storage WHERE scenario='%s' and os_flavor='%s' and os_version='%s'", $args{scenario}, $args{os_flavor}, $args{os_version});

    my $json_res = influxdb_read_data($args{url}, $args{db}, $query);
    return 0 unless (defined($json_res->{results}->[0]->{series}));

    my $series = $json_res->{results}->[0]->{series};
    my @values = @{$series}[0]->{values};
    # explanation of data structures in get_mean_from_db
    return $values[0][0][1] > 10;
}

=head2 analyze_previous_series

    Function which will loop over incoming C<load_types> array
    and calculate the mean of last 5 test results to compare it with 5 test result before that.
    In such a way we protecting ourselfs from one time failures and trigger the flag only when there is
    reproducible performance degradation.

=cut
sub analyze_previous_series {
    my ($args, $load_types) = @_;
    my $result = 0;

    foreach my $load_type (@$load_types) {
        $args->{load_type} = $load_type;
        my $current_load_type = sprintf(" load_type=%s, scenario=%s, Flavor=%s, Version=%s", $args->{load_type}, $args->{scenario}, $args->{os_flavor}, $args->{os_version});
        # getting mean for last 5 test runs
        my $last_records_mean = get_mean_from_db($args, " limit 5");
        # getting mean for 5 runs which were before last 5 ( from 6 to 10th)
        my $previous_records_mean = get_mean_from_db($args, " limit 5 offset 5");

        my $generic_message = sprintf("See previous message and http://openqa-perf.qa.suse.de/d/hoRc37HWz/storage-performance?orgId=1&var-os_flavor=%s&var-os_version=%s", $args->{os_flavor}, $args->{os_flavor});

        # we do analysis only if we get back some non-zero values
        if (defined($previous_records_mean) && defined($last_records_mean) && $previous_records_mean != 0 && $last_records_mean != 0) {
            my $diff_percents = (abs($previous_records_mean - $last_records_mean) / $previous_records_mean) * 100;
            my $analyze = sprintf("Analyzing: %s\n", $current_load_type);
            $analyze .= "Comparing mean values of previous 5 entries and last 5 entries.\n";
            $analyze .= sprintf("Mean of previous 5 entries: %.2f Mean of last 5 entries: %.2f\n", $previous_records_mean, $last_records_mean);
            $analyze .= sprintf("The difference is: %.2f%%.", $diff_percents);
            record_info('ANALYZE', $analyze);
            # This detects if mean values differs more than 10%
            if ($diff_percents > 10) {
                record_info("Deviation occurred. $generic_message", result => 'softfail');
                $result = 1;
            } else {
                record_info('PASS', "The data looks good. $generic_message");
            }
        } else {
            record_info('N/A', "Analysis not possible $generic_message");
        }
    }
    return $result;
}


sub run {
    my ($self) = @_;
    my $reg_code = get_var('SCC_REGCODE');
    my $runtime = get_var('PUBLIC_CLOUD_FIO_RUNTIME', 300);
    my $disk_size = get_var('PUBLIC_CLOUD_HDD2_SIZE');
    my $disk_type = get_var('PUBLIC_CLOUD_HDD2_TYPE');
    my $url = get_var('PUBLIC_CLOUD_PERF_DB_URI');

    my @scenario = (
        {
            name => 'reference',
            rw => 'randread',
            rwmixread => '100',
            bs => '4k'
        },
        {
            name => 'reallife',
            rw => 'randrw',
            rwmixread => '65',
            bs => '4k'
        },
        {
            name => 'writeintensive',
            rw => 'randwrite',
            rwmixread => '10',
            bs => '4k'

        },
        {
            name => 'maxthroughput',
            rw => 'read',
            rwmixread => '100',
            bs => '64k'
        }
    );

    my $tags = {
        instance_type => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
        os_flavor => get_required_var('FLAVOR'),
        os_version => get_required_var('VERSION'),
        os_build => get_required_var('BUILD'),
        os_pc_build => get_required_var('PUBLIC_CLOUD_BUILD'),
        os_pc_kiwi_build => get_required_var('PUBLIC_CLOUD_BUILD_KIWI'),
        os_kernel_release => undef,
        os_kernel_version => undef,
    };

    $self->select_serial_terminal();

    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance(use_extra_disk => {size => $disk_size, type => $disk_type});
    $instance->wait_for_guestregister();

    $tags->{os_kernel_release} = $instance->run_ssh_command(cmd => 'uname -r');
    $tags->{os_kernel_version} = $instance->run_ssh_command(cmd => 'uname -v');

    registercloudguest($instance) if is_byos();
    $instance->run_ssh_command(cmd => 'sudo zypper --gpg-auto-import-keys -q in -y fio', timeout => 600);

    my $block_device = '/dev/' . $instance->run_ssh_command(cmd => 'lsblk -n -l --output NAME,MOUNTPOINT | grep -v sr0 | sort | tail -n1');
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
        $values->{read_throughput} = $json->{jobs}[0]->{read}->{bw};
        $values->{read_iops} = $json->{jobs}[0]->{read}->{iops};
        $values->{read_latency} = $json->{jobs}[0]->{read}->{lat_ns}->{mean} / 1000;
        $values->{write_throughput} = $json->{jobs}[0]->{write}->{bw};
        $values->{write_iops} = $json->{jobs}[0]->{write}->{iops};
        $values->{write_latency} = $json->{jobs}[0]->{write}->{lat_ns}->{mean} / 1000;

        # Store values in influx-db
        if ($url) {
            my $data = {
                table => 'storage',
                tags => $tags,
                values => $values
            };
            $data = influxdb_push_data($url, 'publiccloud', $data);
            my %influx_read_args = (
                url => $url,
                db => 'publiccloud',
                scenario => $href->{name},
                os_flavor => $tags->{os_flavor},
                os_version => $tags->{os_version}
            );
            # we will try to do analysis on when there is enough input data
            # currently test logic expect 10 test results ( so 9 + current one)
            if (db_has_data(%influx_read_args)) {
                # we will do anaysis for same load types which we just pushed to db
                my @load_types = keys %$values;
                # Change the test module result to 'fail' if deviation in analyze_previous_series() occures
                if (analyze_previous_series(\%influx_read_args, \@load_types) == 1) {
                    record_info("Possible performance deviation", "The test module detected a possible performance deviation", result => 'fail');
                    $self->{result} = 'fail';
                }
            }
            else {
                record_info('NO DATA', "We need at least 10 test results to analyze " . $href->{name} . "\n");
            }
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
