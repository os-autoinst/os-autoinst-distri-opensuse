use strict;
use warnings;
use FindBin '$Bin';
use Archive::Tar;
use Cwd qw(getcwd);
use File::Temp qw(tempdir);
use IO::Compress::Gzip qw(gzip $GzipError);
use MIME::Base64 qw(encode_base64);
use Test::More;
use Test::Warnings;

# The recovery loop sleeps 10 seconds between its 18 attempts. Record the
# intervals and return at once so the failure paths finish fast.
our @sleep_args;

BEGIN { *CORE::GLOBAL::sleep = sub { push @sleep_args, $_[0]; return 0 }; }

do "$Bin/../tests/virt_autotest/login_console.pm"
  or die $@ || $! || 'Failed to load tests/virt_autotest/login_console.pm';

# record_info needs a running openQA test instance; collect the calls instead
our @recorded;
{
    no warnings qw(once redefine);
    *login_console::record_info = sub { push @recorded, [@_] };
}

my $BEGIN_MARKER = '=====OPENQA-EMERGENCY-LOGS-BEGIN=====';
my $END_MARKER = '=====OPENQA-EMERGENCY-LOGS-END=====';
my @emergency_files = qw(journal.log failed_units.log cmdline.log fstab storage.log);

# Return the bytes of an uncompressed tar archive with the given members.
# Archive::Tar writes the zero blocks that terminate the archive.
sub tar_bytes {
    my (@members) = @_;
    my $tar = Archive::Tar->new;
    $tar->add_data($_, "content of $_\n") for @members;
    return $tar->write;
}

sub gzip_bytes {
    my ($bytes) = @_;
    my $gzipped = '';
    gzip \$bytes => \$gzipped or die "gzip failed: $GzipError";
    return $gzipped;
}

sub emergency_members {
    return map { "emergency_mode_logs/$_" } @emergency_files;
}

# Return one complete marked block: BEGIN line, base64 body, END line.
sub marked_block {
    my ($payload) = @_;
    return join('', $BEGIN_MARKER, "\n", encode_base64($payload), $END_MARKER, "\n");
}

# Return one marked block with the given text written verbatim between the
# markers. The text is not encoded and not checked.
sub raw_block {
    my ($body) = @_;
    return join('', $BEGIN_MARKER, "\n", $body, "\n", $END_MARKER, "\n");
}

# Return the offset of the 512-byte tar header block that holds the given
# member name. Data blocks hold "content of ..." text, so the name followed by
# a NUL byte identifies a header block. Return nothing when no header holds it.
sub header_offset {
    my ($tar, $name) = @_;
    for (my $offset = 0; $offset + 512 <= length $tar; $offset += 512) {
        return $offset if index(substr($tar, $offset, 512), $name . "\0") >= 0;
    }
    return;
}

sub write_console_log {
    my ($content) = @_;
    my $created = mkdir 'ulogs';
    die "create ulogs: $!" unless $created || -d 'ulogs';
    open(my $fh, '>', 'ulogs/hardware-console-log.txt') or die "write console log: $!";
    print $fh $content or die "write console log: $!";
    close $fh or die "close console log: $!";
}

# Read the bytes of a file. Return nothing when the file is missing, so a
# regression fails one assertion instead of the whole test file.
sub slurp_bytes {
    my ($path) = @_;
    return unless -e $path;
    open(my $fh, '<', $path) or return;
    binmode $fh;
    local $/;
    my $content = <$fh>;
    close $fh or return;
    return $content;
}

# Both subs use paths relative to the current directory, so run every case in
# a new empty directory and go back afterwards.
sub in_fresh_dir {
    my ($code) = @_;
    my $original = getcwd();
    my $dir = tempdir(CLEANUP => 1);
    chdir $dir or die "chdir $dir: $!";
    my $done = eval { $code->(); 1 };
    my $error = $@;
    chdir $original or die "chdir $original: $!";
    die $error unless $done;
}

my $valid_tarball = gzip_bytes(tar_bytes(emergency_members()));

