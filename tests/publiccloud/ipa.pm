# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use IPA framework to test public cloud SUSE images
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "publiccloud::basetest";
use strict;
use testapi;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    my $provider = $self->{provider} = $self->provider_factory();
    $provider->init;

    my $ipa = $provider->ipa(
        instance_type => get_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
        cleanup       => 1,
        image_id      => $self->get_image_id($provider),
        tests         => get_required_var('PUBLIC_CLOUD_IPA_TESTS'),
        results_dir   => 'ipa_results'
    );

    upload_logs($ipa->{logfile});
    parse_extra_log(IPA => $ipa->{results});

    $provider->cleanup();
    delete $self->{provider};
    assert_script_run('rm -rf ipa_results');

    # fail, if at least one test failed
    die if ($ipa->{fail} > 0);
}

sub post_fail_hook {
    my ($self) = @_;

    if ($self->{provider}) {
        $self->{provider}->cleanup();
    }

    # upload logs on unexpected failure
    my $ret = script_run('test -d ipa_results');
    return if (!defined($ret) || $ret != 0);
    assert_script_run('tar -zcvf ipa_results.tar.gz ipa_results');
    upload_logs('ipa_results.tar.gz', failok => 1);
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

=head2 PUBLIC_CLOUD_IMAGE_ID or PUBLIC_CLOUD_IMAGE_LOCATION

The image ID which is used to instantiate a VM and run tests on it.
It is taken from C<PUBLIC_CLOUD_IMAGE_ID> or if not exists it will be retrived from CSP
by searching for the file given with C<PUBLIC_CLOUD_IMAGE_LOCATION>.

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
