#!/usr/bin/perl -w
#
package SSH;
use Expect;


sub new {
    my ($class, %args) = @_;

    my $self = {
        prompt       => '\r?\n[^:]+:~\s*(#|>)',
        linux_prompt => '\r?\n[^:]+:~\s*(#|>)',
        my_prompt    => 'MY_UNIQUE_PROMPT_(\d+)_#\s+',
        my_ps1       => 'MY_UNIQUE_PROMPT_$?_# ',
        e            => undef,
        verbose      => 0
    };
    foreach my $k (keys(%args)) {
        $self->{$k} = $args{$k};
    }
    bless($self, $class);
    return $self;
}

sub connect
{
    my ($self, $host, $username, $password) = @_;

    my @params;
    if (-f $password) {
        push(@params, "-i", $password);
    }
    push(@params, $username . "@" . $host);
    my $exp = Expect->spawn("ssh", @params);

    die("unable to spawn ssh") unless $exp;

    $exp->log_stdout($self->{verbose});

    $self->{e} = $exp;

    # Connect to host;
    $exp->expect(60,
        [qr/\(yes\/no\)\?/ => sub {
                my $exp = shift;
                $exp->send("yes\n");
                exp_continue;
            }
        ],
        [qr/(P|p)assword:\s*/ => sub {
                my $exp = shift;
                $exp->send($password . "\n");
                exp_continue;
            }
        ],
        eof =>
          sub {
            die "ERROR: login failed ssh quit!\nssh " . join(" ", @params);
          },
        [$self->{linux_prompt} => sub {
                my $exp = shift;
                print "Login successful" . $/;
            }
        ]
    );

    # Change to root
    if ($username ne "root") {
        $exp->send("sudo su\n");
        $self->expect_prompt(5);
    }

    # change prompt
    $exp->send("PS1='" . $self->{my_ps1} . "'\n");
    $self->{prompt} = $self->{my_prompt};
    die("unable to set PROMPT") unless $self->expect_prompt == 0;

    $self->run_cmd('export TERM=dump');
}

sub run_cmd
{
    my ($self, $cmd, $timeout) = @_;
    my $e = $self->{e};
    $timeout //= 60;
    $e->clear_accum();
    $e->send($cmd . "\n");
    $e->expect(10, $cmd);
    $e->expect(10, '-re', '\r?\n');
    return $self->expect_prompt($timeout);
}

sub run_assert
{
    my ($self, $cmd, $timeout) = @_;
    my ($ret, $out) = $self->run_cmd($cmd, $timeout);
    die("[TIMEOUT] on cmd '$cmd'") unless (defined($ret));
    die("[ERROR] on cmd '$cmd'")   unless ($ret == 0);
    wantarray ? ($ret, $out) : $ret;
}

sub expect_prompt
{
    my ($self, $timeout) = @_;
    my $e = $self->{e};
    my $retval;
    $timeout //= 60;
    if ($e->expect($timeout, '-re', $self->{prompt})) {
        if ($e->match() =~ $self->{prompt}) {
            $retval = $1;
        }
    }

    wantarray ? ($retval, $e->before()) : $retval;
}

package main;
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage 'pod2usage';
use JSON 'to_json';


sub append_log {
    my ($filename, $txt) = @_;

    open(my $fh, '>>', $filename)
      or die("FAILED OPEN FILE " . $filename);
    print $fh $txt;
    close($fh);
}

sub append_header {
    my ($filename, $text) = @_;
    my $txt = "#" x 79 . $/;
    $txt .= '# ' . $text . $/;
    $txt .= "#" x 79 . $/;
    append_log($filename, $txt);
}

sub exit2str {
    my $e = shift;
    if ($e == 0) {
        return 'SUCCESSFUL';
    }
    if ($e == 32) {
        return 'NOT_SUPPORTED';
    }
    return 'FAILED';
}

