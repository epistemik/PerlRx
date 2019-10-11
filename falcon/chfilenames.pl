#!/usr/bin/perl -w
###################################################
#
#   Mark Sattolo (mhsatto@cse-cst.gc.ca)
#  -------------------------------------------
#    File: @(#)chfilenames.pl
#    Version: 1.1
#    Last Update: 05/02/07 14:24:06
#
###################################################

# change all files in the specified directory to a common name with one-up
# number at the end: e.g. base1, base2, base3, etc.

die "Usage: $0 target_dir base_name \n" unless scalar(@ARGV) == 2 ;

$dir = shift ;
$base = shift ;
$num = 1 ;

print "target directory: $dir \n" ;
print "base name: $base \n" ;

@files = glob( "$dir/*" ); #seems to avoid . files anyway

print "target files: @files \n" ;

foreach $file ( @files )
{
  $oldfile = $file ;
  if( $oldfile !~ m|$dir/\..*| ) #avoid . files
  {
    print "current file: $file \n" ;
    $file = "$dir/$base$num" ;
    print "    new name: $file \n" ;
    rename( $oldfile, $file ) ;
    $num++ ;
  }
}
