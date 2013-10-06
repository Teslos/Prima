package Prima::Cairo::Drawable;
use vars qw(@ISA);
@ISA = qw(Prima::Drawable);

use strict;
use Prima;
use Prima::PS::Fonts;
use Cairo;
use Encode;

use constant {
	'PDF' => 1,
	'PS'  => 2,
	'SVG' => 3
};

use constant M_PI => 3.14159265359;

{
	my %RNT = (
	%{Prima::Drawable->notification_types()},
	Spool => nt::Action,
	);
	
	sub notification_types{ return \%RNT; }
}

sub profile_default
{
	my $def = $_[0]->SUPER::profile_default;
	my %prf = (
		copies  => 1,
		font    => {
			%{$def->{font}},
			name => $Prima::PS::Fonts::defaultFontName,
		},
		grayscale  => 0,
		pageDevice => undef,
		pageSize   => [ 598, 845 ],
		pageMargins => [12, 12, 12, 12],
		resolution  => [ 300, 300 ],
		reversed    => 0,
		rotate      => 0,
		scale       => [1, 1],
		textOutBaseline => 1,
		useDeviceFonts  => 1,
		useDeviceFontsOnly => 0,
		lineJoin    => 'round',
		lineEnd     => 'round'
	
	);
	@$def{keys %prf} = values %prf;
	return $def;
}

sub init
{
	my $self = shift;
	my $width = 200; my $height = 200;
	$self->{antialias_mode} = 1;
	$self->{format} = 'argb32';
	$self->{surface} = Cairo::ImageSurface->create( 'argb32', $width, $height );
	$self->{cairo} = Cairo::Context->create( $self->{surface} );
	$self->{clipRect} = [0,0,0,0];
	$self->{resolution} = [72,72];
	$self->{pageMargins} = [0,0,0,0];
	$self->{pageSize}    = [0,0];
	$self->{scale} = [1,1];
	$self->{rotate}     = 1;
	$self->{font}       = {};
	$self->{useDeviceFonts} = 1;
	$self->{grayscale}  = 0;
	# initialize Prima::Drawable
	my %profile = $self->SUPER::init(@_);
	#$self->$_( $profile{$_} ) for qw( grayscale copies pageDevice useDeviceFonts 
	#	rotate reversed useDeviceFontsOnly );
	$self-> $_( @{$profile{$_}}) for qw( pageSize pageMargins resolution scale);
	$self->{localeEncoding} = [];
	$self->set_font($profile{font});
	return %profile;
}

sub cmd_rgb
{
	my ( $r, $g, $b ) = (
		int((($_[1] & 0xff0000) >> 16) * 100 / 256 + 0.5) / 100,
		int((($_[1] & 0xff00) >> 8) * 100 / 256 + 0.5) / 100,
		int(($_[1] & 0xff) * 100 / 256 + 0.5) / 100);
	#print "Colors: $r, $g, $b \n";
	unless ( $_[0]->{grayscale} ) {
		return ( $r, $g, $b );
	} else {
		my $i = int( 100 * ( 0.31 * $r + 0.5 * $g + 0.18 * $b) + 0.5 ) / 100;
		return $i;
	}	
}

sub point2pixel
{
	my $self = shift;
	my $i;
	my @res;
	for( $i = 0; $i < scalar @_; $i+=2 ) {
		my ( $x, $y ) = @_[$i, $i+1];	
		push( @res, $x * $self->{resolution}->[0] / 72.27 );
		push( @res, $y * $self->{resolution}->[1] / 72.27 );
	}
	return @res;
}

sub pixel2point
{
	my $self = shift;
	my $i;
	my @res;
	for( $i = 0; $i < scalar @_; $i+=2 ) {
		my ( $x, $y ) = @_[$i, $i+1];
		push( @res, int( $x * 7227 / $self->{resolution}->[0] + 0.5) / 100 );
		push( @res, int( $y * 7227 / $self->{resolution}->[1] + 0.5) / 100 ) if defined $y;
	}
	return @res;
}

