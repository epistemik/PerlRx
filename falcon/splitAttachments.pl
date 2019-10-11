#!/usr/bin/perl

#use strict;
use warnings;

open(INFILE, '<', 'fixed.dat') or die $!;

my $filecount = 0;

open( OUTFILE, '>', sprintf('fixed%02d.dat', ++$filecount) ) or die $!;
while( my $line = <INFILE> ) {
    if( $line =~ /attachment/ ) {
        close(OUTFILE) if <OUTFILE>;
        open( OUTFILE, '>', sprintf('fixed%02d.dat', ++$filecount) ) or die $!;
    }
    print OUTFILE $line or die "Failed to write to file: $!";
}

close(OUTFILE);
close(INFILE);

