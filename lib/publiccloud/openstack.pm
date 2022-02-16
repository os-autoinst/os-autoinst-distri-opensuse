# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for OpenStack
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::openstack;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON 'decode_json';
use testapi;
use publiccloud::openstack_client;

has ssh_key => undef;
has ssh_key_name => undef;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->provider_client(publiccloud::openstack_client->new());
    $self->provider_client->init();
}

sub find_img {
    my ($self, $name) = @_;
    ($name) = $name =~ m/([^\/]+)$/;
    $name =~ s/\.qcow2$//;
    my $out = script_output("openstack image show $name -f json | jq -r '.id'", proceed_on_failure => 1);

    if ($out !~ /Could not find resource|No Image found/) {
        return $out;
    }
    return;
}

sub create_keypair {
    my ($self, $prefix) = @_;

    return $self->ssh_key if ($self->ssh_key);

    for my $i (0 .. 9) {
        my $key_name = $prefix . "_" . $i;
        my $cmd = "openstack keypair create --public-key /root/.ssh/id_rsa.pub $key_name";
        my $ret = script_run($cmd, timeout => 300);
        if (defined($ret) && $ret == 0) {
            $self->ssh_key_name($key_name);
            return $key_name;
        }
    }
    die("Create key-pair failed");
}

sub delete_keypair {
    my $self = shift;
    my $name = shift || $self->ssh_key_name;

    return unless $name;

    assert_script_run("openstack keypair delete " . $name);
    $self->ssh_key(undef);
}

sub upload_img {
    my ($self, $file) = @_;

    my ($img_name) = $file =~ /([^\/]+)$/;
    $img_name =~ s/\.qcow2$//;
    assert_script_run("openstack image create"
          . " --disk-format qcow2"
          . " --container-format bare"
          . " --file $file $img_name", timeout => 60 * 60);

    my $image_id = $self->find_img($img_name);
    die("Cannot find image after upload!") unless $image_id;
    record_info('INFO', "Image ID: $image_id");
    return $image_id;
}

sub terraform_apply {
    my ($self, %args) = @_;
    $args{vars} //= {};

    my $keypair = $self->create_keypair($self->prefix . time);
    my $secgroup = get_var("OPENSTACK_SECGROUP");
    $args{vars}->{keypair} = $keypair;
    $args{vars}->{secgroup} = $secgroup;
    return $self->SUPER::terraform_apply(%args);
}

sub cleanup {
    my ($self) = @_;
    $self->terraform_destroy() if ($self->terraform_applied);
    $self->delete_keypair();
    $self->provider_client->cleanup();
}

1;