sub change_transform
{
	return if $_[0]->{delay};
	my $context = $_[0]->{cairo};
	
	my @tp = $_[0]->translate;
	my @cr = $_[0]->clipRect;
	my @sc = $_[0]->scale;
	my $ro = $_[0]->rotate;
	
	$cr[2] -= $cr[0];
	$cr[3] -= $cr[1];
	my $doClip = grep { $_ != 0 } @cr;
	my $doTR   = grep { $_ != 0 } @tp;
	my $doSC   = grep { $_ != 0 } @sc;
	
	if ( !$doClip && !$doTR && !$doSC && !$ro ) {
		return;
	}
	
	@cr = $_[0]->pixel2point(@cr);
	@tp = $_[0]->pixel2point(@tp);
	my $mcr3 = -$cr[3];
	
	print "Translate: @tp\n";
	print "Scale: @sc\n";
	print "Rotate: $ro\n";
	
	$context->translate(@tp) if $doTR;
	$context->scale(@sc) if $doSC;
	$context->rotate($ro) if $ro != 0;
	$_[0]->{changed}->{$_} = 1 for qw(fill linePattern lineWidth lineJoin lineEnd font);
	
}

sub fill
{
}

sub stroke
{
}

# Prima::Drawable interface

#sub begin_paint { return $_[0]->begin_doc; }
#sub end_paint   {        $_[0]->abort_doc; }

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
	$_[0]->SUPER::color($_[1]);
	#print "Color: $_[1]\n";
	my( $r, $g, $b) = $_[0]->cmd_rgb( $_[1] );
	#print "$r, $g, $b \n";
	$_[0]->{cairo}->set_source_rgb($r, $g, $b);
	return unless $_[0]->{canDraw};
	$_[0]->{changed}->{fill} = 1;
}


sub fillPattern
{
	return $_[0]->SUPER::fillPattern unless $#_;
	$_[0]->SUPER::fillPattern($_[1]);
	
	return unless $_[0]->{canDraw};
	my $self = $_[0];
	my $context = $self->{cairo};
	my @fp = @{$self->SUPER::fillPattern};
	my $solidBack = ! grep { $_ != 0 } @fp;
	my $solidFore = ! grep { $_ != 0xff } @fp;
	my $fpid;
	my @scaleto = $self->pixel2point(8,8);
	#print "solidBack: $solidBack solidFore: $solidFore \n";
	if (!$solidBack && !$solidFore) {
		$fpid = join('', map{sprintf("%02x", $_)} @fp);
		unless ( exists $self->{fpHash}->{$fpid}) {
			print "$fpid\n";
			$self->{fpHash}->{$fpid} = 1;
		}
	}
	$self->{fpType} = $solidBack ? 'B' : ( $solidFore ? 'F' : $fpid );
	$self->{changed}->{fill} = 1;	
}

my @lineCaps = ( 'butt', 'square', 'round' );
sub lineEnd
{
	return $_[0]->SUPER::lineEnd unless $#_;
	$_[0]->SUPER::lineEnd($_[1]);
	$_[0]->{cairo}->set_line_cap($lineCaps[$_[1]]);
	return unless $_[0]->{canDraw};
	$_[0]->{changed}->{lineEnd} = 1;
}

my @lineJoins = ( 'round', 'bevel', 'miter' );
sub lineJoin
{
	return $_[0]->SUPER::lineJoin unless $#_;
	$_[0]->SUPER::lineJoin($_[1]);
	$_[0]->{cairo}->set_line_join($lineJoins[$_[1]]);
	return unless $_[0]->{canDraw};
	$_[0]->{changed}->{lineJoin} = 1;
}

sub fillWinding
{
	return $_[0]->SUPER::fillWinding unless $#_;
	$_[0]->SUPER::fillWinding($_[1]);
}

sub linePattern
{
	return $_[0]->SUPER::linePattern unless $#_;
	$_[0]->SUPER::linePattern($_[1]);
	my $offset = -20;
	my @dash = ();
	#print "Line Pattern: ";
	foreach (unpack("(a1)*", $_[1])) {
		push( @dash, ord $_ );
	}
	#print "@dash\n";
	
	$_[0]->{cairo}->set_dash( $offset, @dash );	
	return unless $_[0]->{canDraw};
	$_[0]->{changed}->{linePattern} = 1;
}

sub lineWidth
{
	return $_[0]->SUPER::lineWidth unless $#_;
	$_[0]->SUPER::lineWidth($_[1]);
	$_[0]->{cairo}->set_line_width( $_[1] );
	return unless $_[0]->{canDraw};
	$_[0]->{changed}->{lineWidth} = 1;
}

