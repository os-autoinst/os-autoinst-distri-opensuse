# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify PCM AWS patterns and basic checks on packages
#
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;


sub run {
    select_console('root-console');
    # Check if can get version
    assert_script_run 'aws --version';
    # Define test data
    my %configure = (
        access_key_id     => 'default_access_key',
        secret_access_key => 'default_secret_key',
        output            => 'json',
        region            => 'eu-west-1',
    );
    # Setup configuration
    assert_script_run("aws configure set $_ $configure{$_}") foreach (keys %configure);
    # Validate config file
    my $conf_path = '~/.aws/config';
    die "AWS config file not created, expected path: $conf_path" if (script_run("[[ -f $conf_path ]]") != 0);
    my $conf = script_output "cat $conf_path";
    # Validate default entries
    my $errors = '';
    $errors .= "Output format $configure{output} not set\n"                unless $conf =~ /output\s*=\s*$configure{output}/;
    $errors .= "Region name $configure{region} not set\n"                  unless $conf =~ /region\s*=\s*$configure{region}/;
    $errors .= "Access Key ID $configure{access_key_id} not set\n"         unless $conf =~ /access_key_id\s*=\s*$configure{access_key_id}/;
    $errors .= "Secret access key $configure{secret_access_key} not set\n" unless $conf =~ /secret_access_key\s*=\s*$configure{secret_access_key}/;
    die $errors if $errors;
}

1;
