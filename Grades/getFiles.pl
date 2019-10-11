opendir (DIR, 'D:\\My_Docs\\PROG\\Perl') or die "Couldn't open directory, $!";
while ($file = readdir DIR)
 {
  if (-d $file) { print "Directory: " ;}
  elsif (-T _) { print "Text: " ;}
  else { print "File: " ;}
  print "$file\n" ;
}
close DIR ;
