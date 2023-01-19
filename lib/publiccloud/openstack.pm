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

has ssh_key_name => undef;
has public_ip => undef;
has instance_id => undef;

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
    return $self->ssh_key if ($self->ssh_key and $self->ssh_key_name);

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
    return unless $self->{ssh_key_name};

    assert_script_run("openstack keypair delete " . $self->{ssh_key_name});
    $self->ssh_key_name(undef);
}

sub delete_floating_ip {
    my $self = shift;

    script_run("openstack server remove floating ip $self->{instance_id} $self->{public_ip}", timeout => 120);
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
    my @instances = $self->SUPER::terraform_apply(%args);
    $self->public_ip($instances[0]->{public_ip});
    $self->instance_id($instances[0]->{instance_id});
    return @instances;
}

sub cleanup {
    my ($self) = @_;
    $self->terraform_destroy() if ($self->terraform_applied);
    $self->delete_keypair();
    $self->provider_client->cleanup();
    $self->delete_floating_ip();
}

1;
