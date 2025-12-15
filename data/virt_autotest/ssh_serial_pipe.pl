#!/usr/bin/perl

package ssh_serial_pipe;

use strict; 
use warnings;
use Carp;   
use Net::SSH2;
use Proc::Daemon;
use File::Path qw(make_path);
use Time::Seconds;
use Getopt::Long;
use Pod::Usage;

my $help;
my $man;
my %pipe;
my $title;
my $jumphost;
my $jumpport = 22;
my $jumpuser = 'root';
my $jumppwd;
my $srcaddr;
my $srcdev;
my $serialfile;
my $workinst;
my $logroot;

GetOptions(
    'help|?'            =>     \$help,
    'man'               =>     \$man,
    'pipe=s%'           =>     \%pipe,
    'title:s'           =>     \$title,
    'jumphost=s'        =>     \$jumphost,
    'jumpport:i'        =>     \$jumpport,
    'jumpuser:s'        =>     \$jumpuser,
    'jumppwd=s'         =>     \$jumppwd,
    'srcaddr=s'         =>     \$srcaddr,
    'srcdev:s'          =>     \$srcdev,
    'logroot:s'         =>     \$logroot,
    'serialfile:s'      =>     \$serialfile,
    'workinst:i'        =>     \$workinst
) or pod2usage(2);

pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;

$logroot = ($workinst ? '/var/lib/openqa/pool/' . $workinst . '/' : '/tmp/') if (!$logroot);
$title = (exists $pipe{title}) ? $pipe{title} : 'ssh_serial_pipe';
$srcdev = (exists $pipe{srcdev}) ? $pipe{srcdev} : 'sshserial';

use constant SSH_COMMAND_TIMEOUT_S => 3000;
use constant SSH_SERIAL_READ_BUFFER_SIZE => 4096;

