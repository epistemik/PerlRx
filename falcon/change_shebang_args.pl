#!/usr/bin/perl -w
###################################################
#
#   Mark Sattolo (mhsatto@cse-cst.gc.ca)
#  -------------------------------------------
#    File: @(#)change_shebang_args.pl
#    Version: 1.1
#    Last Update: 05/02/07 14:23:40
#
###################################################

die "Usage: change_shebang_args target_dir new_dir \n" unless scalar(@ARGV) == 2 ;

($dir, $newdir) = @ARGV ; #old and new directories from command line
$target = "#!/apps/perl/bin/perl -w\n" ; #old perl home

opendir(HOME, $dir) or die "1. Cannot open $dir: $!\n" ;
mkdir($newdir, 0750) or die "2. Cannot make directory $newdir: $!\n" ;

while ($name = readdir(HOME))
{
  print "working on $name\n" ;
  $file = $dir."/".$name ; #add path to file name
   
  if (-f $file) #regular file
  {
    $newfile = $newdir."/".$name ; #create new path+file name
    open(PLFILE, $file) or die "3. Can't open $file: $!\n" ;
    open(NEWFILE, "> $newfile") or die "4. Can't open $newfile: $!\n" ;
    print "writing $newfile\n\n" ;
      
    #change the shebang if necessary then copy all other lines as is
    while ($line = <PLFILE>)
    {
      if ($line eq $target)
      { print NEWFILE "#!/usr/local/bin/perl -w\n\n" ; } #new perl home
      else
        { print NEWFILE $line ; }
    }
    # set the proper permissions for the new file
    if (-x $file) { chmod(0740, $newfile) ; }
      
    close(NEWFILE) ;
    close(PLFILE) ;
  }#if(file)
     
}#while
  
closedir(HOME) ;
