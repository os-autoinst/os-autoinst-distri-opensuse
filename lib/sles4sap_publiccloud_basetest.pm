package sles4sap_publiccloud_basetest;

use base 'consoletest';
use Mojo::Base 'publiccloud::basetest';
use strict;
use warnings FATAL => 'all';
use testapi;
use qesapdeployment;
use sles4sap_publiccloud;

sub cleanup {
    my ($self) = @_;
    die("Cleanup already called") if ($self->{cleanup_called});
    $self->{cleanup_called} = 1;
    qesap_execute(verbose => "--verbose", cmd => "terraform", cmd_options => "-d", timeout => 600);
    record_info("Cleanup executed");
}

sub post_fail_hook {
    my ($self) = @_;
    return if (get_var("PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE"));
    $self->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
    return if ($self->test_flags()->{publiccloud_multi_module})
      or (get_var("PUBLIC_CLOUD_NO_CLEANUP"));
    $self->cleanup();
}

1;
