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

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';

sub run {
    select_serial_terminal;
    install_package('libaom-devel gcc make nasm wget bzip2', trup_reboot => 1);
    assert_script_run 'mkdir -p ~/ffmpeg_sources';

    # Re-compile ffmpeg https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 with --enable-libaom
    assert_script_run 'cd ~/ffmpeg_sources';
    assert_script_run 'wget --quiet ' . data_url('libaom/ffmpeg-snapshot.tar.bz2');
    assert_script_run 'tar xjf ffmpeg-snapshot.tar.bz2';
    assert_script_run 'cd ffmpeg';
    # Build only what the AV1 decode below needs, plus the libaom
    # encoder wrapper so it still compiles against libaom-devel; a full
    # ffmpeg build compiles about 8x more objects.
    my @configure = (
        '--prefix="$HOME/ffmpeg_build"', '--bindir="$HOME/bin"',
        '--pkg-config-flags="--static"', '--extra-libs=-lpthread', '--extra-libs=-lm',
        '--disable-everything', '--disable-autodetect', '--disable-network', '--disable-doc',
        '--disable-ffplay', '--disable-ffprobe',
        '--enable-libaom', '--enable-decoder=libaom_av1', '--enable-encoder=libaom_av1',
        '--enable-demuxer=mov', '--enable-encoder=rawvideo', '--enable-muxer=rawvideo',
        '--enable-protocol=file');
    assert_script_run("./configure @configure", timeout => 600);
    assert_script_run('make -j$(nproc)', timeout => 1200);
    assert_script_run 'make install';

    # Change mp4 file with av encoder to yuv file
    assert_script_run 'cd ~/ffmpeg_sources';
    assert_script_run 'wget --quiet ' . data_url('libaom/input.mp4');
    assert_script_run('ffmpeg -c:v libaom-av1 -i input.mp4 -f rawvideo input_yuv', timeout => 50);
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
