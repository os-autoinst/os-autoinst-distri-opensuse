# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package y2_module_consoletest;
use parent 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use Utils::Backends 'is_hyperv';

sub yast2_console_exec {
    my %args = @_;
    die "Yast2 module has not been found among function arguments!\n" unless (defined($args{yast2_module}));
    my $y2_start    = 'Y2DEBUG=1 ZYPP_MEDIA_CURL_DEBUG=1 yast2 ';
    my $module_name = 'yast2-' . $args{yast2_module} . '-status';
    $y2_start .= (defined($args{yast2_opts})) ?
      $args{yast2_opts} . ' ' . $args{yast2_module} . ';' :
      $args{yast2_module} . ';';

    # poo#40715: Hyper-V 2012 R2 serial console is unstable (a Hyper-V product bug)
    # and is in many cases loosing the 15th character, so e.g. instead of the expected
    # 'yast2-scc-status-0' we get 'yast2-scc-statu-0' (sic, see the missing 's').
    # Kepp only the first 10 characters of a magic string plus a dash ('-')
    # and up to a three digit exit code.
    $module_name = substr($module_name, 0, 10) if is_hyperv('2012r2');
    if (!script_run($y2_start . " echo $module_name-\$? > /dev/$serialdev", 0)) {
        return $module_name;
    } else {
        die "Yast2 module failed to execute!\n";
    }
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

sub test_flags {
    return {fatal => 0};
}

1;
