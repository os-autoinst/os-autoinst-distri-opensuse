# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Temporary solution to combine qam-updinstall/update_install
# and qam-updinstall/update_install_mr to conditionally load one or
# the other from a YAML schedule depending on the value of BUILD.
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use utils qw(fully_patch_system);
use power_action_utils qw(prepare_system_shutdown power_action);


sub run {
    my ($self, $run_args) = @_;

    # TODO: Fix this in the bot.
    if (get_var('BUILD') =~ /tomcat/ && get_var('HDD_1') =~ /SLED/) {
        record_info('not shipped', 'tomcat is not shipped to Desktop https://suse.slack.com/archives/C02D16TCP99/p1706675337430879');
        return;
    }

    $run_args->{msg} = 'Hi!';
    # Apply repo quirks unrelated to the incident. e.g NVIDIA repo
    autotest::loadtest("tests/qam-updinstall/repo_quirks.pm", name => 'Repo Quirks', run_args => $run_args, @_);

    # Bring the SUT to a fully released state
    autotest::loadtest("tests/qam-updinstall/prepatch.pm", name => "Prepatch", run_args => $run_args, @_);

    # Query SMELT for incident info
    autotest::loadtest("tests/qam-updinstall/smelt_info.pm", name => 'SMELT Info', run_args => $run_args, @_);

    autotest::loadtest("tests/qam-updinstall/update_install.pm", name => "Installation", run_args => $run_args, @_);

}

1;
