#File: renameKQ.pl
#Name: Mark Sattolo

# load the Win32 file functions - all in Version 0.09
use Win32API::File 0.09 qw( :ALL );

# get the directory from cmd line or set the dir in the script
#die "Usage: renameKQ.pl 'directory' \n" unless scalar(@ARGV) == 1 ;
$dir = "D:/Progra~1/Sierra/test" ;
die "Cannot find files.\n" unless @files = glob("$dir/*.vol") ;

# examine each file - create a hash with a 'time'->'name' entry for each file
foreach $file (@files)
 {
  die "Cannot examine files.n" unless $desc = (-M $file);
  $kqhash{"$desc"} = $file ;
 }

# create a new directory to copy the files into, just to be safe
die "Cannot make directory.\n" unless $newdir = mkdir "$dir/renameKQtest" ;

# reverse sort (oldest to newest) the hash on the keys and rename the files in order
$index = 1 ;
foreach $item (reverse sort { $a <=> $b } keys %kqhash)
 {
  print "$kqhash{$item} == $item \n" ;
  die "Cannot rename files.\n" unless MoveFile($kqhash{$item}, "$newdir/save$index.vol") ;
  $index++ ;
 }
