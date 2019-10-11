#!/usr/bin/perl -w
###################################################
#
#   Mark Sattolo (mhsatto@cse-cst.gc.ca)
#  -------------------------------------------
#    File: @(#)wich.pl
#    Version: 1.3
#    Last Update: 07/02/26 13:58:00
#
###################################################

die "Usage: wich \$executable \n" unless scalar(@ARGV) == 1 ;

$exec = shift ;

#print "Executable to find: $exec \n" ;

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
    $found = $lookfor ;
    print $found ;
    last ;
  }
}

if ( ! $found ) { print "\t[31mNO $exec in $mypath[0m" ; }
  
print "\n" ;
