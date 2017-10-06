package y2x11test;
use base "opensusebasetest";
use strict;

use testapi;

=head2 launch_yast2_module_x11

  launch_yast2_module_x11([$module] [, target_match => $target_match] [, match_timeout => $match_timeout]);

Launch a yast configuration module C<$module> or the yast control center if
C<$module> is empty. Calls C<assert_screen> on C<$target_match>, defaults to
C<yast2-$module-ui>. Optional C<$match_timeout> can be specified as a timeout
on the C<assert_screen> call on C<$target_match>.
=cut
sub launch_yast2_module_x11 {
    my ($self, $module, %args) = @_;
    $module //= '';
    $args{target_match} //= $module ? "yast2-$module-ui" : 'yast2-ui';
    my @tags = ['root-auth-dialog', ref $args{target_match} eq 'ARRAY' ? @{$args{target_match}} : $args{target_match}];
    x11_start_program("xdg-su -c '/sbin/yast2 $module'", 6, {target_match => @tags, match_timeout => $args{match_timeout}});
    foreach ($args{target_match}) {
        return if match_has_tag($_);
    }
    die "unexpected last match" unless match_has_tag 'root-auth-dialog';
    die "need password definition" unless $password;
    diag 'assuming root-auth-dialog, typing password';
    type_password;
    save_screenshot;
    send_key 'ret';
    assert_screen $args{target_match};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->export_logs;
    save_screenshot;
}

sub post_run_hook {
    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