sub config_serial_pipe_channel {
    my (%args) = @_;
    $args{jumphost} //= '';
    $args{jumpport} //= 22;
    $args{jumpuser} //= 'root';
    $args{jumppwd} //= '';
    $args{srcaddr} //= '';
    $args{srcdev} //= $srcdev;
    $args{logroot} //= $logroot;
    die('Can not configure serial pipe channel without jump host and source address') if (!$args{jumphost} or !$args{jumppwd} or !$args{srcaddr});

    my $log_folder = $args{logroot} . __PACKAGE__ . '/';
    my $log_file = $log_folder . 'ssh_serial_pipe_' . $args{srcaddr} . '_' . $$ . '.log';
    open(my $log_handle, '>>', $log_file);
    my $sshcon = Net::SSH2->new(timeout => (SSH_COMMAND_TIMEOUT_S // 5 * ONE_MINUTE) * 1000);
    my $counter = 5;
    my $con_pretty = $args{jumpuser} . "\@" . $args{jumphost} . ' -p ' . $args{jumpport};
    while ($counter > 0) {
        if ($sshcon->connect($args{jumphost}, $args{jumpport})) {
            $sshcon->auth(username => $args{jumpuser}, password => $args{jumppwd});
            if ($sshcon->auth_ok) {
                print $log_handle localtime() . " SSH connection to $con_pretty established\n";
                last;
            }
        }
        else {
            print $log_handle localtime() . " Could not connect to $con_pretty, Retrying after some seconds...\n";
            sleep(10);
            next;
        }
        $counter--;
    }
    if ($counter == 0) {
        print $log_handle localtime() . " Failed to connect to $con_pretty\n";
        die("Failed to connect to $con_pretty");
    }
    $log_handle->flush;

    my $sshchan = $sshcon->channel() or $sshcon->die_with_error;
    $sshchan->blocking(0);
    $sshchan->pty(1);
    $sshchan->ext_data('merge');
    $sshcon->blocking(1);
    if (!$sshchan->exec("ssh $args{srcaddr} \"rm -f /dev/$args{srcdev}; mkfifo /dev/$args{srcdev}; chmod 666 /dev/$args{srcdev}; while true; do cat /dev/$args{srcdev}; done\"")) {
        print $log_handle localtime() . " Failed setup ssh serial pipe for $args{srcaddr} with PID: $$\n";
        die("Failed setup ssh serial pipe for $args{srcaddr} with PID: $$\n");
    }
    else {
        print $log_handle localtime() . " Successfully setup ssh serial pipe for $args{srcaddr} with PID: $$\n";
    }
    $sshcon->blocking(0);
    $log_handle->flush;
    close($log_handle);
    return $sshchan;
}

sub read_serial_pipe_channel {
    my (%args) = @_;
    $args{sshchan} //= '';
    $args{serialfile} //= '';
    $args{logroot} //= $logroot;
    die('Can read from serial pipe channel without ssh channel object') if (!$args{sshchan});

    my $buffer;
    my $log_folder = $args{logroot} . __PACKAGE__ . '/';
    my @serial_file = ($log_folder . 'serial0', $log_folder . 'serial0.txt', $args{logroot} . 'serial0', $args{logroot} . 'serial0.txt');
    push @serial_file, ($args{logroot} . $args{serialfile}, $args{logroot} . $args{serialfile}) if ($args{serialfile});
    while (1) {
        while (defined(my $bytes_read = $args{sshchan}->read($buffer, 4096))) {
            return 1 unless $bytes_read > 0;
            foreach my $file (@serial_file) {
                open(my $file_handle, '>>', $file);
                print $file_handle $buffer;
                close($file_handle);
            }
        }
    }
}

sub run_pipe_as_daemon {
    my %args = @_;
    $args{title} //= $title;
    $args{jumphost} //= '';
    $args{jumpport} //= 22;
    $args{jumpuser} //= 'root';
    $args{jumppwd} //= '';
    $args{srcaddr} //= '';
    $args{srcdev} //= $srcdev;
    $args{logroot} //= $logroot;
    die('Can not configure serial pipe channel without jump host/password and source address') if (!$args{jumphost} or !$args{jumppwd} or !$args{srcaddr});

    eval {
        my $log_folder = $args{logroot} . __PACKAGE__ . '/';
        make_path($log_folder, {mode => 0777});
        my $pipe_as_daemon = Proc::Daemon->new(
            work_dir => '/',
            child_STDOUT => $log_folder . __PACKAGE__ . '_output_' . $args{srcaddr},
            child_STDERR => $log_folder . __PACKAGE__ . '_error_' . $args{srcaddr},
            pid_file => $log_folder . __PACKAGE__ . '_pid_' . $args{srcaddr}
        );
        my $pipe_as_daemon_pid = $pipe_as_daemon->Init;

        unless ($pipe_as_daemon_pid) {
            $0 = $args{title} . '_pid' . $$;
            my $log_file = $log_folder . 'ssh_serial_pipe_' . $args{srcaddr} . '_' . $$ . '.log';
            open(my $log_handle, '>>', $log_file);
            print $log_handle '********** ' . localtime() . ' SSH SERIAL PIPE LOG PID: ' . $$ . ' **********';
            print $log_handle localtime() . " Pipe process will run as daemon for source: $args{srcaddr} with PID: $$\n";
            print $log_handle localtime() . " Pipe process $args{title} with PID: $$ is now running in the background\n";
            $log_handle->flush;
            close($log_handle);

            my $sshchan = config_serial_pipe_channel(jumphost => $args{jumphost}, jumpport => $args{jumpport}, jumppwd => $args{jumppwd}, srcaddr => $args{srcaddr}, srcdev => $args{srcdev});
            read_serial_pipe_channel(sshchan => $sshchan, serialfile => $args{serialfile});
            exit 0;
        }
    };
    exit 1 if ($@);
}

run_pipe_as_daemon(title => $title, jumphost => $jumphost, jumpport => $jumpport, jumppwd => $jumppwd, srcaddr => $srcaddr);

exit 0;

__END__

=head1 NAME

ssh_serial_pipe.pl - Script to establish and capture serial device output from remote end via relay and ssh

=head1 SYNOPSIS

ssh_serial_pipe.pl --pipe key=value [--pipe key=value] [--title program title] --jumphost ip or FQDN 
                   [--jumpport 22 or others] [--jumpuser root or others] [--jumppwd password to jumphost]
                   --srcaddr remote end ip or FQDN [--srcdev sshserial or others] [--logroot logs/folders root]
                   [--serialfile additional file to store serial output other than serial0(.txt)]
                   [--workinst openQA worker number runs the parent program]
 

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the full man page documentation and exit.

=item B<--help>

Print a brief help message and exit.

=item B<--pipe>

key=value hash variable that stores pipe information.

=item B<--title>

Process name to be displayed when run in background. Default to ssh_serial_pipe.

=item B<--jumphost>

Address of relay host. Takes the form of IP or FQDN.

=item B<--jumpport>

SSH port to be connected. Default to 22.

=item B<--jumpuser>

Username to login jumphost. Default to root.

=item B<--jumppwd>

Password to login jumphost.

=item B<--srcaddr>

Address of remote end from which serial content is received. Takes the form of IP or FQDN.

=item B<--srcdev>

Serial device to used on remote end. Default to sshserial.

=item B<--logroot>

Root of all log files.

=item B<--serialfile>

Specific serial file to be used for storing captured serial content.

=item B<--workinst>

The number of openQA worker instance that runs calling program.

=back

=head1 DESCRIPTION

The script establish ssh connection to serial device on remote end through a relay
host, so serial content from remote end can be captured continuously.

=head1 EXAMPLES

=over 4

=item To display a brief help message:

  ./ssh_serial_pipe.pl --help

=item To view the full man page:

  ./ssh_serial_pipe.pl --man

=item To run the script in real world:

  ./ssh_serial_pipe.pl --pipe title=ssh_serial_pipe_for_10.0.2.16 --pipe srcaddr=10.0.2.16 \
      --pipe srcdev=sshserial --workinst 11 --jumphost 127.0.0.1 --jumpport 18888 \
      --jumppwd nots3cr3t --srcaddr 10.0.2.16

=back

=head1 AUTHOR

Wayne Chen <wchen@suse.com>

=cut
