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

=cut
