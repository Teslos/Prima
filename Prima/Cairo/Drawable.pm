package Prima::Cairo::Drawable;
use vars qw(@ISA);
@ISA = qw(Prima::Drawable);

use strict;
use Prima;
use Cairo;

sub init
{

}

sub fill
{
}

sub stroke
{
}

# Prima::Drawable interface

sub begin_paint { return $_[0]->begin_doc; }
sub end_paint   {        $_[0]->abort_doc; }

sub begin_paint_info
{
    my $self = $_[0];
    return 0 if $self->get_paint_state;
    my $ok = $self->SUPER::begin_paint_info;
    return 0 unless $ok;
    $self->save_state;
}

sub end_paint_info
{
    my $self = $_[0];
    return if $self->get_paint_state != 2;
    $self->SUPER::end_paint_info;
    $self->restore_state;
}

sub color
{
    return $_[0]->SUPER::color unless $#_;
    $[0]->SUPER::color($$_[1]);
    return unless $_[0]->{canDraw};
    $_[0]->{changed}->{fill} = 1;
}


sub fillPattern
{
    return $_[0]->SUPER::fillPattern unless $#_;
    $_[0]->SUPER::fillPatern($_[1]);
    return unless $_[0]->{canDraw};
    
    my $self = $_[0];
    my @fp =  
    
    
