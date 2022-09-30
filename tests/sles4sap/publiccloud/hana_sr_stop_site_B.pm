use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings FATAL => 'all';

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    my $site_b = $run_args->{site_b};

    $self->select_serial_terminal;

    # Switch to control Site B (currently PROMOTED)
    $self->{my_instance} = $site_b;

    record_info("Stop DB", "Stopping Site B ('$site_b->{instance_id}')");
    $self->stop_hana();

    record_info("Takeover check");
    $self->check_takeover;

    record_info("Replication", "Enabling replication on Site B (DEMOTED)");
    $self->enable_replication();

    record_info("Site B start");
    $self->cleanup_resource();

    record_info("Done", "Test finished");
}

1;