sub rop
{
}

sub rop2
{
}

sub translate
{
	return $_[0]->SUPER::translate unless $#_;
	my $self = shift;
	my $context = $self->{cairo}; 
	$self->SUPER::translate(@_);
	#$self->change_transform;
	$context->translate($self->SUPER::translate);
}

sub clipRect
{
	return @{$_[0]->{clipRect}} unless $#_;
	my $context = $_[0]->{cairo};
	$_[0]->{clipRect} = [@_[1..4]];
	my ( $x1, $y1, $x2, $y2 ) = $_[0]->pixel2point( @_[1..4] );
	$context->rectangle($x1,$y1, $x2-$x1,$y2-$y1);
	$context->clip();
	#$_[0]->change_transform;
}


sub region
{
	return undef;
}	
    
sub scale
{
	return @{$_[0]->{scale}} unless $#_;
	my $self = shift;
	my $context = $self->{cairo};
	$self->{scale} = [@_[0,1]];
	#$self->change_transform;
	$context->scale($self->{scale}->[0],$self->{scale}->[1]);
}

sub rotate
{
	return $_[0]->{rotate} unless $#_;
	my $self = $_[0];
	my $context = $self->{cairo};
	$self->{rotate} = $_[1];
	#$self->change_transform;
	$context->rotate($self->{rotate});
}

sub resolution
{
	return @{$_[0]->{resolution}} unless $#_;
	return if $_[0]->get_paint_state;
	my ($x, $y) = @_[1..2];
	return if $x <= 0 || $y <= 0;
	$_[0]->{resolution} = [$x,$y];
	$_[0]->calc_page;
}

sub copies
{
}

sub pageDevice
{
}

sub useDeviceFonts
{
}

sub useDevicFontsOnly
{
}

sub grayscale
{
	return $_[0]->{grayscale} unless $#_;
	$_[0]->{grayscale} = $_[1] unless $_[0]->get_paint_state;
}

sub set_locale
{
}

sub calc_page
{
	my $self = $_[0];
	my @s =  @{$self-> {pageSize}};
	my @m =  @{$self-> {pageMargins}};
	if ( $self-> {reversed}) {
		@s = @s[1,0];
		@m = @m[1,0,3,2];
	}
	$self-> {size} = [
		int(( $s[0] - $m[0] - $m[2]) * $self-> {resolution}-> [0] / 72.27 + 0.5),
		int(( $s[1] - $m[1] - $m[3]) * $self-> {resolution}-> [1] / 72.27 + 0.5),
	];
}

sub pageSize
{
	return @{$_[0]-> {pageSize}} unless $#_;
	my ( $self, $px, $py) = @_;
	return if $self-> get_paint_state;
	$px = 1 if $px < 1;
	$py = 1 if $py < 1;
	$self-> {pageSize} = [$px, $py];
	$self-> calc_page;
}

sub pageMargins
{
	return @{$_[0]-> {pageMargins}} unless $#_;
	my ( $self, $px, $py, $px2, $py2) = @_;
	return if $self-> get_paint_state;
	$px = 0 if $px < 0;
	$py = 0 if $py < 0;
	$px2 = 0 if $px2 < 0;
	$py2 = 0 if $py2 < 0;
	$self-> {pageMargins} = [$px, $py, $px2, $py2];
	$self-> calc_page;
}

sub size
{
	return @{$_[0]->{size}} unless $#_;
	$_[0]->raise_ro("size");
}

# primitives

sub arc
{
	my ( $self, $x, $y, $dx, $dy, $start, $end ) = @_;
	my $context = $self->{cairo};
	my $try = $dy / $dx;
	( $x, $y, $dx, $dy ) = $self->pixel2point( $x, $y, $dx, $dy );
	my $rx = $dx / 2;
	#print "$x, $y, $rx, $start, $end \n"; 
        $context->arc( $x, $y, $rx, $start, $end );
	$context->stroke();
}

