=head1 y2_module_guitest.pm

This module provides subroutine to launch YaST2 module in GUI test.

=cut
package y2_module_guitest;
use base "y2_module_basetest";
use strict;
use warnings;
use utils;
use testapi;
use Exporter 'import';

our @EXPORT = qw(launch_yast2_module_x11 %setup_nis_nfs_x11);
our %setup_nis_nfs_x11 = (
    nis_domain => 'nis.openqa.suse.de',
    nfs_domain => 'nfs.openqa.suse.de',
    nfs_dir => '/home/nis_user',
    client_address => '10.0.2.3/24',
    server_address => '10.0.2.1/24',
    net_mask => '255.255.255.0',
    net_address => '10.0.2.0',
    message => q/"nfs is working"/,
    # nfs mount options -> rw,no_root_squash
    nfs_opts => 'rw,no_'
);

=head2 launch_yast2_module_x11

 launch_yast2_module_x11([$module] [, target_match => $target_match] [, match_timeout => $match_timeout]);

Launch a yast configuration module C<$module> or the yast control center if C<$module> is empty. 

Calls C<assert_screen> on C<$target_match>, defaults to C<yast2-$module-ui>.

Optional C<$match_timeout> can be specified as a timeout on the C<assert_screen> call on C<$target_match>. 
C<$maximize_window> option allows to maximize application window using shortcut.

=cut

sub launch_yast2_module_x11 {
    my ($module, %args) = @_;
    $module //= '';
    $args{target_match} //= $module ? "yast2-$module-ui" : 'yast2-ui';
    my @tags = ['root-auth-dialog', ref $args{target_match} eq 'ARRAY' ? @{$args{target_match}} : $args{target_match}];
    # Terminate yast processes which may still run
    if (get_var('YAST2_GUI_TERMINATE_PREVIOUS_INSTANCES')) {
        select_console('root-console');
        script_run('pkill -TERM -e yast2');
        select_console('x11');
    }
    my $yast_env_variables = y2_module_basetest::with_yast_env_variables($args{extra_vars});
    # the command started with 'sh -c' to be able to execute 'echo' in Desktop Runner on Gnome
    x11_start_program("sh -c 'xdg-su -c \"env $yast_env_variables /sbin/yast2 $module\"; echo \"yast2-$module-status-\$?\" > /dev/$serialdev'", target_match => @tags, match_timeout => $args{match_timeout});
    foreach ($args{target_match}) {
        return if match_has_tag($_);
    }
    die "unexpected last match" unless match_has_tag 'root-auth-dialog';
    die "need password definition" unless $password;
    diag 'assuming root-auth-dialog, typing password';
    type_password;
    send_key 'ret';
    assert_screen $args{target_match}, $args{match_timeout};
    # Uses hotkey for gnome, adjust if need for other desktop
    send_key 'alt-f10' if $args{maximize_window};
}

sub post_run_hook {
    assert_screen('generic-desktop');
}

1;
