#!/usr/bin/perl -w
###################################################
#
#   Mark Sattolo (mhsatto@cse-cst.gc.ca)
#  -------------------------------------------
#    File: @(#)whereis.pl
#    Version: 1.3
#    Last Update: 07/02/26 14:03:13
#
###################################################

die "Usage: whereis \$executable \n" unless scalar(@ARGV) == 1 ;

$exec = shift ;

print "Executable to find: $exec \n" ;

$mypath = $ENV{q^PATH^} ;
#print "$mypath \n\n" ;

$found = "" ;

@path = split /:/, $mypath ;
#print @path ;

foreach $dir ( @path )
{
  #print "path directory: $dir \n" ;
  $lookfor = $dir."/".$exec ;
  #print "looking for $lookfor \n" ;

  if ( -x $lookfor )
  {
    $found = "\t[1mFOUND: $lookfor [0m" ;
    print $found ;
    last ;
  }
}

if ( ! $found ) { print "\t[31mNO $exec in \$PATH[0m" ; }
  
print "\n" ;
