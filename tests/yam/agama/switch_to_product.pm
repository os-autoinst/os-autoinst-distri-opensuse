## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Switch VERSION to the auto installed system name and
#          reset consoles for gnome desktop/
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base Yam::Agama::agama_base;
use testapi qw(reset_consoles get_var set_var);
use scheduler 'get_test_suite_data';

sub run {
    my $self = shift;
    reset_consoles if (get_var('DESKTOP') eq 'gnome');
    set_var('VERSION', 'Tumbleweed') if (get_test_suite_data()->{os_release_name} =~ /Tumbleweed/);
}

1;
