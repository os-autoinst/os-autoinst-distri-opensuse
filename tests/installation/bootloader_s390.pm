use base "installbasetest";

use testapi;

use strict;
use warnings;
use English;

###################################################################

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

sub get_to_yast() {
    my $self  = shift;
    my $s3270 = console('x3270');

    my $params = '';
    $params .= get_var('S390_NETWORK_PARAMS');
    $params .= " ssh=1 sshpassword=$testapi::password sshd=1 ";
    $params .= " VNC=1 VNCSize=1024x768 VNCPassword=$testapi::password ";

    # we have to hardcode the hostname here - the true hostname would
    # create a too long parameter ;(
    $params .= " install=ftp://openqa/" . get_var('REPO_0') . " ";

    my $parmfile_with_Newline_s = split_lines($params);

    my $r;

    ###################################################################
    # qboot
    my $ftp_server = get_var('OPENQA_HOSTNAME') or die;
    # TODO: find the proper repo for 'ISO'
    my $dir_with_suse_ins = get_var('REPO_0');
    $s3270->sequence_3270("String(\"qaboot $ftp_server $dir_with_suse_ins\")", "ENTER", "Wait(InputField)",);

    ##############################
    # edit parmfile
    {
        $r = $s3270->expect_3270(buffer_ready => qr/X E D I T/, timeout => 240);

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

    ###################################################################
    # linuxrc
    $r = $s3270->expect_3270(
        output_delim => qr/Loading Installation System/,
        timeout      => 300
    );
    my $display_type = "VNC";
    my $output_delim
      = $display_type eq "SSH" || $display_type eq "SSH-X" ? qr/\Q***  run 'yast' to start the installation  ***\E/
      : $display_type eq "X11" ? qr/\Q***  run 'yast' to start the installation  ***\E/
      : $display_type eq "VNC" ? qr/\Q*** Starting YaST2 ***\E/
      :                          die "unknown vars.json:DISPLAY->TYPE <$display_type>";

    $r = $s3270->expect_3270(
        output_delim => $output_delim,
        timeout      => 20
    );

}

sub run() {

    my $self = shift;

    select_console 'x3270';

    eval {
        ###################################################################
        # connect to zVM, login to the guest
        $self->get_to_yast();
    };

    my $exception = $@;

    die join("\n", '#' x 67, $exception, '#' x 67) if $exception;

    # TODO: "hardcoded" vnc (default) right now - other installation methods have to be added
    select_console("installation");

    $self->result('ok');
}

1;