sub ellipse 
{
	my ( $self, $x, $y, $dx, $dy ) = @_;	
	my $context = $self->{cairo};
	my $try = $dy / $dx;
	( $x, $y, $dx, $dy ) = $self->pixel2point( $x, $y, $dx, $dy );
	my $rx = $dx / 2;
	#$context->scale( $dx / 2, $dy / 2 );
	#print "$x, $y, $rx \n";
	$context->arc( $x, $y, $rx, 0.0, 2*M_PI );
	$context->stroke();
}

sub chord
{
	my ( $self, $x, $y, $dx, $dy, $start, $end ) = @_;
	my $try = $dy / $dx;
	my $context = $self->{cairo};
	( $x, $y, $dx, $dy ) = $self->pixel2point( $x, $y, $dx, $dy );
	my $rx = $dx / 2;
	$context->arc( $x, $y, $rx, $start, $end );
	$context->stroke(); 	
}

sub fill_chord
{
	my ( $self, $x, $y, $dx, $dy, $start, $end ) = @_;
	my $try = $dy / $dx;
	my $context = $self->{cairo};
	( $x, $y, $dx, $dy ) = $self->pixel2point( $x, $y, $dx, $dy );
	my $rx = $dx / 2;
	$end -= $start;
	my $F = $self->fillWinding ? 'winding' : 'even-odd';
	$context->set_fill_rule($F);
	$context->arc( $x, $y, $rx, $start, $end ); 
}

sub fill_ellipse
{
	my ( $self, $x, $y, $dx, $dy, $start, $end ) = @_;
	my $context = $self->{cairo};
	my $try = $dy / $dx;
	( $x, $y, $dx, $dy ) = $self->pixel2point( $x, $y, $dx, $dy );
	my $rx = $dx / 2;
	$context->fill_preserve();
	$context->arc( $x, $y, $rx, 0, 2*M_PI );
	$context->fill();
}

sub sector
{
	my ( $self, $x, $y, $dx, $dy, $start, $end ) = @_;
	my $context = $self->{cairo};
	my $try = $dy / $dx;
	( $x, $y, $dx, $dy ) = $self->pixel2point( $x, $y, $dx, $dy );
	my $rx = $dx / 2;
	$context->arc( $x, $y, $rx, $start, $end );
}

sub fill_sector
{
	my ( $self, $x, $y, $dx, $dy, $start, $end ) = @_;
	my $context = $self->{cairo};
	my $try = $dy / $dx;
	( $x, $y, $dx, $dy ) = $self->pixel2point( $x, $y, $dx, $dy );
	my $rx = $dx / 2;
	my $F = $self->fillWinding ? 'winding' : 'even-odd';
 	$context->fill_style($F);
	$context->arc( $x, $y, $rx, $start, $end );	
}

sub text_out
{
	my ( $self, $text, $x, $y ) = @_;
	return 0 unless $self->{canDraw} and length $text;
	my $context = $self->{cairo};
	( $x, $y ) = $self->pixel2point( $x, $y );

	my $name  = $self->{font}->{name};
	my $angle = $self->{font}->{direction};
	my $size  = $self->{font}->{size};
	my $style  = $self->{font}->{style};
	my @slants = ('normal', 'italic', 'oblique');
	my @weight = ('normal', 'bold');
	print "text_out method\n";
	#print "Style: $style\n";
	#print "Font name: $name, size: $size, direction: $angle, style: $style \n";
	if ( $style & (fs::Italic | fs::Bold) ) {
		$context->select_font_face($name, $slants[1], $weight[1]);
	} elsif ( $style & (fs::Normal | fs::Bold) ){
		$context->select_font_face($name, $slants[0], $weight[1]);
	} else {
		$context->select_font_face($name, $slants[0], $weight[0]);
	} 
	$context->set_font_size($size);
	if ( $angle != 0 ) {
		#print "Angle: $angle\n";
		$context->translate( $x, $y );
		$context->rotate( $angle * M_PI / 180.0 );
		$context->translate( -$x, -$y )
	}
	$context->move_to($x,$y);
	$context->show_text($text);
	$context->restore();
}

