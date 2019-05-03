# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use IPA framework to test public cloud SUSE images
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use Mojo::JSON;

sub extract_startup_timings {
    my $string = shift;
    my $res    = {};
    $string =~ s/Startup finished in\s*//;
    $string =~ s/=(.+)$/+$1 (overall)/;
    for my $time (split(/\s*\+\s*/, $string)) {
        if ($time =~ /((\d{1,2})min\s*)?(\d{1,2}\.\d{1,3})s\s*\((\w+)\)/) {
            my $sec = $3;
            $sec += $2 * 60 if (defined($1));
            $res->{$4} = $sec;
        }
    }
    map { die("Fail to detect $_ timing") unless exists($res->{$_}) } qw(kernel initrd userspace overall);
    return $res;
}

sub build_influx_kv {
    my $hash = shift;
    my $req  = '';
    for my $k (keys(%{$hash})) {
        my $v = $hash->{$k};
        $v =~ s/,/\\,/g;
        $v =~ s/ /\\ /g;
        $v =~ s/=/\\=/g;
        $req .= $k . '=' . $v . ',';
    }
    return substr($req, 0, -1);
}

sub build_influx_query {
    my $data = shift;
    my $req  = $data->{table} . ',';
    $req .= build_influx_kv($data->{tags});
    $req .= ' ';
    $req .= build_influx_kv($data->{values});
    return $req;
}

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance();
    my $tests    = get_var('PUBLIC_CLOUD_IPA_TESTS', '');

    my $ipa = $provider->ipa(
        instance    => $instance,
        tests       => $tests,
        results_dir => 'ipa_results'
    );

    if (get_var('PUBLIC_CLOUD_CHECK_BOOT_TIME')) {
        my $kernel_max_boot_time = 60;
        my $system_max_boot_time = 120;
        my $out                  = script_output('grep "^Startup finished in" ' . $ipa->{logfile});
        record_info('Startup time', $out);
        my $startup_timings = extract_startup_timings($out);
        record_info('Kernel boot is too slow',         result => 'fail') if $startup_timings->{'kernel'} > $kernel_max_boot_time;
        record_info('Overall system boot is too slow', result => 'fail') if $startup_timings->{'overall'} > $system_max_boot_time;
        my $url = get_var('PUBLIC_CLOUD_PERF_DB_URI');
        if ($url) {
            my $data = {
                table => 'bootup',
                tags  => {
                    instance_type     => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
                    os_flavor         => get_required_var('FLAVOR'),
                    os_version        => get_required_var('VERSION'),
                    os_build          => get_required_var('BUILD'),
                    os_pc_build       => get_required_var('PUBLIC_CLOUD_BUILD'),
                    os_pc_kiwi_build  => get_required_var('PUBLIC_CLOUD_BUILD_KIWI'),
                    os_kernel_release => $instance->run_ssh_command(cmd => 'uname -r'),
                    os_kernel_version => $instance->run_ssh_command(cmd => 'uname -v')
                },
                values => $startup_timings
            };
            $data = build_influx_query($data);
            assert_script_run(sprintf("curl -i -X POST '%s' --data-binary '%s'", $url . '/write?db=publiccloud', $data));
        }
    }
    upload_logs($ipa->{logfile});
    parse_extra_log(IPA => $ipa->{results});
    assert_script_run('rm -rf ipa_results');

    # fail, if at least one test failed
    if ($ipa->{fail} > 0) {

        # Upload cloudregister log if corresponding test fails
        for my $t (@{$self->{extra_test_results}}) {
            next if ($t->{name} !~ m/registration|repo|smt|guestregister|update/);
            my $filename = 'result-' . $t->{name} . '.json';
            my $file     = path(bmwqemu::result_dir(), $filename);
            my $json     = Mojo::JSON::decode_json($file->slurp);
            next if ($json->{result} ne 'fail');
            $instance->upload_log('/var/log/cloudregister');
            last;
        }
    }
}

sub cleanup {
    my ($self) = @_;

    # upload logs on unexpected failure
    my $ret = script_run('test -d ipa_results');
    if (defined($ret) && $ret == 0) {
        assert_script_run('tar -zcvf ipa_results.tar.gz ipa_results');
        upload_logs('ipa_results.tar.gz', failok => 1);
    }
}

1;

=head1 Discussion

This module use IPA tool to test public cloud SLE images.
Logs are uploaded at the end.

When running IPA from SLES, it must have a valid SCC registration to enable
public cloud module.

The variables DISTRI, VERSION and ARCH must correspond to the system where
IPA get installed in and not to the public cloud image.

=head1 Configuration

=head2 PUBLIC_CLOUD_IMAGE_LOCATION

Is used to retrieve the actually image ID from CSP via C<$provider->get_image_id()>

For azure, the name of the image, e.g. B<SLES12-SP4-Azure-BYOS.x86_64-0.9.0-Build3.23.vhd>.
For ec2 the AMI, e.g. B<ami-067a77ef88a35c1a5>.

=head2 PUBLIC_CLOUD_PROVIDER

The type of the CSP (Cloud service provider).

=head2 PUBLIC_CLOUD_KEY_ID

The CSP credentials key-id to used to access API.

=head2 PUBLIC_CLOUD_KEY_SECRET

The CSP credentials secret used to access API.

=head2 PUBLIC_CLOUD_REGION

The region to use. (default-azure: westeurope, default-ec2: eu-central-1)

=head2 PUBLIC_CLOUD_INSTANCE_TYPE

Specify the instance type. Which instance types exists depends on the CSP.
(default-azure: Standard_A2, default-ec2: t2.large )

More infos:
Azure: https://docs.microsoft.com/en-us/rest/api/compute/virtualmachinesizes/list
EC2: https://aws.amazon.com/ec2/instance-types/

=head2 PUBLIC_CLOUD_TENANT_ID

This is B<only for azure> and used to create the service account file.

=head2 PUBLIC_CLOUD_SUBSCRIPTION_ID

This is B<only for azure> and used to create the service account file.

=head2 PUBLIC_CLOUD_PERF_DB_URI

If this variable is set, the bootup timings get stored inside the influx
database. The database name is 'publiccloud'.
(e.g. PUBLIC_CLOUD_PERF_DB_URI=http://openqa-perf.qa.suse.de:8086)

=cut
