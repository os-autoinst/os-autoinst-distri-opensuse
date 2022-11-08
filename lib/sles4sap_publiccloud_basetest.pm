# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Base test providing cleanup, post fail and post run hooks for tests using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

package sles4sap_publiccloud_basetest;

use Mojo::Base 'publiccloud::basetest';
use strict;
use warnings FATAL => 'all';
use Exporter 'import';
use testapi;
use qesapdeployment;

our @EXPORT = qw(cleanup);


sub cleanup {
    my ($self) = @_;
    # Do not run destroy if already executed
    return if ($self->{cleanup_called});
    $self->{cleanup_called} = 1;

    for my $command ("ansible", "terraform") {

        # Skip cleanup if ansible inventory is not present (deployment could not have been done without it)
        my $inventory_check_cmd = join(" ", ("test", "-f", qesap_get_inventory()));
        next if script_run($inventory_check_cmd) == 0;

        record_info("Cleanup", "Executing $command cleanup");
        # 3 attempts for both terraform and ansible cleanup
        for (1 .. 3) {
            my $cleanup_cmd_rc = qesap_execute(verbose => "--verbose", cmd => $command, cmd_options => "-d", timeout => 1200);
            if ($cleanup_cmd_rc == 0) {
                diag(ucfirst($command) . " cleanup attempt # $_ PASSED.");
                record_info("Clean $command", ucfirst($command) . " cleanup PASSED.");
                last;
            }
            else {
                diag(ucfirst($command) . " cleanup attempt # $_ FAILED.");
                sleep 10;
            }
            record_info("Cleanup FAILED", "Cleanup $command FAILED", result => "fail") if $_ == 3 && $cleanup_cmd_rc;
            $self->{result} = "fail" if $_ == 3 && $cleanup_cmd_rc;
        }
    }
    record_info("Cleanup finished");
}

sub post_fail_hook {
    my ($self) = @_;
    if (get_var("PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE")) {
        diag("Skip post fail", "Variable 'PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE' defined.");
        return;
    }
    $self->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
    if ($self->test_flags()->{publiccloud_multi_module} or get_var("PUBLIC_CLOUD_NO_CLEANUP")) {
        diag("Skip post run", "Skipping post run hook. \n Variable 'PUBLIC_CLOUD_NO_CLEANUP' defined or test_flag 'publiccloud_multi_module' active");
        return;
    }
    $self->cleanup();
}

1;
