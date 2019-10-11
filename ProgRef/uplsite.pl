#!/usr/local/bin/perl5

use strict;
use Net::FTP;
use Getopt::Long;
use File::Find;
use Cwd;

my $debug      = 1;
my $remserver  = undef;
my $remport    = '21';
my $user       = 'anonymous';
my $password   = 'me@foo.bar';
my $dir        = '.';
my $localdir   = './';
my $curxfermode = 'ASCII';

unless (GetOptions("d" => \$debug,
                   "s=s" => \$remserver,
                   "r=s" => \$dir,
                   "p=i" => \$remport,
                   "u=s" => \$user,
                   "w=s" => \$password,
                   "l=s" => \$localdir
                   ))
{
    usage();
}

usage() unless $remserver;

$localdir = './' unless ($localdir);
my $ftp = Net::FTP->new($remserver, 'Port' => $remport);
die "Could not connect to $remserver" unless $ftp;
$ftp->login($user, $password) 
    or die "Couldn't login to $remserver";
$ftp->cwd($dir) 
    or die "Invalid directory ($dir) on FTP Server";
$ftp->ascii()
    or warn "Couldn't change default xfer mode, continuing";

chdir($localdir);
my $currentdir = getcwd();
find(\&sendfile,'.');

$ftp->quit();

sub sendfile
{
    my $file      =  $File::Find::name;
    $file         =~ s#^\./##g;
    my $localfile =  "$currentdir/$file";
    $localfile    =~ s#//#/#g;
    my $remfile   =  $file;

    print "Processing $localfile rem($remfile)\n" if $debug;

    if (-d $localfile)
    {
        my $remcurdir = $ftp->pwd();
        unless($ftp->cwd($remfile))
        {
            unless ($localfile eq '..')
            {
                print "Attempting to make directory $remfile\n";
                $ftp->mkdir($remfile,1) or 
                    die "Couldn't make directory $remfile";
            }
        }
        else
        {
            $ftp->cwd($remcurdir) or
                die "Couldn't change to directory $currentdir";
        }
    }
    else
    {
        my ($remtime,$localtime,$upload) = (undef,undef,0);
        unless($remtime = $ftp->mdtm($remfile))
        {
            $remtime = 0;
        }
        $localtime = (stat($file))[9];
        if (defined($localtime) and defined($remtime))
        {
            if ($localtime > $remtime)
            {
                $upload=1;
            }
        }
        else
        {
            $upload=1;
        }
        if ($upload)
        {
            if (-B $localfile)
            {
                if ($curxfermode eq 'ASCII')
                {
                    if ($ftp->binary())
                    {
                        $curxfermode = 'BIN';
                        print "Changed mode to BINary\n" 
                            if $debug;
                    }
                    else
                    {
                        warn "Couldn't change transfer mode";
                    }
                }
            }
            else
            {
                if ($curxfermode eq 'BIN')
                {
                    if ($ftp->ascii())
                    {
                        $curxfermode = 'ASCII';
                        print "Changed mode to ASCII\n" 
                            if $debug;
                    }
                    else
                    {
                        warn "Couldn't change transfer mode";
                    }
                }
            }
            print "Uploading $localfile to $remfile\n" if $debug;
            $ftp->put($localfile,$remfile) 
                or warn "Couldn't upload $remfile";
        }
        else
        {
            print "File $remfile appears to be up to date\n" 
                if $debug;
        }
    }
}

sub usage
{
    print <<EOF;
Usage:

    uplsite.pl [-d] [-r remdir] [-p remport] [-u user] 
               [-w password] [-l localdir] -s server

Description:

Uploads a directory structure to the server using FTP.

Where:

-d  Switch on debugging output
-r  Remote directory to upload to (defaults to .)
-p  The remote port to use (defaults to 21)
-u  The user name to login as (defaults to anonymous)
-w  The password to use (defaults to me\@foo.bar)
-l  The local directory to upload from (defaults to .)
-s  The remote server address to upload to (required)

EOF
    exit 1;
}