sub add_result {
    my ($ctx, $name, $ret, $tout) = @_;
    $tout =~ s/\x1b\[[0-9;]*[a-zA-Z]//g;

    my $status = (exit2str($ret) eq 'FAILED') ? 'FAILED' : 'PASS';

    $ctx->{results} //= [];

    my $result = {
        status   => $status,
        test_fqn => $name,
        test     => {
            'log'      => $tout,
            'duration' => 0,
            'result'   => $status
          }
    };
    push(@{$ctx->{results}}, $result);
}

sub run_ltp {
    my ($ctx, $ltp_file, $exclude) = @_;
    my $exit = 0;

    my ($ret, $output) = $ctx->{backend}->run_assert('cat /opt/ltp/runtest/' . $ltp_file);
    my $ltp_bin = '/opt/ltp/testcases/bin';

    for my $fname (($ctx->{'output_file'}, $ctx->{'log_file'})) {
        append_header($fname, $ltp_file);
    }

    $ctx->{backend}->run_assert("cd $ltp_bin");

    for my $l (split(/\r?\n/, $output)) {
        next if ($l =~ /^#|^\s*$/);

        if ($l =~ /^\s*([\w-]+)\s+(.+)$/) {
            my $name = $1;
            my $cmd  = $2;
            next if ($name =~ m/$exclude/);

            my ($ret, $tout) = $ctx->{backend}->run_cmd("./" . $cmd, 60 * 30);
            die("TIMEOUT on $cmd") unless defined($ret);
            add_result($ctx, $name, $ret, $tout);
            append_log($ctx->{log_file}, sprintf("TEST: %20s %s$/", $name, exit2str($ret)));
            append_header($ctx->{output_file}, $name);
            append_log($ctx->{output_file}, $tout);
            $exit = 1 if (exit2str($ret) eq 'FAILED');
        }
    }
    $ctx->{backend}->run_assert("cd - ");

    return $exit;
}


MAIN:
{
    my $ctx = {
        'ltp-exclude' => '',
        'log_file'    => "ltp_log.txt",
        'output_file' => "ltp_out.txt",
        'verbose'     => 0
    };
    my $help       = 0;
    my $man        = 0;
    my $no_install = 0;

    GetOptions(
        'host=s'        => \$ctx->{host},
        'username=s'    => \$ctx->{username},
        'password=s'    => \$ctx->{password},
        'ltp-test=s'    => \$ctx->{ltp_test},
        'ltp-exclude=s' => \$ctx->{ltp_exclude},
        'repo=s'        => \$ctx->{repo},
        'log-file=s'    => \$ctx->{log_file},
        'output-file=s' => \$ctx->{'output_file'},
        'json-file=s'   => \$ctx->{json_file},
        'verbose'       => \$ctx->{'verbose'},
        'help'          => \$help,
        'man'           => \$man
    );

    pod2usage(1) if $help;
    pod2usage(-verbose => 2) if $man;

    for my $mandatory (qw(username password host ltp_test repo)) {
        pod2usage("Missing mandatory paramter --$mandatory") unless $ctx->{$mandatory};
    }

    my @files = ($ctx->{output_file}, $ctx->{log_file});
    push(@files, $ctx->{json_file}) if $ctx->{json_file};
    for my $fname (@files) {
        die("[ERROR] log file already exists - $fname") if (-f $fname);
    }

    my $backend = SSH->new(verbose => $ctx->{verbose});
    $backend->connect($ctx->{host}, $ctx->{username}, $ctx->{password});
    $ctx->{'backend'} = $backend;

    $backend->run_assert("cd");
    $backend->run_assert("pwd");

    my ($ret, $out) = $backend->run_cmd('zypper ar "' . $ctx->{repo} . '"');
    if ($ret != 0) {
        if ($out =~ m/Repository named '([^']+)' already exists/) {
            print('[WARN] Repository ' . $1 . ' already exists' . $/);
        } else {
            die('[ERROR] Failed on adding repo ' . $ctx->{repo});
        }
    }
    $backend->run_assert('zypper --gpg-auto-import-keys in -y ltp');

    $backend->run_assert('export PATH=/opt/ltp/testcases/bin:$PATH');
    $backend->run_assert('export LTPROOT=/opt/ltp');
    $backend->run_assert('export TMPBASE=/tmp');
    $backend->run_assert('export TMPDIR=/tmp');

    my $exitcode = run_ltp($ctx, $ctx->{ltp_test}, $ctx->{ltp_exclude});

    if ($ctx->{json_file}) {
        my $txt = to_json({results => $ctx->{results}});
        append_log($ctx->{json_file}, $txt);
    }

    exit($exitcode);
}

__END__

=head1 NAME

run_ltp.pl - Script to run LTP on a publiccloud instance connecting via SSH. LTP gets
installed from given repo.

=head1 SYNOPSIS

run_ltp.pl [options]

=head1 OPTIONS

=over 4

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the manual page and exit.

=item B<--host>

Specify the hostname to connect to (required).

=item B<--username>

Set the username used for ssh connection

=item B<--password>

Set the password or the ssh-key to use for authentication.

=item B<--repo>

The repo to install ltp from.

=item B<--log-file>

Specify the log output filename (default: ltp_log.txt).

=item B<--output-file>

Specify the LTP output filename (default: ltp_out.txt).

=item B<--json-file>

If given, the results will be written to this file in JSON format.

=item B<--ltp-test>

Specify the LTP runtest file to use.

=item B<--ltp-exclude>

A regex to exclude tests from runtest file.

=back

=head1 DESCRIPTION

Helper script to install and run LTP on a publiccloud instance. 
The connection is done via SSH. The output is written to logfiles.

=cut

