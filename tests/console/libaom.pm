# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# jira feature PED-11076
#
# Package: libaom
# Summary: Basic tests for ffmpeg with libaom
#    1. Install the denpendence packages
#    2. Re-compile ffmpeg with --enable-libaom
#    3. Change mp4 file with av encoder to yuv file
# Maintainer: qe-core <qe-core@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    zypper_call 'in libaom-devel cmake gcc gcc-c++ git make libtool nasm wget';
    assert_script_run 'mkdir -p ~/ffmpeg_sources';

    # Re-compile ffmpeg https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 with --enable-libaom
    assert_script_run 'cd ~/ffmpeg_sources';
    assert_script_run 'wget --quiet ' . data_url('libaom/ffmpeg-snapshot.tar.bz2');
    assert_script_run 'tar xjvf ffmpeg-snapshot.tar.bz2';
    assert_script_run 'cd ffmpeg';
    assert_script_run "PATH=\"\$HOME/bin:\$PATH\" PKG_CONFIG_PATH=\"\$HOME/ffmpeg_build/lib/pkgconfig\" ./configure --prefix=\"\$HOME/ffmpeg_build\" --pkg-config-flags=\"--static\" --extra-cflags=\"-I\$HOME/ffmpeg_build/include\" --extra-ldflags=\"-L\$HOME/ffmpeg_build/lib\" --extra-libs=-lpthread --extra-libs=-lm --bindir=\"\$HOME/bin\" --enable-libaom";

    assert_script_run('make', timeout => 800);
    assert_script_run 'make install';

    # Change mp4 file with av encoder to yuv file
    assert_script_run 'cd ~/ffmpeg_sources';
    assert_script_run 'wget --quiet ' . data_url('libaom/input.mp4');
    assert_script_run('ffmpeg -c:v libaom-av1 -i input.mp4 -f rawvideo input_yuv', timeout => 50);
}

1;
