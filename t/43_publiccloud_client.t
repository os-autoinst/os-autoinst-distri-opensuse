# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Unit tests for the public cloud connection clients
#   (publiccloud::aws_client, publiccloud::azure_client, publiccloud::gcp_client).
#   The region / disallow logic is shared via publiccloud::client_base, so every
#   subtest exercises all three concrete clients to prove the inherited behaviour.

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use testapi 'set_var';

use publiccloud::aws_client;
use publiccloud::azure_client;
use publiccloud::gcp_client;
use publiccloud::client_base;

# Running each check against all of the CSP children classes verifies the
# shared behaviour through every concrete client.
my @CLIENTS = qw(
  publiccloud::aws_client
  publiccloud::azure_client
  publiccloud::gcp_client
);

sub _unset { for my $k (@_) { set_var($k, undef) } }

subtest '[region] default returns PUBLIC_CLOUD_REGION' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'olympus-1');
    # Also add alternate regions, even if the test does not use them.
    # It proof they do not interfere the default.
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'delphi-2 , ithaca-3,sparta-4');
    for my $class (@CLIENTS) {
        my $client = $class->new();
        is $client->region, 'olympus-1', "$class returns the single configured region";
    }
    _unset('PUBLIC_CLOUD_REGION', 'PUBLIC_CLOUD_ALTERNATE_REGIONS');
};

subtest '[region] missing PUBLIC_CLOUD_REGION dies' => sub {
    _unset('PUBLIC_CLOUD_REGION');
    for my $class (@CLIENTS) {
        my $client = $class->new();
        dies_ok { $client->region } "$class dies when PUBLIC_CLOUD_REGION is not set";
    }
};

subtest '[disable_region] ignore double disabling' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'olympus-1');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'delphi-2,ithaca-3');
    my $ret;
    for my $class (@CLIENTS) {
        my $client = $class->new();
        $client->disable_region('olympus-1');
        is $client->region, 'delphi-2', "$class skips the single not allowed region";

        # Block two times the same does not have any effect
        $client->disable_region('olympus-1');
        is $client->region, 'delphi-2', "$class skips the single not allowed region";
    }
    _unset('PUBLIC_CLOUD_REGION', 'PUBLIC_CLOUD_ALTERNATE_REGIONS');
};

subtest '[disable_region] is chainable' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'olympus-1');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'delphi-2,ithaca-3');
    my $ret;
    for my $class (@CLIENTS) {
        my $client = $class->new();
        $client->disable_region('olympus-1')->disable_region('delphi-2');
        is $client->region, 'ithaca-3', "$class skips multiple disabled regions set via chaining";
    }
    _unset('PUBLIC_CLOUD_REGION', 'PUBLIC_CLOUD_ALTERNATE_REGIONS');
};

subtest '[region] dies when all regions are blocked' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'olympus-1');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'delphi-2');
    for my $class (@CLIENTS) {
        my $client = $class->new();
        $client->disable_region('olympus-1')->disable_region('delphi-2');
        throws_ok { $client->region } qr/No available regions/,
          "$class dies with a descriptive error when every region is disabled";
    }
    _unset('PUBLIC_CLOUD_REGION', 'PUBLIC_CLOUD_ALTERNATE_REGIONS');
};

subtest '[disable_region] state is isolated per instance' => sub {
    set_var('PUBLIC_CLOUD_REGION', 'olympus-1');
    set_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', 'delphi-2');
    for my $class (@CLIENTS) {
        my $first = $class->new();
        my $second = $class->new();
        $first->disable_region('olympus-1');
        is $first->region, 'delphi-2', "$class first instance sees its own blocked list";
        is $second->region, 'olympus-1', "$class second instance is not affected by the first (per-instance hash)";
    }
    _unset('PUBLIC_CLOUD_REGION', 'PUBLIC_CLOUD_ALTERNATE_REGIONS');
};

done_testing;
