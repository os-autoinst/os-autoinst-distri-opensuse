## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# run playwright tests directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::agama::agama_base;
use strict;
use warnings;

use testapi qw(
  assert_script_run
  assert_screen
  get_required_var
  enter_cmd
);

sub run {
    my $self = shift;
    my $test = get_required_var('AGAMA_TEST');

    assert_script_run("playwright test --trace on --project chromium --config /usr/share/e2e-agama-playwright tests/" . $test . ".spec.ts", timeout => 1200);
    $self->upload_traces();
    enter_cmd 'reboot';
}

sub post_run_hook {
    my ($self) = shift;
    assert_screen([qw(grub2-agama encrypted-disk-password-prompt)], 120);
    $self->SUPER::post_run_hook;
}

1;
