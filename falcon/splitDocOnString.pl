#!/usr/bin/perl -w
###################################################
#
#   Mark Sattolo (mhsatto@cse-cst.gc.ca)
#  -------------------------------------------
#    splitDocOnString.pl
#
###################################################

die "Usage: splitDocOnString <doc name> <target string> <new doc basename> \n" unless scalar(@ARGV) == 3 ;
($doc, $target, $filename) = @ARGV ; # from command line

my $filecount = 0;
open(INFILE, '<', $doc) or die $!;
open( OUTFILE, '>', sprintf("$filename%02d.txt", ++$filecount) ) or die $!;
while( my $line = <INFILE> ) {
    if( $line =~ /$target/ ) {
        close(OUTFILE);
        open( OUTFILE, '>', sprintf("$filename%02d.txt", ++$filecount) ) or die $!;
    }
    print OUTFILE $line or die "Failed to write to file: $!";
}

close(OUTFILE);
close(INFILE);