subtest 'emergency_tarball_problem rejects bad payloads' => sub {
    in_fresh_dir(sub {
            is(login_console::emergency_tarball_problem(undef), 'empty payload', 'undef payload reports an empty payload');
            is(login_console::emergency_tarball_problem(''), 'empty payload', 'empty payload reports an empty payload');
            is(login_console::emergency_tarball_problem('PK' . ('x' x 64)), 'no gzip magic', 'data without gzip magic reports no gzip magic');
            like(login_console::emergency_tarball_problem("\x1f\x8b" . ('junk' x 16)),
                qr/^gzip error: /, 'gzip magic followed by garbage reports a gzip error');
            is(login_console::emergency_tarball_problem(gzip_bytes("short log line\n")),
                'tar archive is not terminated', 'short payload reports an unterminated tar archive');

            my $unterminated = tar_bytes(emergency_members());
            substr($unterminated, -1024) = 'X' x 1024;
            is(login_console::emergency_tarball_problem(gzip_bytes($unterminated)),
                'tar archive is not terminated', 'tar archive without the zero blocks reports an unterminated tar archive');

            # The payload ends in NUL bytes, so only the tar read can reject it
            my $unreadable = gzip_bytes((('not a tar archive' . "\n") x 64) . ("\0" x 1024));
            is(login_console::emergency_tarball_problem($unreadable), 'tar archive cannot be read', 'garbage instead of tar headers is unreadable');

            # Break the checksum field of a tar header that is not the first
            # header. The five expected files stay intact, so only the reader
            # warning can reject this payload.
            my $with_extra = tar_bytes(emergency_members(), 'emergency_mode_logs/extra.log');
            my $header = header_offset($with_extra, 'extra.log');
            ok(defined $header, 'the extra member header is found');
            substr($with_extra, $header + 148, 8) = '0000000 ' if defined $header;
            like(login_console::emergency_tarball_problem(gzip_bytes($with_extra)),
                qr/^tar reader warning: .*checksum error/, 'a bad non-first tar header checksum reports the tar reader warning');

            my $partial = gzip_bytes(tar_bytes('emergency_mode_logs/journal.log', 'emergency_mode_logs/other.log'));
            is(login_console::emergency_tarball_problem($partial),
                'missing files: failed_units.log, cmdline.log, fstab, storage.log',
                'archive without all expected files reports the missing files');

            is(login_console::emergency_tarball_problem($valid_tarball . 'junk after the gzip stream'),
                'trailing data after the gzip stream', 'junk after the gzip stream reports trailing data');
            is(login_console::emergency_tarball_problem($valid_tarball), undef, 'complete archive has no problem');

            # The gzip trailer is the last 8 bytes of the file: a 4-byte CRC32
            # then a 4-byte ISIZE. Flip one bit of the stored CRC32 and keep the
            # compressed data intact, so only the trailer check can reject this
            # payload. A non-strict gunzip accepts it.
            my $damaged_trailer = $valid_tarball;
            substr($damaged_trailer, -8, 1) = chr(ord(substr($damaged_trailer, -8, 1)) ^ 0x01);
            isnt($damaged_trailer, $valid_tarball, 'the damaged trailer differs from the valid archive');
            like(login_console::emergency_tarball_problem($damaged_trailer),
                qr/^gzip error: /, 'a damaged gzip trailer is rejected');
    });
    in_fresh_dir(sub {
            # A plain file named ulogs blocks the mkdir and the open of the
            # validation file, so the write failure must be reported
            open(my $plain, '>', 'ulogs') or die "create ulogs file: $!";
            print $plain "not a directory\n" or die "write ulogs file: $!";
            close $plain or die "close ulogs file: $!";
            like(login_console::emergency_tarball_problem($valid_tarball), qr/^cannot write /, 'unwritable ulogs directory reports cannot write');
    });
};

subtest 'recover_emergency_mode_tarball without a console log' => sub {
    in_fresh_dir(sub {
            @recorded = ();
            @sleep_args = ();
            is(login_console::recover_emergency_mode_tarball(0), 0, 'missing console log returns 0');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'no tarball is written');
            is(scalar @sleep_args, 0, 'the recovery loop is not entered');
    });
};

subtest 'recover_emergency_mode_tarball recovers a valid block' => sub {
    in_fresh_dir(sub {
            @recorded = ();
            write_console_log("boot messages\n" . marked_block($valid_tarball));
            is(login_console::recover_emergency_mode_tarball(0), 1, 'complete valid block returns 1');
            ok(-e 'ulogs/emergency_mode_logs.tar.gz', 'the tarball is written');
            is(slurp_bytes('ulogs/emergency_mode_logs.tar.gz'), $valid_tarball, 'the tarball is byte identical to the encoded gzip stream');
            is(login_console::emergency_tarball_problem(slurp_bytes('ulogs/emergency_mode_logs.tar.gz')), undef, 'the written tarball passes validation');
            is(scalar @recorded, 0, 'no failure is recorded');
    });
    in_fresh_dir(sub {
            @recorded = ();
            # The console log carries control characters between the base64 lines
            my $noisy_body = encode_base64($valid_tarball);
            $noisy_body =~ s/\n/\x00\x1b\r\n/g;
            write_console_log(raw_block($noisy_body));
            is(login_console::recover_emergency_mode_tarball(0), 1, 'a base64 body with control characters is recovered');
            is(slurp_bytes('ulogs/emergency_mode_logs.tar.gz'), $valid_tarball, 'the noisy body yields a byte identical tarball');
    });
};

