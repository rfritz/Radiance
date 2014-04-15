#!/usr/bin/perl
#
# Make an interactive preview of a luminaire
#
# This script is based on Radiance's objview.pl plus
# Rob Guglielmetti's ltview extension to his objview.rb
#
# Written by Axel Jacobs <axel@jaloxa.eu>

use strict;
use warnings;
use Math::Trig;
use File::Copy qw(copy);
use File::Temp qw/ tempdir /;

my $td     = tempdir( CLEANUP => 1 );
my $oct    = "$td/ltview.oct";
my $room   = "$td/room.rad";
my $box;                # Overall box dimensions
my $default_box = 10;   # Default box dimensions
my $rif    = "$td/ltview.rif";
my $lumi   = "$td/lumi.rad";    # Fitting as given on cmd line, or generated by ies2rad
my $lumi2  = "$td/lumi2.rad";   # Fitting scaled to max unity
my $raddev = "x11";     # default output device. Overwrite with -o
my $is_ies = 0;         # input file is IES photometry, not a Radiance luminaire

my $maxscale = 1;       # Maximum luminiare dimension after scaling
my $opts     = "";      # Options common to rad and glrad
my $render   = "-ab 1 -ds .15 -av 0 0 0";    # render= line in rif file
my $radopt   = 0;       # An option specific to rad was passed (Boolean).

while (@ARGV) {
	$_ = $ARGV[0];
	if (m/-i/) {
		$is_ies = 1;
	} elsif (m/-o/) {   # output device (rvu -devices)
		$raddev = $ARGV[1];
		$radopt = 1;
		shift @ARGV;
	} elsif (m/-b/) {
		$box = $ARGV[1];    # Box dimensions
		shift @ARGV;
	} elsif (m/^-\w/) {
		die("objview: Bad option: '$_'\n");
	} else {
		last;
	}
	shift @ARGV;
}

# We need exactly one Radiance luminaires or IES file
if (! $#ARGV == 0) {
	die("ltview: Need one Radiance luminaire or IES file.\n");
}

if ($is_ies == 0) {
	# Input file is a Radiance luminaire
	$lumi = $ARGV[0];
} else {
	# Input file is IES photometry
	system "ies2rad -p $td -o lumi $ARGV[0]";
}


open(FH, ">$room") or
		die("ltview: Can't write to temporary file '$room'\n");
print FH "void plastic wall_mat  0  0  5 .2 .2 .2 0 0\n";

my $b2;
if (defined $box) {
	# Room dimensions are giving explicitly.  Don't touch the fitting.
	$b2 = $box / 2;

	$lumi2 = $ARGV[0];
} else {
	# Scale fitting so it fits nicely into our default test room.
	$b2 = $default_box;    # Default room dimension

	# Work out how large the luminaire is and scale so that the longest
	# axis-align dimension is $maxscale
	my $dimstr = `getbbox -h $lumi`;
	chomp $dimstr;
	# Values returned by getbbox are indented and delimited with multiple spaces.
	$dimstr =~ s/^\s+//;   # remove leading spaces
	my @dims = split(/\s+/, $dimstr);   # convert to array

	# Find largest axes-aligned dimension
	my @diffs = ($dims[1]-$dims[0], $dims[3]-$dims[2], $dims[5]-$dims[4]);
	@diffs = reverse sort { $a <=> $b } @diffs;
	my $size = $diffs[0];

	# Move objects so centre is at origin
	my $xtrans = -1.0 * ($dims[0] + $dims[1]) / 2;
	my $ytrans = -1.0 * ($dims[2] + $dims[3]) / 2;
	my $ztrans = -1.0 * ($dims[4] + $dims[5]) / 2;
	# Scale so that largest object dimension is $maxscale
	my $scale = $maxscale / $size;

	#system "xform -t $xtrans $ytrans $ztrans -s $scale $ARGV[0] > $lumi";
	system "xform -t $xtrans $ytrans $ztrans -s $scale $lumi > $lumi2";
}

print FH <<EndOfRoom;
# Don't generate -y face so we can look into the box (could use clipping)
#wall_mat polygon box.1540  0  0  12  $b2 -$b2 -$b2  $b2 -$b2 $b2  -$b2 -$b2 $b2  -$b2 -$b2 -$b2
wall_mat polygon box.4620  0  0  12  -$b2 -$b2 $b2  -$b2 $b2 $b2  -$b2 $b2 -$b2  -$b2 -$b2 -$b2
wall_mat polygon box.2310  0  0  12  -$b2 $b2 -$b2  $b2 $b2 -$b2  $b2 -$b2 -$b2  -$b2 -$b2 -$b2
wall_mat polygon box.3267  0  0  12  $b2 $b2 -$b2  -$b2 $b2 -$b2  -$b2 $b2 $b2  $b2 $b2 $b2
wall_mat polygon box.5137  0  0  12  $b2 -$b2 $b2  $b2 -$b2 -$b2  $b2 $b2 -$b2  $b2 $b2 $b2
wall_mat polygon box.6457  0  0  12  -$b2 $b2 $b2  -$b2 -$b2 $b2  $b2 -$b2 $b2  $b2 $b2 $b2
EndOfRoom
close(FH);

my $scene = "$room $lumi";
# Make this work under Windoze
if ( $^O =~ /MSWin32/ ) {
	$scene =~ s{\\}{/}g;
	$oct =~ s{\\}{/}g;
	$raddev = "qt";
}

# Tweak bounding box so we get a nice view covering all of the box, without
# having a wasteful black border around it.  Must work for arbitrary box dims.
my $zone = 1.1 * $b2 * ( 1 + 1/tan(22.5*pi/180) );

open(FH, ">$rif") or
		die("ltview: Can't write to temporary file '$rif'\n");
print FH <<EndOfRif;
scene= $scene
EXPOSURE= 2
ZONE= Interior -$zone $zone  -$zone $zone  -$zone $zone
UP= Z
view= y
OCTREE= $oct
oconv= -f
render= $render
EndOfRif
close(FH);

exec "rad -o $raddev $opts $rif";

#EOF
