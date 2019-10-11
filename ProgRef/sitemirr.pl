#!/usr/local/bin/perl

use strict;
use LWP::Simple;
use LWP::UserAgent;
use HTML::LinkExtor;
use URI::URL;
use Getopt::Long;
use File::Basename;

my ($file,$host,$localdir,$curhost);
my ($url, $specdir, $quiet, $silent, $inchost, $unrestrict) 
    = (undef, undef, undef, undef, undef);

usage() unless(GetOptions("d=s" => \$specdir,
                          "s"   => \$silent,
                          "q"   => \$quiet,
                          "h"   => \$inchost,
                          "u"   => \$unrestrict
                          ));

usage() unless($url=shift);
$specdir = '.' unless defined($specdir);
$specdir = "$specdir/" unless ($specdir =~ m#/$#);
$quiet = 1 if ($silent);
                             
my %fullurl;
my @urlstack = ($url);
my @urls = ();
my $p = HTML::LinkExtor->new(\&callback);

my $ua = new LWP::UserAgent;
my $res = $ua->request(HTTP::Request->new(GET => $url));
my $base = $res->base;
$curhost = $host = url($url,'')->host;

print "Retrieving from $url to $specdir", 
      ($inchost ? "$host\n" : "\n")
           unless ($silent);

while ($url = pop(@urlstack))
{
    $host = url($url,'')->host;
    if ($host ne $curhost)
    {
        my $ua = new LWP::UserAgent;
        my $res = $ua->request(HTTP::Request->new(GET => $url));
        my $base = $res->base;
        $host = url($url,'')->host;
        $curhost = $host;
        print "Changing host to $host\n" unless $quiet;
    }        
    $localdir = ($inchost ? "$specdir$host/" : "$specdir/");
    
    $file = url($url,$base)->full_path;
    $file .='index.html' if ($file =~ m#/$#);
    $file =~ s#^/#$localdir#;
                             
    print "Retrieving: $url to $file\n" unless ($quiet);
    my $dir = dirname($file);
    unless (-d $dir)
    {
        mkdirhier($dir);
    }
    getfile($url,$file);
    if (-e $file)
    {
        $p->parse_file($file);
        @urls = map { $_ = url($_, $base)->abs; } @urls;
        addtostack(@urls);
    }
}

sub addtostack
{
    my (@urllist) = @_;

    for my $url (@urllist)
    {
        next if ($url =~ /#/);
        next unless ($url =~ m#^http#);
        my $urlhost = url($url,$base)->host;
        unless (defined($unrestrict)) 
            { next unless ($urlhost eq $host); };
        push(@urlstack,$url) unless(defined($fullurl{$url}));
        $fullurl{$url} = 1;
    }
}

sub callback 
{
    my($tag, %attr) = @_;
    push(@urls, values %attr);
}

sub getfile
{
    my ($url,$file) = @_;
    my $rc = mirror($url, $file);
    
    if ($rc == 304) 
    {
        print "File is up to date\n" unless ($quiet);
    } 
    elsif (!is_success($rc))
    {
        warn "sitemirr: $rc ", status_message($rc), " ($url)\n" 
            unless ($silent);
        return(0);
    }
}

sub mkdirhier
{
    my ($fullpath) = @_;
    my $path;

    for my $dir (split(m#/#,$fullpath))
    {
        unless (-d "$path$dir")
        {
            mkdir("$path$dir",0777) 
                or die "Couldn't make directory $path/$dir: $!";
        }
        $path .= "$dir/";
    }
}

sub usage
{
    die <<EOF;
Usage:
    sitemirr.pl [-d localdir] [-s] [-q] URL

Where:

localdir is the name of the local directory you want
         files copied to (default: .)
h        Include host in local directory path
q        Retrieve quietly (show errors only)
s        Retrieve silently (no output)
u        Unrestrict site match (will download ALL
         URL's, including those from other hosts)
EOF
}
