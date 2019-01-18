# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify PCM Azure patterns and basic checks on packages
#
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use version_utils 'is_sle';

sub run {
    return record_info('No azurectl available on SLE 15, skipping') if is_sle('15+');

    select_console('root-console');
    # Check if can get version
    record_soft_failure('bsc#1105223') if (script_run('azurectl -v') != 0);
    # Define test data
    my $rsa_key      = '~/.ssh/id_rsa';
    my $azure_key    = 'azure.pem';
    my $account_name = 'test_azure';
    my $url          = 'http://url.endpoint';
    my $subscr_id    = '00000000-0000-0000-0000-000000000000';
    my $config_path  = "~/.config/azurectl/$account_name.config";
    # Generate pem key to stub missing azure key
    script_run "ssh-keygen -t rsa -b 2048 -f $rsa_key -N ''";
    script_run "openssl rsa -in $rsa_key -outform pem > $azure_key";
    # Setup azure account to validate config file
    assert_script_run qq{azurectl setup account configure \\
      --name $account_name \\
      --management-pem-file $azure_key \\
      --management-url $url \\
      --subscription-id $subscr_id};

    # Validate config file
    die "Azure config file was not created, expected path: $config_path" if (script_run("[[ -f $config_path ]]") != 0);

    # Get config file content
    my $config = script_output "cat $config_path";
    # Validate entries
    my $errors = '';
    $errors .= "Account $account_name is not set as default_account\n"      unless $config =~ /default_account\s*=\s*account:$account_name/;
    $errors .= "Account section for $account_name is not added\n"           unless $config =~ /\[account:$account_name\]/;
    $errors .= "Pem file $azure_key is not set as management_pem_file\n"    unless $config =~ /management_pem_file\s*=\s*$azure_key/;
    $errors .= "Mgmt url $url is not set as management_url\n"               unless $config =~ /management_url\s*=\s*$url/;
    $errors .= "Subscription id $subscr_id is not set as subscription_id\n" unless $config =~ /subscription_id\s*=\s*$subscr_id/;

    die $errors if $errors;
}

1;
