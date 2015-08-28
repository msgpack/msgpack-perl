package Data::MessagePack::ExtensionType;
use strict;
use warnings;
use Carp ();

sub new {
    my ($class, %args) = @_;
    return bless {
        size  => $args{size},
        type  => $args{type},
        data  => $args{data},
    }, $class;
}

sub create {
    my ($class, $byte, %args) = @_;

    if ($byte == 0xc7) {
        Data::MessagePack::ExtensionType::Ext8->new(%args);
    } elsif ($byte == 0xc8) {
        Data::MessagePack::ExtensionType::Ext16->new(%args);
    } elsif ($byte == 0xc9) {
        Data::MessagePack::ExtensionType::Ext32->new(%args);
    } elsif ($byte == 0xd4) {
        Data::MessagePack::ExtensionType::FixExt1->new(%args);
    } elsif ($byte == 0xd5) {
        Data::MessagePack::ExtensionType::FixExt2->new(%args);
    } elsif ($byte == 0xd6) {
        Data::MessagePack::ExtensionType::FixExt4->new(%args);
    } elsif ($byte == 0xd7) {
        Data::MessagePack::ExtensionType::FixExt8->new(%args);
    } elsif ($byte == 0xd8) {
        Data::MessagePack::ExtensionType::FixExt16->new(%args);
    } else {
        Carp::croak(sprintf "Invalid extension type ID: 0x%x", $byte);
    }
}

sub size  { $_[0]->{size}  }
sub type  { $_[0]->{type}  }
sub data  { $_[0]->{data}  }

sub pack {
    die "'pack' method must be override in subclass";
}

package
    Data::MessagePack::ExtensionType::Ext8;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;

    my $fmt = sprintf "CCCA%d", $self->size;
    return CORE::pack($fmt, 0xc7, $self->size, $self->type, $self->data);
}

package
    Data::MessagePack::ExtensionType::Ext16;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;

    my $fmt = sprintf "CnCA%d", $self->size;
    return CORE::pack($fmt, 0xc8, $self->size, $self->type, $self->data);
}

package
    Data::MessagePack::ExtensionType::Ext32;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;

    my $fmt = sprintf "CNCA%d", $self->size;
    return CORE::pack($fmt, 0xc9, $self->size, $self->type, $self->data);
}

package
    Data::MessagePack::ExtensionType::FixExt1;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;
    return CORE::pack("CCA", 0xd4, $self->type, $self->data);
}

package
    Data::MessagePack::ExtensionType::FixExt2;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;
    return CORE::pack("CCA2", 0xd5, $self->type, $self->data);
}

package
    Data::MessagePack::ExtensionType::FixExt4;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;
    return CORE::pack("CCA4", 0xd6, $self->type, $self->data);
}

package
    Data::MessagePack::ExtensionType::FixExt8;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;
    return CORE::pack("CCA8", 0xd7, $self->type, $self->data);
}

package
    Data::MessagePack::ExtensionType::FixExt16;
use parent qw(Data::MessagePack::ExtensionType);

sub pack {
    my $self = shift;
    return CORE::pack("CCA16", 0xd8, $self->type, $self->data);
}

1;
