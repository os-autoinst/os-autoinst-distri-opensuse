# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Push a container image to the Public Cloud Registry
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::k8sbasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::urls 'get_image_uri';

sub run {
    my ($self, $run_args) = @_;
    my $provider = undef;
    my $container_registry_service = undef;
    my $public_cloud_provider = shift(@{$run_args->{provider}});

    die "Test called without \$run_args->{provider} denied" unless defined($public_cloud_provider);


    select_serial_terminal;

    $container_registry_service = $self->get_container_registry_service_name($public_cloud_provider);
    $provider = $self->provider_factory(provider => $public_cloud_provider, service => $container_registry_service);

    my $image = get_image_uri();
    my $tag = $provider->get_default_tag();
    $self->{image_tag} = $run_args->{image_tag} = $tag;

    record_info('Pull', "Pulling $image");
    assert_script_run("podman pull $image", 360);

    my $image_build_format = '{{ index .Config.Labels "org.opencontainers.image.version" }}';
    my $image_build = script_output("podman image inspect $image --format='$image_build_format'");
    record_info('Img version', $image_build);

    my $image_name = $provider->push_container_image($image, $tag);
    record_info('Registry',
        "Image successfully uploaded to $container_registry_service:\n$image_name\ntag:$tag\n\n\n" . script_output("podman inspect $image_name"));
}

sub cleanup {
    my ($self) = @_;
    record_info('INFO', "Deleting image $self->{image_tag}");
    $self->{provider}->delete_image($self->{image_tag});
}

sub post_fail_hook {
    my ($self) = @_;
    $self->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
}

sub test_flags {
    return {fatal => 0};
}

1;
