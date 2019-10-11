#!/usr/local/bin/perl -w

($file) = @ARGV ;
open(FILE, $file) or die "Can't open $file: $!\n" ;
while ($line = <FILE>)
 { 
  if ( $line =~ /\b\Fred\b/ )
   { print "match: '", $&, "' in line: ", $line ; }
 }