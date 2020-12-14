package Installation::Partitioner::LibstorageNG::v4_3::FormattingOptionsPage;
use strict;
use warnings;
use testapi;
use YuiRestClient;
use parent 'Installation::Partitioner::LibstorageNG::FormattingOptionsPage';

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->{app} = $args->{app};
    $self->init($args);
}

sub init {
    my $self = shift;
    $self->{cb_enable_snapshots} = $self->{app}->checkbox({id => '"Y2Partitioner::Widgets::Snapshots"'});
    return $self;
}

sub enable_snapshots {
    my ($self) = @_;
    $self->{cb_enable_snapshots}->check();
}

1;
