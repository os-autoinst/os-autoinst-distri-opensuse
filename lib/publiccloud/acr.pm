# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Azure Container Registry (ACR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>

package publiccloud::acr;
use Mojo::Base 'publiccloud::k8s_provider';
use testapi;
use utils;

has security_token => undef;
has key_id => undef;
has key_secret => undef;
has subscription => undef;
has tenantid => undef;

sub init {
    my ($self, %args) = @_;
    $self->SUPER::init("ACR");
    $self->configure_podman();
}

=head2 delete_image
Delete a ACR image
=cut

sub delete_image {
    my ($self, $tag) = @_;
    $tag //= $self->get_default_tag();
    record_info('INFO', "Deleting image $tag");
    assert_script_run(
        "az acr repository delete --yes --name " . $self->provider_client->container_registry . " --image " . $tag);
    return;
}

sub cleanup() {
    my ($self) = @_;
    $self->provider_client->cleanup();
}

1;
