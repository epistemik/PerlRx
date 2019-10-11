#!/usr/local/bin/perl5
# -*- mode: perl -*-

# from http://www.ciphergoth.org/software/#crypto
#   I once wanted to use bash in an environment that only set up the csh environment properly,
#   so this was my solution: this script runs csh to find out what environment variables it set up,
#   then emits sh directives to do the same work.

$rcsid = q$Id: login-magic 1.1 Sat, 19 Jun 1999 19:19:22 +0100 paul $;

#use diagnostics;
#use strict;
#no strict 'vars';
#use Getopt::Long;
#use vars qw($rcsid $fh %optctl);

# Annoyingly, I can't *quite* use open2 for this because I need indirect object syntax.

$fh = 'FHOPEN000';

sub open2closure {
  no strict 'refs';
  my ($dad_rdr, $dad_wtr, $do_when_forked) = @_;
  my ($kid_rdr, $kid_wtr, $kidpid);

  $dad_rdr ne '' 		|| die "open2closure: rdr should not be null";
  $dad_wtr ne '' 		|| die "open2closure: wtr should not be null";
  
  # force unqualified filehandles into callers' package
#  local($package) = caller;
#  $dad_rdr =~ s/^[^']+$/$package'$&/ unless ref $dad_rdr;
#  $dad_wtr =~ s/^[^']+$/$package'$&/ unless ref $dad_wtr;

  $kid_rdr = ++$fh;
  $kid_wtr = ++$fh;

  pipe($dad_rdr, $kid_wtr) 	|| die "open2closure: pipe 1 failed: $!";
  pipe($kid_rdr, $dad_wtr) 	|| die "open2closure: pipe 2 failed: $!";

  if (($kidpid = fork) < 0) {
    die "open2closure: fork failed: $!";
  } elsif ($kidpid == 0) {
    close $dad_rdr; close $dad_wtr;
    open(STDIN,  "<&$kid_rdr");
    open(STDOUT, ">&$kid_wtr");
    &{$do_when_forked}
    or die "open2closure: failed after fork";
    exit 0;
  } 
  close $kid_rdr; close $kid_wtr;
  select((select($dad_wtr), $| = 1)[0]); # unbuffer pipe
  $kidpid;
}

#my ($var, $val, %csh_env, @new_path, %path_includes);

open2closure(\*READER, \*WRITER, sub {
   for (keys %ENV) {
   next if /^HOME$/ || /^LOGNAME$/ || /^USER$/;
    delete $ENV{$_}
  };
  chdir $ENV{HOME};
  $ENV{PATH} = '/bin:/usr/bin';
  exec {'/bin/csh'} '-sh';
});

#print WRITER "source .cshrc\n";
#print WRITER "source .login\n";
print WRITER "echo ENV_START\n";
print WRITER "env\n";
print WRITER "echo ENV_END\n";
print WRITER "logout\n";
close WRITER or die "Failed to close write stream to shell, stopped";

while (<READER>) {
  chomp;
  if (/^ENV_START$/ .. /^ENV_END$/) {
    if (($var, $val) = /^([^=]+)=(.*)$/) {
      $csh_env{$var} = $val;
    }
  }
}

# These should already be set in the current shell and shouldn't be mucked about.
delete $csh_env{USER};
delete $csh_env{LOGNAME};
delete $csh_env{HOME};
delete $csh_env{PWD};
delete $csh_env{TERM};


#print "# Old path: $csh_env{PATH}\n";
@old_path = split(/:/, $csh_env{PATH});
#print "# Split into: \n#   ", join("\n#   ", @old_path), "\n";
@new_path = ();

sub use_path {
#  my $self = shift;
  my $pattern = shift;
  print "# Matching path pattern $pattern\n";
  my $code_fragment = q{
    foreach (@old_path) {
      if (!defined $path_includes{$_} && m{PATTERN}o) {
        $path_includes{$_} = 1;
        if (-d $_) {
          print "# Adding to path: $_\n";
          push @new_path, $_;
        } else {
          print "# Dropping nonexistant directory: $_\n";
        }
#      } else {
#          print "# Not accepting nonmatch: $_\n";
      }
    }
  };
  $code_fragment =~ s/PATTERN/$pattern/;
  print "# Code used to match:\n";
  my $commented_code_fragment;
  $commented_code_fragment = $code_fragment;
  $commented_code_fragment =~ s/^/\# /gmo;
  print $commented_code_fragment, "\n";
#  print "# Old path: ", join(", ", @old_path), "\n";
  eval $code_fragment;
}


#GetOptions("use-path=s" => \@use_path);
# KLUDGE because GetOptions is shit in Perl 5.000
foreach (@ARGV) {
  next if /^--use-path$/;
  use_path($_);
}

foreach (sort keys %csh_env) {
  next if /^PATH$/;
  print "$_='$csh_env{$_}'\nexport $_\n";
}
print "PATH='", join(":", @new_path), "'\nexport PATH\n";

