#!/usr/local/bin/perl -w

($file) = @ARGV ;
open(FILE, $file) or die "Can't open $file: $!\n" ;
while (<FILE>)
  { print if /\bFred\b/ ; }
