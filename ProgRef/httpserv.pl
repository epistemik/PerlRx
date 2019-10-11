#!/usr/local/bin/perl5 -w

use Ssockets;
use FileHandle;
use Cwd;
use Getopt::Std;
use Socket;
use vars qw/$opt_d/;
getopts('d');
use strict;

$SIG{'INT'} = $SIG{'QUIT'} = \&exit_request_handler;
$SIG{'CHLD'} = \&child_handler;

my ($res, $remaddr);
my ($SERVERPORT) = 4003;

unless(listensocket(*SERVERSOCKET, $SERVERPORT, 'tcp', 5))
{
    die "$0: ", $Ssockets::error;
}

autoflush SERVERSOCKET 1;

chroot(getcwd());
die "$0: Couldn't change root directory, are you root?"
    unless (getcwd() eq "/");

print "Changing root to ", getcwd(), "\n" if $opt_d;

print "Simple HTTP Server Started\n" if $opt_d;

while(1)
{
  ACCEPT_CONNECT:
    {
        ($remaddr = accept(CHILDSOCKET, SERVERSOCKET)) 
            || redo ACCEPT_CONNECT;
    }
    autoflush CHILDSOCKET 1;
    my $pid = fork();
    die "Cannot fork, $!" unless defined($pid);
    if ($pid == 0)
    {
        my ($remip) 
            = inet_ntoa((unpack_sockaddr_in($remaddr))[1]);
        print "Connection accepted from $remip\n" if $opt_d;
        $_ = <CHILDSOCKET>;
        print "Got Request $_" if $opt_d;
        chomp;

        unless (m/(\S+) (\S+)/)
        {
            print "Malformed request string $_\n" if $opt_d;
            bad_request(*CHILDSOCKET);
        }
        else
        {
            my ($command) = $1;
            my ($arg) = $2;
            if (uc($command) eq 'GET')
            {
                if (open(FILE, "<$arg"))
                {
                    while(<FILE>)
                    {
                        print CHILDSOCKET $_;
                    }
                    close(FILE);
                }
                else
                {
                    bad_request(*CHILDSOCKET);
                }
            }
        }
        close(CHILDSOCKET);
        exit(0);
    }
    close(CHILDSOCKET);
}

sub bad_request
{
    my ($SOCKET) = shift;

    print $SOCKET <<EOF
<html>
<head>
<title>Bad Request</title>
</head>
<body>
<h1>Bad Request</h1>
The file you requested could not be found
</body>
</html>
EOF
    ;
}    

sub child_handler
{
    wait;
}

sub exit_request_handler
{
    my ($recvsig) = @_;
    $SIG{'INT'} = $SIG{'QUIT'} = 'IGNORE';
    close(SERVERSOCKET);
    close(CHILDSOCKET);
    die "Qutting on signal $recvsig\n";
}
