#!/usr/bin/perl -w
###################################################
#
#   Mark Sattolo (mhsatto@cse-cst.gc.ca)
#  -------------------------------------------
#    File: @(#)findscedit.pl
#    Version: 1.5
#    Last Update: 07/02/09 14:35:54
#
###################################################

$current = $ENV{q^PWD^} ;
print "Starting Dir: [1m$current[0m\n" ;

check ( $current );


# recursive function &check
#   make sure all the vars are private ('my') so that the recursion will not overwrite 
#   the parent values
sub check
{
  my @allEntries ;
  my $count = 1 ;
  my $dir = shift( @_ );
  #print "working on $dir\n" ;
  
  if ( opendir( CHECKDIR, $dir ) )
  {
    @allEntries = readdir CHECKDIR ;
    #print "@allEntries\n" ;
    closedir( CHECKDIR );
  }
  else
    { print "[34mCANNOT open $dir: [1m$!\n[0m" ; }
    
  foreach $file ( @allEntries )
  {
    my $absfile = $dir."/"."$file" ;
    #print "working on $file in $dir\n" ;
    
    if ( -d $absfile ) # directories
    {
      if ( $file eq "SCCS" ) # find SCCS directories
      {
        my @sccsFiles ;
        print "[31mFound an SCCS directory: $absfile[0m\n" ;
        
	    if ( opendir( SCCSDIR, $absfile ) )
	    {
          # check for p (checked-out) files
	      @sccsFiles = grep /^p\..?/, readdir SCCSDIR ;
	      #print "@sccsFiles\n" ;
	      closedir( SCCSDIR );
        }
        else
          { print "[1mCANNOT open $absfile: [31m$!\n[0m" ; }
          
	    foreach $sccs ( @sccsFiles )
	    {
	      print "\t[1;31m! Found an open SCCS file: ", $absfile, "/", $sccs, " ![0m\n" ;
	    }
      }
      elsif ( $file ne "." && $file ne ".." ) # skip . and ..
        {
	      #print "Found a new sub-directory to try: $absfile\n" ;
	      check ( $absfile );
	    }
    }
    #print "at #", $count++, "\n" ;
  }
  #print "Finished foreach loop.\n" ;
  
}# sub check