subtest 'recover_emergency_mode_tarball rejects a corrupt block' => sub {
    in_fresh_dir(sub {
            @recorded = ();
            write_console_log(marked_block('this is not base64 data !!!'));
            is(login_console::recover_emergency_mode_tarball(0), 0, 'valid base64 of non-tar data returns 0');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'no tarball is written');
            is(scalar @recorded, 1, 'the invalid tarball is recorded once');
            my $last = $recorded[-1] // [];
            is($last->[0], 'Invalid emergency tarball', 'the recorded title names the invalid tarball');
            is($last->[3], 'fail', 'the failure is recorded with result fail');
    });
    in_fresh_dir(sub {
            @recorded = ();
            # Raw text between the markers: no base64 encoding, plus control bytes
            write_console_log(raw_block("### this is not base64 \x01\x02 >>> ???"));
            is(login_console::recover_emergency_mode_tarball(0), 0, 'raw non-base64 text in the block returns 0');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'no tarball is written for raw text');
            is(scalar @recorded, 1, 'the raw text block is recorded once');
            my $last = $recorded[-1] // [];
            is($last->[0], 'Invalid emergency tarball', 'the raw text block is recorded as an invalid tarball');
            is($last->[3], 'fail', 'the raw text block is recorded with result fail');
    });
};

subtest 'recover_emergency_mode_tarball uses the last complete block' => sub {
    in_fresh_dir(sub {
            @recorded = ();
            write_console_log(marked_block($valid_tarball) . marked_block('corrupt newer block'));
            is(login_console::recover_emergency_mode_tarball(0), 0, 'newer corrupt block wins over the older valid block');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'the older valid tarball is not written');
    });
    in_fresh_dir(sub {
            @recorded = ();
            write_console_log(marked_block('corrupt older block') . marked_block($valid_tarball));
            is(login_console::recover_emergency_mode_tarball(0), 1, 'newer valid block wins over the older corrupt block');
            is(slurp_bytes('ulogs/emergency_mode_logs.tar.gz'), $valid_tarball, 'the newer valid tarball is written');
    });
};

subtest 'recover_emergency_mode_tarball honours the offset' => sub {
    my $older = marked_block($valid_tarball);
    in_fresh_dir(sub {
            @recorded = ();
            write_console_log($older);
            is(login_console::recover_emergency_mode_tarball(length $older), 0, 'a complete block that ends at the offset is not handled again');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'the already handled block is not written');
    });
    in_fresh_dir(sub {
            @recorded = ();
            write_console_log($older . marked_block('corrupt block after the offset'));
            is(login_console::recover_emergency_mode_tarball(length $older), 0, 'only the block after the offset is considered');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'the valid block before the offset is not written');
    });
    in_fresh_dir(sub {
            @recorded = ();
            write_console_log($older . marked_block($valid_tarball));
            is(login_console::recover_emergency_mode_tarball(length $older), 1, 'the valid block after the offset is recovered');
            is(slurp_bytes('ulogs/emergency_mode_logs.tar.gz'), $valid_tarball, 'the recovered tarball is byte identical');
    });
    in_fresh_dir(sub {
            @recorded = ();
            my $log = marked_block($valid_tarball);
            write_console_log($log);
            is(login_console::recover_emergency_mode_tarball(length($log) + 100), 1, 'an offset past the end of the file resets to 0');
    });
};

subtest 'recover_emergency_mode_tarball waits for a missing END marker' => sub {
    in_fresh_dir(sub {
            @recorded = ();
            @sleep_args = ();
            write_console_log(marked_block($valid_tarball) . join('', $BEGIN_MARKER, "\n", encode_base64($valid_tarball)));
            my $start = time;
            is(login_console::recover_emergency_mode_tarball(0), 0, 'BEGIN without END returns 0');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'the older complete block is not recovered');
            is_deeply(\@sleep_args, [(10) x 18], 'the recovery loop waits 10 seconds between all 18 attempts');
            cmp_ok(time - $start, '<', 10, 'the recovery loop finishes fast');
    });
};

subtest 'recover_emergency_mode_tarball needs standalone marker lines' => sub {
    in_fresh_dir(sub {
            @recorded = ();
            @sleep_args = ();
            # The typed command echo holds the BEGIN marker in the middle of a line
            my $command_echo = "echo " . $BEGIN_MARKER . "\n";
            write_console_log($command_echo . encode_base64($valid_tarball) . $END_MARKER . "\n");
            is(login_console::recover_emergency_mode_tarball(0), 0, 'BEGIN marker in the middle of a line does not start a block');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'no tarball is written');
            is(scalar @recorded, 0, 'no invalid tarball is recorded');
            is_deeply(\@sleep_args, [(10) x 18], 'the recovery loop waits 10 seconds between all 18 attempts');
    });
    in_fresh_dir(sub {
            @recorded = ();
            @sleep_args = ();
            write_console_log(join('', $BEGIN_MARKER, "\n", encode_base64($valid_tarball), 'trailing text ' . $END_MARKER . "\n"));
            is(login_console::recover_emergency_mode_tarball(0), 0, 'END marker in the middle of a line does not close the block');
            ok(!-e 'ulogs/emergency_mode_logs.tar.gz', 'no tarball is written');
            is(scalar @recorded, 0, 'no invalid tarball is recorded');
            is_deeply(\@sleep_args, [(10) x 18], 'the recovery loop waits 10 seconds between all 18 attempts');
    });
};

done_testing;
