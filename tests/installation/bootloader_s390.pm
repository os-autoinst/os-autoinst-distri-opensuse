# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";

use testapi;

use strict;
use warnings;
use English;

# try to find the 2 longest lines that are below beyond the limit
# collapsing the lines - we have a limit of 10 lines
sub try_merge_lines {
    my ($lines, $columns) = @_;
    # the order of the parameters doesn't matter, so take the longest first
    @$lines = sort { length($b) <=> length($a) } @$lines;
    for my $start_index (0 .. scalar(@$lines) - 1) {
        my $start = $lines->[$start_index];
        for my $end_index ($start_index + 1 .. scalar(@$lines) - 1) {
            my $end = $lines->[$end_index];
            if (length($start) + length($end) + 1 < $columns) {    # hit!
                my $last = pop @$lines;
                $lines->[$start_index] .= " $end";
                $lines->[$end_index] = $last unless ($last eq $end);
                return 1;
            }
        }
    }
    return 0;
}

sub split_lines {
    my ($params) = @_;

    # s3270 has a funny behaviour in xedit, so be careful
    my $columns = 72;

    my @lines = split(/ /, $params);
    while (try_merge_lines(\@lines, $columns)) {
        # just keep trying!
    }

    $params = '';
    for my $line (@lines) {
        $params .= "String(\"$line \")\nNewline\n";
    }

    return $params;
}

use backend::console_proxy;

sub prepare_parmfile() {
    my $params = '';
    $params .= get_var('S390_NETWORK_PARAMS');

    if (check_var("VIDEOMODE", "text") || check_var("VIDEOMODE", "ssh-x")) {
        $params .= " ssh=1 ";    # trigger ssh-text installation
    }
    else {
        $params .= " sshd=1 VNC=1 VNCSize=1024x768 VNCPassword=$testapi::password ";
    }

    $params .= "sshpassword=$testapi::password ";

    # we have to hardcode the hostname here - the true hostname would
    # create a too long parameter ;(
    $params .= " install=ftp://openqa/" . get_var('REPO_0') . " ";

    return split_lines($params);
}

sub get_to_yast() {
    my $self  = shift;
    my $s3270 = console('x3270');

    my $r;

    # qaboot
    my $dir_with_suse_ins = get_var('REPO_0');

    # ensure that we are in cms mode before executing qaboot
    $s3270->sequence_3270("String(\"#cp i cms\")", "ENTER", "ENTER", "ENTER", "ENTER",);
    $r = $s3270->expect_3270(
        output_delim => qr/CMS/,
        timeout      => 20
    ) || die "Could not initialize CMS";

    $s3270->sequence_3270("String(\"qaboot openqa.suse.de $dir_with_suse_ins\")", "ENTER", "Wait(InputField)",);

    # edit parmfile
    my $parmfile_with_Newline_s = prepare_parmfile;
    {
        $r = $s3270->expect_3270(buffer_ready => qr/X E D I T/, timeout => 240) || die "Download of Kernel or Initrd took too long";

        $s3270->sequence_3270(qw{ String(INPUT) ENTER });

        $r = $s3270->expect_3270(buffer_ready => qr/Input-mode/);

        my $sequence = <<"EO_frickin_boot_parms";
${parmfile_with_Newline_s}
ENTER
ENTER
EO_frickin_boot_parms

        # can't use qw{} because of space in commands...
        $s3270->sequence_3270(split /\n/, $sequence);

        $r = $s3270->expect_3270(buffer_ready => qr/X E D I T/);

        ## Remove the "manual=1" and the empty line at the end
        ## of the parmfile.

        ## HACK HACK HACK HACK this code just 'knows' there is
        ## an empty line and a single "manual=1" at the bottom
        ## of the ftpboot parmfile.  This may fail in obscure
        ## ways when that changes.
        $s3270->sequence_3270(qw{String(BOTTOM) ENTER String(DELETE) ENTER});
        $s3270->sequence_3270(qw{String(BOTTOM) ENTER String(DELETE) ENTER});

        $r = $s3270->expect_3270(buffer_ready => qr/X E D I T/);

        # save the parmfile.  ftpboot then starts the installation.
        $s3270->sequence_3270(qw{ String(FILE) ENTER });

    }

    # linuxrc
    $r = $s3270->expect_3270(
        output_delim => qr/Loading Installation System/,
        timeout      => 300
    ) || die "Installation system was not found";
    my $display_type;

    # set up display_mode for textinstall
    if (check_var("VIDEOMODE", "text")) {
        $display_type = "SSH";
    }
    elsif (check_var('VIDEOMODE', 'ssh-x')) {
        $display_type = "SSH-X";
    }
    # default install is VNC
    else {
        $display_type = "VNC";
    }

    my $output_delim
      = $display_type eq "SSH" || $display_type eq "SSH-X" ? qr/\Q***  run 'yast.ssh' to start the installation  ***\E/
      : $display_type eq "VNC" ? qr/\Q*** Starting YaST2 ***\E/
      :                          die "unknown vars.json:DISPLAY->TYPE <$display_type>";

    $r = $s3270->expect_3270(
        output_delim => $output_delim,
        timeout      => 30
    ) || die "Loading Installation system tooks too long";

}

sub format_dasd() {
    my $self = shift;

    # activate install-shell to do pre-install dasd-format
    select_console('install-shell');

    # bring dasd online
    assert_script_run("dasd_configure 0.0.0150 1");

    # make sure that there is a dasda device
    assert_script_run("lsdasd");
    assert_screen("ensure-dasd-exists");

    # format dasda (this can take up to 20 minutes depending on disk size)
    type_string("echo yes | dasdfmt -b 4096 -p /dev/dasda; echo dasdfmt-status-$?- > /dev/$serialdev\n");
    wait_serial("dasdfmt-status-0-", 1200) || die "dasdfmt could not finish";
}

sub run() {

    my $self = shift;

    select_console 'x3270';

    eval {
        # connect to zVM, login to the guest
        $self->get_to_yast();
    };

    my $exception = $@;

    die join("\n", '#' x 67, $exception, '#' x 67) if $exception;

    # activate console so we can call wait_serial later
    my $c = select_console('iucvconn');

    # we also want to test the formatting during the installation if the variable is set
    if (!get_var("FORMAT_DASD_YAST") && !get_var('S390_DISK')) {
        format_dasd;
    }

    select_console("installation");

    # We have textmode installation via ssh and the default vnc installation so far
    if (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x')) {
        type_string("yast.ssh\n");
    }
    wait_still_screen;

    $self->result('ok');
}

1;
