package builder::MyBuilder;
use strict;
use warnings;
use base 'Module::Build::XSUtil';

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(
        %args,
        c_source => ['xs-src'],
        cc_warnings => 1,
        generate_ppport_h => 'xs-src/ppport.h',
        generate_xshelper_h => 'xs-src/xshelper.h',
        include_dirs => ['include'],
        needs_compiler_c99 => 1,
        xs_files => { 'xs-src/MessagePack.xs' => 'lib/Data/MessagePack.xs' },
    );
    $self->c_source([]) if $self->pureperl_only; # for Module::Build 0.4224 or below
    $self;
}

sub ACTION_test {
    my $self = shift;

    {
        local $ENV{PERL_ONLY} = 1;
        $self->log_info("pp tests\n");
        $self->SUPER::ACTION_test(@_);
    }

    if (!$self->pureperl_only) {
        local $ENV{PERL_DATA_MESSAGEPACK} = "xs";
        $self->log_info("xs tests\n");
        $self->SUPER::ACTION_test(@_);
    }
}

1;
