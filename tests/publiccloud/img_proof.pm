# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-img-proof
# Summary: Use img-proof framework to test public cloud SUSE images
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use Mojo::JSON;
use publiccloud::utils 'is_ondemand';
use publiccloud::ssh_interactive 'select_host_console';

sub run {
    my ($self, $args) = @_;

    my $tests = get_var('PUBLIC_CLOUD_IMG_PROOF_TESTS', 'test-sles');
    my $provider;
    my $instance;

    select_host_console();

    # QAM passes the instance as argument
    if (get_var('PUBLIC_CLOUD_QAM')) {
        $instance = $args->{my_instance};
        $provider = $args->{my_provider};
        $self->{provider} = $args->{my_provider};    # required for cleanup
    } else {
        $provider = $self->provider_factory();
        $instance = $provider->create_instance();

        $instance->wait_for_guestregister() if is_ondemand();
    }

    if ($tests eq "default") {
        record_info("Deprecated setting", "PUBLIC_CLOUD_IMG_PROOF_TESTS should not use 'default' anymore. Please use 'test_sles' instead.", result => 'softfail');
        $tests = "test_sles";
    }

    my $img_proof = $provider->img_proof(
        instance => $instance,
        tests => $tests,
        results_dir => 'img_proof_results',
        exclude => get_var("PUBLIC_CLOUD_IMG_PROOF_EXCLUDE", ''),
        beta => get_var("BETA", 0)
    );

    # Because the IP address of instance might change during img_proof due to the hard-reboot, we need to re-add the ssh public keys
    assert_script_run(sprintf('ssh-keyscan %s >> ~/.ssh/known_hosts', $instance->public_ip));

    upload_logs($img_proof->{logfile});
    parse_extra_log(IPA => $img_proof->{results});
    assert_script_run('rm -rf img_proof_results');

    # fail, if at least one test failed
    if ($img_proof->{fail} > 0) {

        # Upload cloudregister log if corresponding test fails
        for my $t (@{$self->{extra_test_results}}) {
            next if ($t->{name} !~ m/registration|repo|smt|guestregister|update/);
            my $filename = 'result-' . $t->{name} . '.json';
            my $file = path(bmwqemu::result_dir(), $filename);
            my $json = Mojo::JSON::decode_json($file->slurp);
            next if ($json->{result} ne 'fail');
            $instance->upload_log('/var/log/cloudregister', log_name => 'cloudregister.log');
            last;
        }
        $instance->run_ssh_command(cmd => 'rpm -qa > /tmp/rpm_qa.txt', no_quote => 1);
        upload_logs('/tmp/rpm_qa.txt');
        $instance->run_ssh_command(cmd => 'sudo journalctl -b > /tmp/journalctl_b.txt', no_quote => 1);
        upload_logs('/tmp/journalctl_b.txt');
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

=head2 PUBLIC_CLOUD_AZURE_TENANT_ID

This is B<only for azure> and used to create the service account file.

=head2 PUBLIC_CLOUD_AZURE_SUBSCRIPTION_ID

This is B<only for azure> and used to create the service account file.

=cut
