# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use img-proof framework to test public cloud SUSE images
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use Mojo::JSON;

our $azure_byos      = 'test_sles,test_sles_azure';
our $azure_on_demand = 'test_sles_wait_on_registration,test_sles,test_sles_on_demand,test_sles_azure';

our $ec2_byos       = 'test_sles,test_sles_ec2,test_sles_ec2_byos';
our $ec2_byos_chost = 'test_sles,test_sles_ec2';
our $ec2_on_demand  = 'test_sles_wait_on_registration,test_sles,test_sles_ec2,test_sles,test_sles_on_demand,test_sles_ec2_on_demand';

our $gce_byos      = 'test_sles_wait_on_registration,test_sles,test_sles_gce';
our $gce_on_demand = 'test_sles_wait_on_registration,test_sles,test_update,test_sles_smt_reg,test_sles_guestregister,test_sles_on_demand,test_sles_gce';

our $img_proof_tests = {
    'Azure-BYOS'       => $azure_byos,
    'Azure-Basic'      => $azure_on_demand,
    'Azure-Standard'   => $azure_on_demand,
    'Azure-CHOST-BYOS' => $azure_byos,
    'Azure-HPC'        => $azure_on_demand,
    'Azure-HPC-BYOS'   => $azure_byos,

    'EC2-CHOST-BYOS'   => $ec2_byos_chost,
    'EC2-HVM'          => $ec2_on_demand,
    'EC2-HVM-ARM'      => $ec2_on_demand,
    'EC2-HVM-BYOS'     => $ec2_byos,
    'EC2-HVM-HPC-BYOS' => $ec2_byos,

    GCE              => $gce_on_demand,
    'GCE-BYOS'       => $gce_byos,
    'GCE-CHOST-BYOS' => $gce_byos,
};

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    my $flavor   = get_required_var('FLAVOR');
    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance();
    my $tests    = get_required_var('PUBLIC_CLOUD_IMG_PROOF_TESTS');
    if ($tests eq "default") {
        $tests = $img_proof_tests->{$flavor};
        die("Missing img_proof tests for $flavor - plz change img_proof.pm") unless $tests;
    }

    my $img_proof = $provider->img_proof(
        instance    => $instance,
        tests       => $tests,
        results_dir => 'img_proof_results'
    );

    upload_logs($img_proof->{logfile});
    parse_extra_log(IPA => $img_proof->{results});
    assert_script_run('rm -rf img_proof_results');

    # fail, if at least one test failed
    if ($img_proof->{fail} > 0) {

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
        $instance->run_ssh_command(cmd => 'rpm -qa > /tmp/rpm_qa.txt', no_quote => 1);
        upload_logs('/tmp/rpm_qa.txt');
    }
}

sub cleanup {
    my ($self) = @_;

    # upload logs on unexpected failure
    my $ret = script_run('test -d img_proof_results');
    if (defined($ret) && $ret == 0) {
        assert_script_run('tar -zcvf img_proof_results.tar.gz img_proof_results');
        upload_logs('img_proof_results.tar.gz', failok => 1);
    }
}

1;

=head1 Discussion

This module use img-proof tool to test public cloud SLE images.
Logs are uploaded at the end.

When running img-proof from SLES, it must have a valid SCC registration to enable
public cloud module.

The variables DISTRI, VERSION and ARCH must correspond to the system where
img-proof get installed in and not to the public cloud image.

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

=cut
