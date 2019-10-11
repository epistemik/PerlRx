# #!/usr/bin/perl/ -s

while( @ARGV )
  {
    $p = shift ;
    print "'$p'\n" ;
    while( $p )
    {
      $c = substr( $p, 0, 1 );
      #print "'$c'\n" ;
      $p = substr( $p, 1, length($p)-1 );
      #print "'$p'\n" ;
      $c .= _ ;
      print $c ;
    }
    print "\n" ;
  }

$cwd = Win32::GetCwd();
print "$cwd\n" ;

$os = Win32::GetOSVersion();
print "OS Version: $os\n" ;
