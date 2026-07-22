# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the system registered against the expected registration server
#          (SCC or proxySCC) based on /etc/SUSEConnect and the openQA SCC_URL variable.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use version_utils qw(is_sle);
use List::Util 'first';

sub run {
    select_console 'root-console';

    # Skip the validation for SLES16.0 if it is registered against SCC, there isn't /etc/SUSEConnect file
    return 1 if is_sle('<16.1') && get_var('SCC_URL', '') eq '';

    my $scc_url = get_var('SCC_URL', '');
    my $system_url = script_output("awk '/^url:/ {print \$2}' /etc/SUSEConnect");

    record_info('REG_SERVER', "openQA SCC_URL: '$scc_url'\nDetected/Fallback url: '$system_url'");

    my @validation_rules = (
        {
            type => 'SCC',
            env_pattern => qr/^$/,
            sys_pattern => qr{^https://scc\.suse\.com},
            error_message => "Expected direct SCC 'https://scc.suse.com', but found '$system_url'",
        },
        {
            type => 'proxySCC',
            env_pattern => qr/proxy/i,
            sys_pattern => qr/proxy/i,
            error_message => "openQA SCC_URL contains 'proxy', but /etc/SUSEConnect ('$system_url') does not",
        },
    );

    my $matched_rule = first { $scc_url =~ $_->{env_pattern} } @validation_rules
      or die("Unknown or unhandled SCC_URL format in openQA setting: '$scc_url'");

    $system_url =~ $matched_rule->{sys_pattern}
      or die("Registration server mismatch! $matched_rule->{error_message}");
}

1;
