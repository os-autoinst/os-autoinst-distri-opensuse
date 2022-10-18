# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Stress test the virtio serial terminal with long output.
# Maintainer: cfamullaconrad@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Mojo::Util qw(sha1_sum trim);
use Mojo::File 'path';
use serial_terminal;

sub create_test_data
{
    my $size = shift // 1024 * 1024;
    my $line_length = shift // 79;
    my @a = ('a' .. 'z', 'A' .. 'Z', 0 .. 9);

    my $data = "";
    for (my $i = 1; $i < $size; $i++) {
        if ($i > 0 && ($i % $line_length) == 0) {
            $data .= $/;
        } else {
            $data .= $a[($i) % @a];
        }
    }
    $data .= $/;
    return $data;
}

sub run {
    my $self = shift;
    my $size = get_var('VIRTIO_CONSOLE_TEST_FILESIZE') // 200 * 1024;
    my $repeat = 1000;

    select_serial_terminal;

    # prepare upload directory
    system('mkdir -p ulogs/') == 0 or die('Failed to create ulogs/ directory');

    my $filename = "original_$size.txt";
    my $testdata = create_test_data($size);
    path('ulogs/' . $filename)->spurt($testdata);
    save_tmp_file($filename, $testdata);
    assert_script_run('curl -O ' . autoinst_url . "/files/" . $filename);
    my $sha1sum = sha1_sum(trim($testdata));    # cause script_output() trim the data
    record_info("FILE", "SHA1: $sha1sum\nSIZE: $size");
    $testdata = undef;    # free

    for (my $i = 0; $i < $repeat; $i++) {
        my $output = undef;
        eval {
            script_run("echo 'RUN: $i'", quiet => 1, timeout => 10);
            $output = script_output('cat ' . $filename, quiet => 1, timeout => 10, proceed_on_failure => 1);
        };
        if (!defined($output)) {
            record_info("TIMEOUT ERROR", result => 'fail');
            type_string(qq(\c\\));    # Send QUIT signal
            $output = wait_serial(serial_term_prompt(), no_regex => 1, record_output => 1, timeout => 10);
            record_info("OUTPUT ON TIMEOUT", $output // 'undef');
            die("Ooops: this should not happen! Timeout appear, check serial_terminal.txt for last output\n" . $@);
        }
        my $sha1sum_2 = sha1_sum($output);
        if ($sha1sum eq $sha1sum_2) {
            record_info('OK ' . $i);
        } else {
            script_run("cat /sys/kernel/debug/virtio-ports/*");
            record_info("FAILED $i", "ORIG: $sha1sum\nFAIL: $sha1sum_2", result => 'fail');
            path('ulogs/failed')->spurt($output);
            record_info('DIFF', scalar(`diff  ulogs/$filename ulogs/failed`)) if (system('diff --help') == 0);
            die("OUTPUT MISSMATCH");
        }
    }
}

sub test_flags {
    return {always_rollback => 1};
}


1;

=head1 Configuration
Testing virtio or svirt serial console.

NOTE: test is using C<select_serial_terminal()> therefore
VIRTIO_CONSOLE resp. SERIAL_CONSOLE must *not* be set to 0
(otherwise root-console will be used).

=head2 Example

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_sdk_installed.qcow2
VIRTIO_CONSOLE_TEST=1

=head2 VIRTIO_CONSOLE_TEST_FILESIZE

File size which will be used to C<cat> to get the output from. Default is 1mb.

=cut
