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

die "Substitute the OLD pattern of every file in the current folder for the NEW pattern.\nUsage: subFileNamesCurFldr old_pattern [new_pattern] (No new_pattern = remove old_pattern).\n" unless scalar(@ARGV) >= 1 ;

$old = shift ;
$new = shift ;
if( ! $new ) {
  $new = "";
}

print "OLD pattern: $old \n" ;
print "NEW pattern: $new \n" ;

#print qq| $ENV{q^PATH^} \n| ;

@files = glob("*") ;

foreach $file (@files) {
  $oldfile = $file ;
  print "current file: $file \n" ;
  $file =~ s|$old|$new|g ;
  #print "old name: $oldfile \n" ;
  print "     new name: $file \n" ;
  rename($oldfile, $file) ;
}
