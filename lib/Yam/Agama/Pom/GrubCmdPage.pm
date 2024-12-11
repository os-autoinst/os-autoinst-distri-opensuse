# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB cmd.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubCmdPage;
use strict;
use warnings;
use utils qw(type_string_slow);

use testapi;
use bootloader_setup;

sub new {
    my ($class, $args) = @_;
    return bless {
        max_interval => $args->{max_interval},
        key_return => 'ret'
    }, $class;
}

sub type {
    my ($self, $args) = @_;
    type_string_slow("$args ", max_interval => $self->{max_interval});
    wait_still_screen(1);
    save_screenshot();
}

sub send_return_key {
    my ($self) = @_;
    send_key($self->{key_return});
}

sub add_boot_parameters {
    my ($self) = @_;

    my $iso = get_required_var('ISO');
    my $repo = get_required_var('REPO_0');
    my $mntpoint = "mnt/openqa/repo/$repo/boot/ppc64le";

    if (my $ppc64le_grub_http = get_var('PPC64LE_GRUB_HTTP')) {
        # Enable grub http protocol to load file from OSD: (http,10.145.10.207)/assets/repo/$repo/boot/ppc64le
        $mntpoint = "$ppc64le_grub_http/assets/repo/$repo/boot/ppc64le";
        record_info("Updated boot path for PPC64LE_GRUB_HTTP defined", $mntpoint);
    }

    $self->type("linux $mntpoint/linux");
    $self->type("vga=normal");
    $self->type("console=hvc0");
    $self->type("kernel.softlockup_panic=1");
    $self->type("Y2DEBUG=1");
    if (my $extrabootparams = get_var('EXTRABOOTPARAMS')) {
        $self->type($extrabootparams);
    }
    else {
        $self->type("live.password=$testapi::password");
    }
    my $host = get_var('OPENQA_HOSTNAME', 'openqa.opensuse.org');
    $self->type("root=live:http://$host/assets/iso/$iso");
    $self->send_return_key();

    $self->type("initrd $mntpoint/initrd");
    $self->send_return_key();
}

sub boot {
    my ($self) = @_;
    enter_cmd("boot");
    prepare_disks;
    script_run("agamactl -s");
}

1;
