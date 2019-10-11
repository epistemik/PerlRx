#!/usr/local/bin/perl5 -w

use strict;
use FileHandle;
use Getopt::Std;
my $usage = "Usage: [-r | [-e|m alias...]] [-f aliasfile]";
use vars qw/$opt_e $opt_f $opt_m $opt_r/;
die $usage unless (getopts('merf:'));
$opt_e = 1 unless($opt_r || $opt_m);
$opt_f = '/etc/aliases' unless ($opt_f);
die $usage unless @ARGV or $opt_r;

my %alias = readaliases($opt_f);
expand_aliases(\%alias) if $opt_e;
member_of(\%alias) if $opt_m;
report_bad_aliases(\%alias) if $opt_r;

sub member_of
{
    local *alias = shift;
    my %members = memberalias(\%alias);
    
    for $_ (@ARGV)
    {
        if ($members{$_})
        {
            print "$_ is a member of $members{$_}\n";
        }
        else
        {
            print "$_ isn't a member of anything\n";
        }
    }
}

sub expand_aliases
{
    local *alias = shift;
    for $_ (@ARGV)
    {
        my @expand=expandalias(\%alias,$_);
        if ($expand[-1])
        {
            print "$_ expands to @expand\n";
        }
        else
        {
            print "$_ not found in alias DB\n";
        }
    }
}

sub report_bad_aliases
{
    local *alias = shift;
    my %erroralias;
    for my $aliasname (keys %alias)
    {
        my @members = expandalias(\%alias,$aliasname);
        for my $member (@members)
        {
            if ($member)
            {
                unless (($member =~ /.*@.*/) || 
                        ($member =~ /^\/.*/) ||
                        ($member =~ /["!|]/))
                {
                    $erroralias{$aliasname} .= 
                        "$member " unless getpwnam(lc($member));
                }
            }
        }
    }
    if (keys %erroralias)
    {
        for my $aliasname (keys %erroralias)
        {
            print("Alias $aliasname has missing members:",
                $erroralias{$aliasname},"\n");
        }
    }
    else
    {
        print "No problems found";
    }
}

sub readaliases
{
    my $file = shift;
    my (%alias,$aliasname,$members);
    open(D,"<$file") || die "Cannot open $file, $!";
    while (<D>)
    {
        next if /^#/;
        chomp;
        ($aliasname,$members) = split /:\s+/;
        $alias{(lc($aliasname))} = lc($members);
    }
    close(D) || return 0;;
    return(%alias);
}

sub expandalias
{
    *alias = shift;
    my $expand = shift;
    my @expanded;
    my @toexpand = split /\s*,\s*/,$expand;

    return(0) unless $alias{$expand};

  OUTEXPAND:
    {
        while ($#toexpand >= 0)
        {
            my $toexpand = pop @toexpand;
          EXPAND:
            {
                if (defined($alias{$toexpand}))
                {
                    if (defined($alias{$alias{$toexpand}}))
                    {
                        $toexpand = $alias{$alias{$toexpand}};
                        redo EXPAND;
                    }
                    $toexpand = $alias{$toexpand};
                }
            }
            if ($toexpand =~ /,/)
            {
                push @toexpand,split(/\s*,\s*/,$toexpand);
                redo OUTEXPAND;
            }
            else
            {
                push @expanded,$toexpand;
            }
        }
    }
    my %dedupe;
    for (@expanded)
    {
        $dedupe{$_} = 1;
    }
    return (keys %dedupe);
}

sub expandaliases
{
    *alias = shift;
    
  EXPAND:
    {
        for $_ (sort keys %alias)
        {
            if (defined($alias{$alias{$_}}))
            {
                delete $alias{$_};
                redo EXPAND;
            }
        }
    }
}

sub memberalias
{
    *alias = shift;
    my %mteams;

    for my $aliasname (keys %alias)
    {
        for my $member (split /,/,$alias{$aliasname})
        {
            $mteams{$member} .= "$aliasname ";
        }
    }
    return %mteams;
}

    

