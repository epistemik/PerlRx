#!/usr/bin/perl -w

die "Usage: wich <executable> \n" unless scalar(@ARGV) == 1 ;

$exec = shift ;
print "executable to find: $exec \n\n" ;

$mypath = $ENV{q^PATH^} ;
print "$mypath \n\n" ;

$found = "" ;

@path = split /:/, $mypath ;
#print @path ;

foreach $dir (@path)
{
	print "path directory: $dir \n" ;
	$lookfor = $dir."/".$exec ;
	print "looking for $lookfor \n" ;
	
	if( -x $lookfor )
	{
		$found = "FOUND: $lookfor \n" ;
		print $found ;
		last ;
	}
}

if( ! $found )
{
	print "\n NO $exec in \$PATH" ;
}
print "\n" ;
