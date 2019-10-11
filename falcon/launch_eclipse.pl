#!/usr/bin/perl

# from Bill Collison

use Term::ReadKey;
 
print "Enter your password: ";
ReadMode 'noecho';
$password = ReadLine 0;
chomp $password;
ReadMode 'normal';
 
my $ini_file = "/local_data/mhsatto/eclipse/eclipse.ini";
my $eclipseLaunch = "/local_data/mhsatto/eclipse/eclipse&";
my $sleepTime = 30;
 
open(INI_FILE, ">>$ini_file") or die "can't open $ini_file";
print INI_FILE "-Djavax.net.ssl.keyStorePassword=$password";
close INI_FILE;
 
print "Password added to Keystore...\n";
print "Launching Eclipse ...\n";
system($eclipseLaunch);
 
#Wait some time
sleep($sleepTime);
 
print "Deleting password from ini.\n";
 
#remove the last line from the file
my $addr;
open (INI_FILE, "+< $ini_file") or die "can't update $file: $!";
while ( <INI_FILE> ) {
    $addr = tell(INI_FILE) unless eof(INI_FILE);
}
truncate(INI_FILE, $addr) or die "can't truncate $file: $!";
close INI_FILE;