sub text_out_old
{
	my ( $self, $text, $x, $y ) = @_;
	return 0 unless $self->{canDraw} and length $text;
	$y += $self->{font}->{descent} if !$self->textOutBaseline;
	my $context = $self->{cairo};
 
	( $x, $y ) = $self->pixel2point( $x, $y );
	my $n = $self->{typeFontMap}->{$self->{font}->{name}};
	my $spec = exists( $self->{font}->{encoding}) ?
		exists( $Prima::Cairo::Encodings::fontspecific{ $self->{font}->{encoding}}) : 0;
	if ( $n == 1 ) {
		my $fn = $self->{font}->{docname};
		unless( $spec || 
			( !defined( $self->{locale}) && !defined($self->{fontLocaleData}->{$fn})) ||
			( defined( $self->{locale}) && defined($self->{fontLocaleData}->{$fn}) &&
				( $self->{fontLocaleData}->{$fn} eq $self->{locale}))) {
			$self->{fontLocaleData}->{$fn} = $self->{locale};
			#define encoding
			$self->{changed}->{font} = 1;
		}
		if ($self->{changed}->{font}) {
			# emit the size of font
			$self->{changed}->{font} = 0;
		}
	}
	$context->move_to( $x, $y );
	if ( $self->{font}->{direction} != 0 ) {
		my $r = $self->{font}->{direction};
		# define direction of font
	}
	my @rb;
	if ( $self->textOpaque || $self->{font}->{style} & (fs::Underlined | fs::StruckOut)) {
		my ( $ds, $bs ) = ( $self->{font}->{direction}, $self->textOutBaseline );
		$self->textOutBaseling(1) unless $bs;
		@rb = $self->pixel2point( @{$self->get_text_box( $text ) });
		$self->{font}->{direction} = $ds;
		$self->textOutBaseline($bs) unless $bs;
	}
	if ( $self->textQpaque ) {
		$self->cmd_rgb( $self->backColor );
	}
	$self->cmd_rgb( $self->color );
	my ($rm, $nd) = $self->get_rmap;
	my ($xp, $yp) = ( $x, $y );
	my $c = $self->{font}->{chardata};
	my $le = $self->{localeEncoding};
	my $adv = 0;

	my ( @t, @umap );
	my $unicode = Encode::is_utf8( $text );
	if ( defined($self->{font}->{encoding}) && $unicode ) {
		# known encoding ?
		eval { Encode::encode( $self->{font}->{encoding}, ''); };
		unless( $@ ) {
			# convert as much of unicode text as possible into the current encoding
			while( 1 ) {
				my $conv = Encode::encode(
					$self->{font}->{encoding}, $text,
					Encode::FB_QUIET
				);
				push @t, split('', $conv);
				push @umap, (undef) x length $conv;
				last unless length $text;
				push @t, substr( $text, 0, 1, '');
				push @umap, 1;
			}
		} else {
			@t = split '', $text;
			@umap = map { undef } @t;
		}

	} else {
		@t = split '', $text;
		@umap = map { undef } @t;
	}	
	my $i = -1;
	for my $j (@t) {
		$i++;
		my $advance;
		my $u = $umap[$i] || 0;
		if (
			!$umap[$i] &&              # not unicode
			$n == 1 &&                 # postscript font
			( $le->[ord $j] ne '.notdef' ) && ( $spec ||
			  exists ( $c->{$le->[ord $j]} ))
		   ){
			$j =~ s/([\\()])/\\$1/g;
			my $adv2 = int( $adv * 100 + 0.5) / 100;
			# emit 
			my $xr = $rm->[ord $j];
			$advance = $$xr[1] + $$xr[2] + $$xr[3];
		} else {
			my ($pg, $a, $b, $c ) = $self->place_glyph($j);
			if ( length $pg ) {
				my $adv2 = $adv + $a * 72.27 / $self->{resolution}->[0];
				$adv2 = int( $adv * 100 + 0.5) / 100;
				$advance = $a + $b + $c;
			} else {
				$advance = $$nd[1] + $$nd[2] + $$nd[3];
			}
		}
		$adv += $advance * 72.27 / $self->{resolution}->[0];
	}

	if ( $self->{font}->{style} & (fs::Underlined | fs::StruckOut)) {
		my $lw = $self->{font}->{size}/30; 
		#emit font underlined and struckout
		if ( $self->{font}->{style} & fs::Underlined ) {
			# emit 
			;
		}
		if ( $self->{font}->{style} & fs::StruckOut ) {
			;
		}
	}
	return 1;
}

