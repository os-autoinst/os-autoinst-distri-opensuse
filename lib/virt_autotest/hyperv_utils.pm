# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Utilities for executing commands on Hyper-V hosts, allowing interaction
#          with Hyper-V plugins and managing the Hyper-V environment within openQA tests.
# Maintainer: Roy.Cai@suse.com, qe-virt@suse.de

package virt_autotest::hyperv_utils;


use base 'Exporter';
use Exporter;
use base 'installbasetest';
use testapi;
use utils;
use strict;
use warnings;


# Export 'hyperv_cmd' so it can be used outside the package
our @EXPORT = qw(
  hyperv_cmd
  hyperv_cmd_with_retry
);

sub hyperv_cmd {
    my ($cmd, $args) = @_;
    $args->{ignore_return_code} ||= 0;
    my $ret = console('svirt')->run_cmd($cmd);
    diag "Command on Hyper-V returned: $ret";
    die 'Command on Hyper-V failed' unless ($args->{ignore_return_code} || !$ret);
    return $ret;
}

sub hyperv_cmd_with_retry {
    my ($cmd, $args) = @_;
    die 'Command not provided' unless $cmd;

    my $attempts = $args->{attempts} // 7;
    my $sleep = $args->{sleep} // 300;
    # Common messages
    my @msgs = $args->{msgs} // (
        'Failed to create the virtual hard disk',
        'The operation cannot be performed while the object is in use',
        'The process cannot access the file because it is being used by another process',
        'Access is denied.'
    );
    for my $retry (1 .. $attempts) {
        my ($ret, $stdout, $stderr) = console('svirt')->run_cmd($cmd, wantarray => 1);
        # return when powershell returns 0 (SUCCESS)
        return {success => 1} if $ret == 0;

        diag "Attempt $retry/$attempts: Command failed";
        my $msg_found = 0;
        foreach my $msg (@msgs) {
            diag "Looking for message: '$msg'";
            # Narrow the error message for an easy match
            # Remove Windows-style new lines (<CR><LF>)
            $stdout =~ s/\r\n//g;
            $stderr =~ s/\r\n//g;
            # Error message is not the expected error message in this cycle,
            # try the next one
            if ($stdout =~ /$msg/ || $stderr =~ /$msg/) {
                $msg_found = 1;
                # Error message is the expected one, sleep
                diag "Sleeping for $sleep seconds...";
                sleep $sleep;
                last;
            }
        }
        # Error we don't know if we should attempt to recover from
        return {success => 0, error => "Command failed with unhandled error"} unless $msg_found;
    }
    return {success => 0, error => "Run out of attempts"};
}

1;
