# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Bridge - ifreload with bond interfaces
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;


sub run {
    my ($self, $ctx) = @_;
    $self->get_from_data('wicked/ifreload-3.sh', '/tmp/ifreload-3.sh');
    my $script_cmd = sprintf(q(bond_slaves='%s' time sh /tmp/ifreload-3.sh), join(" ", $ctx->iface, $ctx->iface2));
    my $output     = script_output($script_cmd . ' && echo "==COLLECT_EXIT_CODE==$?=="', proceed_on_failure => 1);
    my $result     = $output =~ m/==COLLECT_EXIT_CODE==0==/ ? 'ok' : 'fail';
    $self->record_console_test_result('ifreload-3', $output, result => $result);
}

sub record_console_test_result {
    my ($self, $title, $content, %args) = @_;
    $args{result} //= 'failed';
    $title =~ s/:/_/g;
    my $details  = $self->record_testresult($args{result});
    my $filename = $self->next_resultname('txt', $title);
    $details->{_source} = 'parser';
    $details->{text}    = $filename;
    $details->{title}   = $title;
    $self->write_resultfile($filename, $content);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
