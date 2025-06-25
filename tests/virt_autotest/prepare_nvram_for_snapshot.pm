# SUSE's openQA tests
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Prepare qcow2 format nvram template files to run uefi vm snapshot test.
#   The converted nvram template file(s) is used in uefi vm's configuration
#   file under data/virt_autotest/guest_params_xml_files/.
# Maintainer: qe-virt@suse.de, Xiaoli Ai<xlai@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    unless (get_var('SNAPSHOT_NVRAM_TEMPLATE_SRC', '') ne '') {
        record_info("Empty SNAPSHOT_NVRAM_TEMPLATE_SRC, skip converting.");
        return 1;
    }

    my @snapshot_nvram_template_src = split(/,/, get_var('SNAPSHOT_NVRAM_TEMPLATE_SRC', ''));
    my @snapshot_nvram_template_new = split(/,/, get_var('SNAPSHOT_NVRAM_TEMPLATE_NEW', ''));
    my $nvram_template_dir = '/usr/share/qemu';
    while (my ($index, $src) = each @snapshot_nvram_template_src) {
        my $new = "$nvram_template_dir/$snapshot_nvram_template_new[$index]";
        assert_script_run("qemu-img convert -O qcow2 $nvram_template_dir/$src $new");
        assert_script_run("qemu-img info $new");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
