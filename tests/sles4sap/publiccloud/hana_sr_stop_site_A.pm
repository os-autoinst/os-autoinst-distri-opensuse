use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings FATAL => 'all';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    my $site_a = $run_args->{site_a};

    $self->select_serial_terminal;

    # Switch to control Site A (currently PROMOTED)
    $self->{my_instance} = $site_a;

    record_info("Stop DB", "Stopping Site A ('$site_a->{instance_id}')");
    $self->stop_hana();

    record_info("Takeover check");
    $self->check_takeover;

    record_info("Replication", "Enabling replication on Site A (DEMOTED)");
    $self->enable_replication();

    record_info("Site A start");
    $self->cleanup_resource();

    record_info("Done", "Test finished");

}

1;