sub bar
{
	my ( $self, $x1, $y1, $x2, $y2 ) = @_;
	my $context = $self->{cairo};	
	( $x1, $y1, $x2, $y2 ) = $self->pixel2point( $x1, $y1, $x2, $y2 );
	my $width = $x2 - $x1;
	my $height = $y2 - $y1;
	$context->rectangle( $x1, $y1, $width, $height ); 
	$context->fill();
}	

sub rectangle
{
	my ( $self, $x1, $y1, $x2, $y2 ) = @_;	
	my $context = $self->{cairo};
	( $x1, $y1, $x2, $y2 ) = $self->pixel2point( $x1, $y1, $x2, $y2 );
	my $width = $x2 - $x1;
	my $height = $y2 - $y1;
	$context->rectangle( $x1, $y1, $width, $height );
	$context->stroke(); 
}

sub clear
{
	my ( $self, $x1, $y1, $x2, $y2 ) = @_;
	my $context = $self->{cairo};
	if ( grep { ! defined } $x1, $y1, $x2, $y2 ) {
		($x1, $y1, $x2, $y2) = $self->clipRect;
		print "x1: $x1, y1: $y1, x2: $x2, y2: $y2\n";
		unless ( grep { $_ != 0 } $x1, $y1, $x2, $y2 ) {
			($x1, $y1, $x2, $y2) = (0, 0, @{$self->{size}});
		}
	}
	( $x1, $y1, $x2, $y2 ) = $self->pixel2point( $x1, $y1, $x2, $y2 );
	my ($r, $g, $b) = $self->cmd_rgb( $self->backColor );
	print "Color: $r, $g, $b \n";
	my $width  = $x2 - $x1;
	my $height = $y2 - $y1;
	$context->set_source_rgb( $r, $g, $b );
	$context->rectangle( $x1, $y1, $x2, $y2 );
	$self->{changed}->{fill} = 1;	
		
}

sub line
{
	my ( $self, $x1, $y1, $x2, $y2  ) = @_;
	my $context = $self->{cairo};
	$context->move_to( $x1, $y1 );
	$context->rel_line_to( $x2, $y2 );
	$context->stroke();
}

sub lines
{
	my ( $self, $array ) = @_;
	my $context = $self->{cairo};
	my $i;
	my $c = scalar @$array;
	my @a = $self->pixel2point( @$array );
	$c = int( $c / 4 ) * 4;
	my $z = ' ';
	for ( $i = 0; $i < $c; $i += 4 ) {
		$context->move_to(@a[$i,$i+1]);
		$context->rel_line_to(@a[$i+2,$i+3]);
	}
	$context->stroke();
}

sub polyline
{
	my ( $self, $array ) = @_;
	my $context = $self->{cairo};
	my $i;
	my $c = scalar @$array;	
	my @a = $self->pixel2point( @$array );
	$c = int( $c / 2 ) * 2;
	return if $c < 2;
	$context->move_to(@a[0,1]);
	for ( $i = 2; $i < $c; $i += 2 ) {
		$context->rel_line_to(@a[$i,$i+1]);
	}
	$context->stroke();	
}

