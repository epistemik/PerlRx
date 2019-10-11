#!/usr/bin/perl -w
###################################################
#
#   Mark Sattolo (mhsatto@cse-cst.gc.ca)
#  -------------------------------------------
#    File: @(#)chextg.pl
#    Version: 1.1
#    Last Update: 05/02/07 14:23:57
#
###################################################

die "Usage: chextg old_ext new_ext \n" unless scalar(@ARGV) == 2 ;

$old = shift ;
$new = shift ;

print "OLD extension: .$old \n" ;
print "NEW extension: .$new \n" ;

#print qq| $ENV{q^PATH^} \n| ;

@files = glob("*.$old") ;

foreach $file (@files)
{
  $oldfile = $file ;
  print "current file: $file \n" ;
  $file =~ s|\.$old|\.$new|g ;
  #print "old name: $oldfile \n" ;
  print "     new name: $file \n" ;
  rename($oldfile, $file) ;
}
