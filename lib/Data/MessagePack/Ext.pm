package Data::MessagePack::Ext;
use strict;
use warnings;
use overload
    '==' => sub { $_[0]->{type} == $_[1]->{type} && $_[0]->{data} eq $_[1]->{data} },
    fallback => 1,
;

sub new
{
    my ($this, $type, $data) = @_;

    my $class = ref($this) || $this;
    my $self =
    {
        type => $type,
        data => $data,
    };

    return bless $self, $class;
}

1;
