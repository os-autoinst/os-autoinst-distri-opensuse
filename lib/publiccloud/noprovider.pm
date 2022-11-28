# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for dummy provider
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::noprovider;
use Mojo::Base 'publiccloud::provider';
use testapi;
use publiccloud::existing;

has ssh_key => undef;
has ssh_key_file => undef;
has username => sub { get_var('PUBLIC_CLOUD_USER', 'root') };

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->provider_client(publiccloud::existing->new());
}

sub create_instances {
    my ($self, %args) = @_;
    $args{check_connectivity} //= 1;

    my @vms;
    my $instance = publiccloud::instance->new(
        public_ip => get_required_var('PUBLIC_CLOUD_INSTANCE_IP'),
        username => get_required_var('PUBLIC_CLOUD_USER'),
        ssh_key => '~/.ssh/id_rsa',
        provider => $self
    );
    # Install server's ssh publicckeys to prevent authenticity interactions
    assert_script_run(sprintf('ssh-keyscan %s >> ~/.ssh/known_hosts', $instance->public_ip));
    push @vms, $instance;
    return @vms;
}

sub create_ssh_key {
    my ($self, %args) = @_;
    $args{ssh_private_key_file} //= '~/.ssh/id_rsa';
    assert_script_run('SSH_DIR=`dirname ' . $args{ssh_private_key_file} . '`; mkdir -p $SSH_DIR');

    # How to generate and use SSH KEY:
    # Run those on the SUT manually:
    # 1. Generate the key pair
    #   ssh-keygen -t rsa -b 2048
    # 2. Get the private key without new lines and use it as _SECRET_PUBLIC_CLOUD_INSTANCE_SSH_KEY
    #   awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ~/.ssh/id_rsa; echo
    # 3. Put the key to authorized_keys
    #   cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    my $ssh_key = get_required_var('_SECRET_PUBLIC_CLOUD_INSTANCE_SSH_KEY');

    script_run("echo -e \"$ssh_key\" > $args{ssh_private_key_file}; chmod 0700 $args{ssh_private_key_file}");
}

sub cleanup {
    my ($self) = @_;
    # Do nothing with existing instance.
}

sub destroy {
    my ($self) = @_;
    # Do nothing with existing instance.
}

1;
