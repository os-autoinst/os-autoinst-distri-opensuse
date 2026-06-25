# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the self-update is performed by Agama via /etc/live-self-update/result
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils qw(systemctl);
use scheduler qw(get_test_suite_data);

sub run {
    my $self_update_enabled = get_test_suite_data()->{self_update_enabled};
    if ($self_update_enabled) {
        my $systemctl_output = script_output('systemctl status live-self-update.service', proceed_on_failure => 1);
        unless ($systemctl_output =~ /status=0\/SUCCESS/) {
            die "Self update did not end successfully";
        }

        my $self_update_url = get_var('SCC_URL') =~ /proxy/
          ? get_var('SCC_URL')
          : get_var('INST_SELF_UPDATE', 'https://scc.suse.com');
        assert_script_run("journalctl -t live-self-update --no-pager | grep 'Will use a custom registration server " .
              "$self_update_url for obtaining the self-update repository'");
    } else {
        systemctl('is-active live-self-update', expect_false => 1);
        assert_script_run("journalctl -t live-self-update | grep \"Self update not configured\"");
    }
}

1;
