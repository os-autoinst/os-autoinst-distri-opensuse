# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for terraform tests
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

package terraform::basetest;
use Mojo::Base 'opensusebasetest';
use testapi;
use terraform::libvirt_domain;
use terraform::host;
use Data::Dumper;
use Mojo::JSON 'decode_json';
use MIME::Base64;

use constant TERRAFORM_TIMEOUT => 600;
use constant WORKDIR           => '/root/terraform';

=head2 _run_terraform_cmd

    _run_terraform_cmd();

Runs terraform command given by C<cmd>

=cut
sub _run_terraform_cmd {
    my ($self, $cmd) = @_;
    my $output = script_output($cmd, TERRAFORM_TIMEOUT);
    record_info('TFM CMD', $cmd . "\n\n" . $output) if check_var('DEBUG', 1);
    return $output;
}

=head2 _prepare_ssh

    _prepare_ssh();

Copy the private ssh key to access the remote host without password.
The remote host must have the public key in authorized_keys

=cut
sub _prepare_ssh {
    my ($self) = @_;
    my $private_key = get_required_var('PRIVATE_KEY');
    assert_script_run('echo "' . decode_base64($private_key) . '" > /root/.ssh/id_rsa');
    assert_script_run('chmod 600 /root/.ssh/id_rsa');
}

=head2 deploy_test_env

    deploy_test_env();

Deploys the given Terraform C<tf_file> file on the Terraform VM which will create
the environment on the remote host.

=cut
sub deploy_test_env {
    my ($self, $tf_file) = @_;
    my @domains;
    $self->_prepare_ssh();
    assert_script_run('mkdir -p ' . WORKDIR);
    assert_script_run('cd ' . WORKDIR);
    assert_script_run('curl ' . data_url($tf_file) . ' -o ./test.tf');

    my $host = terraform::host->new(
        ip   => get_required_var('REMOTE_HOST_IP'),
        user => get_required_var('REMOTE_HOST_USER')
    );
    record_info('HOST', Dumper $host) if check_var('DEBUG', 1);

    my $sut_hdd_url = get_required_var('SUT_HDD');
    die("Invalid SUT_HDD url ") unless ($sut_hdd_url =~ m|([^/]+)/?$|);
    my $hdd_name = $1;

    #$host->run_ssh_command("wget -q $sut_hdd_url -O /root/$hdd_name");
    assert_script_run("wget -q $sut_hdd_url");
    $self->_run_terraform_cmd('terraform init');
    $self->_run_terraform_cmd('terraform apply -auto-approve -var "hdd=' . WORKDIR . '/' . $hdd_name . '" -var "remote_ip=' . $host->{ip} . '"');

    my $vms       = decode_json($self->_run_terraform_cmd('terraform output -json vm_names'))->{value};
    my $ips       = decode_json($self->_run_terraform_cmd('terraform output -json vm_ips'))->{value};
    my @ips_array = map { $_->[0] } @{$ips};

    if (get_var('DEBUG')) {
        record_info('IPS',   Dumper(\@ips_array));
        record_info('NAMES', Dumper($vms));
        for my $i (@ips_array) {
            record_info("IP", $i);
        }
    }

    foreach my $i (0 .. $#{$vms}) {
        my $domain = terraform::libvirt_domain->new(
            domain_name => @{$vms}[$i],
            domain_ip   => $ips_array[$i],
            host        => $host
        );
        record_info('INFO', "Domain created: " . @{$vms}[$i] . "\n" . Dumper $domain) if check_var('DEBUG', 1);
        $domain->init();
        record_info('INFO', "Domain initialized: " . @{$vms}[$i] . "\n" . Dumper $domain);
        push @domains, $domain;
    }
    return @domains;
}

=head2 destroy_test_env

    destroy_test_env();

Destroys the Terraform environment on the remote host.

=cut
sub destroy_test_env {
    my ($self) = @_;
    my $sut_hdd_url = get_required_var('SUT_HDD');
    $sut_hdd_url =~ m|([^/]+)/?$|;
    my $hdd_name = $1;
    $self->_run_terraform_cmd('terraform destroy -auto-approve -var "hdd=' . WORKDIR . '/' . $hdd_name . '" -var "remote_ip=' . get_required_var('REMOTE_HOST_IP') . '"');
}


sub post_fail_hook {
    my ($self) = @_;
    $self->destroy_test_env();
}

sub post_run_hook {
    my ($self) = @_;
    $self->destroy_test_env();
}

1;
