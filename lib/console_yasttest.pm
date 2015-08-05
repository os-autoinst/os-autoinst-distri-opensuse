# Base for YaST tests.  Switches to text console 2 and uploady y2logs

package console_yasttest;
use base "opensusebasetest";

use testapi;

sub post_fail_hook() {
    my $self = shift;

    send_key "ctrl-alt-f2";
    assert_screen("text-login", 10);
    type_string "root\n";
    sleep 2;
    type_password;
    type_string "\n";
    sleep 1;

    save_screenshot;

    my $fn = sprintf '/tmp/y2logs-%s.tar.bz2', ref $self;
    type_string "save_y2logs $fn\n";
    upload_logs $fn;
    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    $self->clear_and_verify_console;
}

# Executes the command line tests from a yast repository (in master or in the
# given optional branch) using prove
sub run_yast_cli_test {
    my ($self, $repo, $branch) = @_;
    my $action;

    assert_script_run "git clone https://github.com/yast/$repo.git";
    script_run "cd $repo";

    if ($branch) {
        assert_script_run "git checkout $branch";
    }
    # Run 'prove' only if there is a directory called t
    script_run("if [ -d t ]; then echo -n 'run'; else echo -n 'skip'; fi > /dev/$serialdev");
    $action = wait_serial(['run', 'skip'], 10);
    if ($action eq 'run') {
      assert_script_run 'prove';
    }

    script_run 'cd ..';
    script_run "rm -rf $repo";
}

1;
# vim: set sw=4 et:
