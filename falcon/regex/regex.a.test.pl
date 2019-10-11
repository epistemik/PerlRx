#!/usr/local/bin/perl -w

($file) = @ARGV ;
open(FILE, $file) or die "Can't open $file: $!\n" ;
while ($line = <FILE>)
 { 
  if ( $line =~ m|\b\+\b| )
   { print "match: '", $&, "' in line: ", $line ; }
 }