sub fillpoly
{
	my ( $self, $array ) = @_;
	my $context = $self->{cairo};
	my $i;
	my $c = scalar @$array;
	$c = int( $c / 2 ) * 2;
	return if $c < 2;
	my @a = $self->pixel2point( @$array );
	$context->move_to(@a[0,1]);
	for ( $i = 2; $i < $c; $i += 2 ) {
		$context->rel_line_to(@a[$i,$i+1]);
	}
	my $F = $self->fillWinding ? "winding" : "even-odd"; 
	$context->fill_style($F);
}
#
#sub flood_fill { return 0; }
#
#sub pixel
#{
#	my ( $self, $x, $y, $pix ) = @_;
#	return cl::Invalid unless defined $pix;
#	my $c = $self->cmd_rgb( $pix );
#	( $x, $y ) = $self->pixel2point( $x, $y );
#	$self->{changed}->{fill} = 1;
#}
#
#
## methods
#
#sub put_image_indirect
#{
#	return 0 unless $_[0]->{canDraw};
#	my ( $self, $image, $x, $y, $xFrom, $yFrom, $xDestLen, $yDestLen, $xLen, $yLen) = @_;
#	
#	my $touch;
#	$touch = 1, $image = $image->image if $image->isa('Prima::DeviceBitmap');
#	
#	unless ($xFrom == 0 && $yFrom == 0 && $xLen == $image->width && $yLen == image->height) {
#		$image = $image->extract( $xFrom, $yFrom, $xLen, $yLen );
#		$touch = 1;
#	}
#	my $ib = $image->get_bpp;
#	if ( $ib != $self->get_bpp ) {
#		$image = $image->dup unless $touch;
#		if ( $self->{grayscale} || $image->type & im::GrayScale ) {
#			$image->type( im::Byte );
#		} else {
#			$image->type( im::RGB );
#		}
#	} elsif ( $self->{grayscale} || $image->type & im::GrayScale ) {
#		$image = $image->dup unless $touch;
#		$image->type( im::Byte );
#	}
#	
#	$ib = $image->get_bpp;
#	$image->type( im::RGB ) if $ib != 8 && $ib != 24;
#	
#	my @is = $image->size;	
#	($x, $y, $xDestLen, $yDestLen) = $self->pixel2point( $x, $y, $xDestLen, $yDestLen );
#	my @fullScale = (
#		$is[0] / $xLen * $xDestLen;
#		$is[1] / $yLen * $yDestLen;
#	);
#	
#	my $g = $image->data;
#	my $bt = ( $image->type & im::BPP ) * $is[0] / 8;
#	my $ls = int(( $is[0] * ( $image->type & im::BPP) + 31) / 32) * 4;
#	my ( $i, $j );
#	
#	return 1;
#}
#
## fonts
sub fonts
{
	my ( $self, $family, $encoding ) = @_;
	$family = undef if defined $family && !length $family;
	$encoding = undef if defined $encoding && !length $encoding;

	my $f1 = $self->{useDeviceFonts} ? Prima::PS::Fonts::enum_fonts( $family, $encoding ) : [];
	return $f1 if !$::application || $self->{useDeviceFontsOnly};

	my $f2 = $::application->fonts( $family, $encoding );
	if ( !defined($family) && !defined($encoding) ) {
		my %f = map { $_->{name} => $_ } @$f1;
		my @add;
		for( @$f2 ) {
			if ( $f{$_} ) {
				push @{$f{$_}->{encodings}}, @{$_->{encoding}};
			} else {
				push @add, $_;
			}
		}
		push @$f1, @add;
	} else {
		push @$f1, @$f2;
	}
	return $f1;
}

sub font_encodings
{
	my @r;
	if ( $_[0]->{useDeviceFonts} ) {
		@r = Prima::PS::Encodings::unique, keys %Prima::PS::Encodings::fontspecific;
	}
	if ( $::application && !$_[0]->{useDeviceFontsOnly} ) {
		my %h = map { $_ => 1 } @r;	
		for ( @{$::application->font_encodings} ) {
			next if $h{$_};
			push @r, $_;
		}
	}
	return \@r;
}

sub get_font
{
	my $z = {%{$_[0]->{font}}};
	delete $z->{charmap};
	delete $z->{docname};
	return $z;
}

