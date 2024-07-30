# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package y2_module_consoletest;
use parent 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use Utils::Backends 'is_hyperv';
use Exporter 'import';
use version_utils 'is_public_cloud';
our @EXPORT_OK = qw(yast2_console_exec);

sub yast2_console_exec {
    my %args = @_;
    die "Yast2 module has not been found among function arguments!\n" unless (defined($args{yast2_module} || defined($args{podman})));
    my $cmd_start;
    my $module_name;
    if (defined($args{yast2_module})) {
        $cmd_start = y2_module_basetest::with_yast_env_variables($args{extra_vars}) . ' yast2 ';
        $module_name = 'yast2-' . $args{yast2_module} . '-status';
        $cmd_start .= (defined($args{yast2_opts})) ?
          $args{yast2_opts} . ' ' . $args{yast2_module} :
          $args{yast2_module};
        $cmd_start .= " $args{args}" if (defined($args{args}));
        $cmd_start .= ';';
        # poo#40715: Hyper-V 2012 R2 serial console is unstable (a Hyper-V product bug)
        # and is in many cases loosing the 15th character, so e.g. instead of the expected
        # 'yast2-scc-status-0' we get 'yast2-scc-statu-0' (sic, see the missing 's').
        # Kepp only the first 10 characters of a magic string plus a dash ('-')
        # and up to a three digit exit code.
        $module_name = substr($module_name, 0, 10) if is_hyperv('2012r2');
    }
    if (defined($args{podman})) {
        $cmd_start = y2_module_basetest::with_yast_env_variables($args{extra_vars}) . $args{podman};
        $module_name = 'podman-status';
    }
    if (!defined($args{yast2_module})) {
        $cmd_start = y2_module_basetest::with_yast_env_variables($args{extra_vars}) . ' yast2 ';
        $cmd_start .= ';';
        $module_name = 'yast2-ui-status';
    }
    if (!script_run($cmd_start . " echo $module_name-\$? > /dev/$serialdev", 0)) {
        return $module_name;
    } else {
        die "$cmd_start failed to execute!\n";
    }
}

sub ncurses_filesystem_probing {
    my $exit_needle = pop();

    assert_screen([('fs-probing-failed', $exit_needle)], 300);
    return unless (match_has_tag('fs-probing-failed'));

    send_key 'alt-n';
    assert_screen($exit_needle, 60);
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

sub test_flags {
    return is_public_cloud() ? {no_rollback => 1, fatal => 0} : {fatal => 0};
}

1;
