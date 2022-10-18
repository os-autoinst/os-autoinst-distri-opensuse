# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: vorbis-tools libvorbis0
# Summary: Test basic functionality of libvorbis audio compression format.
# - Install vorbis-tools libvorbis0
# - Download sample from datadir
# - Get info on sample file and check
# - run ogginfo on sample and check
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use version_utils 'is_sle';
use registration 'add_suseconnect_product';

sub run {
    # setup
    my ($self) = @_;
    select_serial_terminal;

    add_suseconnect_product('sle-module-desktop-applications') if is_sle && !main_common::is_updates_tests();
    zypper_call 'in vorbis-tools libvorbis0';
    # download ogg sample
    assert_script_run 'curl -v -o sample.ogg ' . data_url('libvorbis/glass.ogg');
    # ogg file info
    assert_script_run("file sample.ogg | grep \"sample.ogg: Ogg data, Vorbis audio, stereo, 44100 Hz, ~192000 bps, created by: Xiph.Org libVorbis I\"");
    # test ogginfo
    assert_script_run("ogginfo sample.ogg 2>&1 | grep -Pz '(?s)(?=.*Processing file \"sample.ogg\")(?=.*Channels: 2)(?=.*Rate: 44100)(?=.*Total data length: 15170 bytes)(?=.*Playback length: 0m:00.751s)(?=.*Average bitrate: 161.418024 kb/s)'");
}

1;
