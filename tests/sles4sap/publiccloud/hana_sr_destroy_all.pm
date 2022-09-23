package hana_sr_destroy_all;

use parent 'Exporter';
use strict;
use warnings FATAL => 'all';
use Mojo::Base 'publiccloud::basetest';
use testapi;

sub test_flags {
    return {
        fatal => 1,
    };
}

sub run {
    my ($self) = @_;
    if (get_var('INSTANCES_IMPORT') or get_var('INSTANCES_EXPORT')) {
        record_info("No cleanup", "Cleanup skipped - 'INSTANCE_IMPORT' or 'INSTANCE_EXPORT' variable defined");
        return;
    }

    record_info("Cleanup", "Destroying public cloud instances.");
    $self->terraform_destroy();
}

1;