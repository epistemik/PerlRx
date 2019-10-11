#!/usr/local/bin/perl5 -w

use strict;

use Net::DNS;
use Net::Domain;

my $hostfqdn = Net::Domain::hostfqdn();
my ($dnsdir,$cache,@secondaries,@primaries,%dnshosts);

open(DNSCONF,"<$ARGV[0]") or die "Couldn't open $ARGV[0], $!";

while(<DNSCONF>)
{
    chomp;
    s/\s+//g;
    my ($type,$opt) = split(/:/,$_,2);
    if ($type eq 'dir')
    {
        $dnsdir = $opt;
    }
    elsif ($type eq 'cache')
    {
        $cache = $opt;
    }
    elsif ($type eq 'primary')
    {
        push(@primaries,$opt);
    }
    elsif ($type eq 'secondary')
    {
        push(@secondaries,$opt);
    }
}
close(DNSCONF) or die "Couldn't close $ARGV[0], $!";

open(NAMED,">$ARGV[0].boot") 
    or die "Couldn't open $ARGV[0].boot, $!";

print NAMED "directory $dnsdir\n";
print NAMED "cache . $cache";

for my $primary (sort @primaries)
{
    print NAMED "primary $primary primary/$primary\n";
}

my $res = new Net::DNS::Resolver;
unless ($res)
{
    die "Error creating resolver";
}

for my $domain (sort @secondaries)
{
    my $query = $res->query($domain,"NS");
    unless ($query)
    {
        print("Error processing query for $domain: ",
              $res->errorstring,"\n");
        next;
    }        
    my (@remote,@local);

    for my $rr ($query->answer)
    {
        next unless($rr->type eq 'NS');
        next if ($rr->nsdname eq $hostfqdn);
        my $islocal = 0;
        for my $dom (@primaries)
        {
            if ($rr->nsdname =~ /$dom$/)
            {
                $islocal=1;
                last;
            }
        }
        if ($islocal)
        {
            push(@local,$rr->nsdname);
        }
        else
        {
            push(@remote,$rr->nsdname);
        }
    }
    print NAMED "secondary $domain ";
    for my $host (@local,@remote)
    {
        unless(defined($dnshosts{$host}))
        {
            $dnshosts{$host} = 
                join('.',
                     unpack('C4',
                            gethostbyname($host)));
        }
        print NAMED "$dnshosts{$host} " 
            if(defined($dnshosts{$host}));
    }
    print NAMED " secondary/$domain\n";
}

close(NAMED) 
    or die "Couldn't close $ARGV[0].boot, $!";