sub set_font
{
	my ( $self, $font) = @_;
	$font = { %$font }; 
	my $n = exists($font-> {name}) ? $font-> {name} : $self-> {font}-> {name};
	my $gui_font;
	$n = $self-> {useDeviceFonts} ? $Prima::PS::Fonts::defaultFontName : 'Default'
		unless defined $n;

	$font-> {height} = int(( $font-> {size} * $self-> {resolution}-> [1]) / 72.27 + 0.5)
		if exists $font-> {size};

AGAIN:
	if ( $self-> {useDeviceFontsOnly} || !$::application ||
			( $self-> {useDeviceFonts} && 
			( 
			# enter, if there's a device font
				exists $Prima::PS::Fonts::enum_families{ $n} || 
				exists $Prima::PS::Fonts::files{ $n} ||
				(
					# or the font encoding is PS::Encodings-specific,
					# not present in the GUI space
					exists $font-> {encoding} &&
					(  
						exists $Prima::PS::Encodings::fontspecific{$font-> {encoding}} ||
						exists $Prima::PS::Encodings::files{$font-> {encoding}}
					) && (
						!grep { $_ eq $font-> {encoding} } @{$::application-> font_encodings}
					)
				)
			) && 
			# and, the encoding is supported
			( 
				!exists $font-> {encoding} || !length ($font-> {encoding}) || 
				(
					exists $Prima::PS::Encodings::fontspecific{$font-> {encoding}} ||
					exists $Prima::PS::Encodings::files{$font-> {encoding}}
				)
			) 
		)
	)
	{
		$self-> {font} = Prima::PS::Fonts::font_pick( $font, $self-> {font}, 
			resolution => $self-> {resolution}-> [1]); 
		$self-> {fontCharHeight} = $self-> {font}-> {charheight};
		$self-> {docFontMap}-> {$self-> {font}-> {docname}} = 1; 
		$self-> {typeFontMap}-> {$self-> {font}-> {name}} = 1; 
		$self-> {fontWidthDivisor} = $self-> {font}-> {maximalWidth};
		$self-> set_locale( $self-> {font}-> {encoding});
	} else {
		my $wscale = $font-> {width};
		my $wsize  = $font-> {size};
		my $wfsize = $self-> {font}-> {size};
		delete $font-> {width};
		delete $font-> {size};
		delete $self-> {font}-> {size};
		unless ( $gui_font) {
			$gui_font = Prima::Drawable-> font_match( $font, $self-> {font});
			if ( $gui_font-> {name} ne $n && $self-> {useDeviceFonts}) {
				# back up
				my $pitch = (exists ( $font-> {pitch} ) ? 
					$font-> {pitch} : $self-> {font}-> {pitch}) || fp::Variable;
				$n = $font-> {name} = ( $pitch == fp::Variable) ? 
					$Prima::PS::Fonts::variablePitchName :
					$Prima::PS::Fonts::fixedPitchName;
				$font-> {width} = $wscale if defined $wscale;
				$font-> {wsize} = $wsize  if defined $wsize;
				$self-> {font}-> {size} = $wfsize if defined $wfsize;
				goto AGAIN;
			}
		}
		$self-> {font} = $gui_font;
		$self-> {font}-> {size} = 
			int( $self-> {font}-> {height} * 72.27 / $self-> {resolution}-> [1] + 0.5);
		$self-> {typeFontMap}-> {$self-> {font}-> {name}} = 2; 
		$self-> {fontWidthDivisor} = $self-> {font}-> {width};
		$self-> {font}-> {width} = $wscale if $wscale;
		$self-> {fontCharHeight} = $self-> {font}-> {height};
	}
	$self-> {changed}-> {font} = 1;
	$self-> {plate}-> destroy, $self-> {plate} = undef if $self-> {plate};
}
#
#sub plate
#{
#}
#
#sub place_glyph
#{
#}
#
#sub get_rmap
#{
#}
#
#sub get_font_abc
#{
#	my( $self, $first, $last ) = @_;
#	my $lim = ( defined ($self->{font}->{encoding}) &&
#		exists( $Prima::PS::Encodings::fontspecific{$self->{font}->{encoding}}))
#		? 255 : 127;
#	$first = 0 if !defined $first || $first < 0;
#	$first = $lim if $first > $lim;
#	$last  = $lim if !defined $last || $last < 0 || $last > $lim;
#	my $i;
#	my @ret;
#	my ( $rmap, $nd ) = $self->get_rmap;
#	my $wmul = $self->{font}->{width} / $self->{fontWidthDivisor};
#	for ( $i = $first; $i < $last; $i++ ) {
#		my $cd = $rmap->[$i] || $nd;
#		push( @ret, map{ $_ * $wmul } @$cd[1..3]);
#	}
#	return \@ret;	
#}
#
sub get_text_width
{
	my ( $self, $text, $addOverhang ) = @_;
	my $i;
	my $len = length $text;
	my $context = $self->{cairo};
	return 0 unless $len;
#	$context->select_font_face( name, style, weight );
#	$context->set_font_size( size );	
#	my ($y_bearing, $width, $height) = $context->text_extents(text);
#	$context->restore();
#	return $width;
}

# helper functions
sub save_to_png
{
	my ( $self, $filename ) = @_;
	my $surface = $self->{surface};
	$surface->write_to_png($filename);
}

1;
__END__	
