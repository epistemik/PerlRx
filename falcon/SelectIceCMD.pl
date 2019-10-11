#!/bin/env perl

use strict;

use File::Copy;
use File::Find;
use Cwd;

my $SYNTAX = "\nSyntax: SelectCMD.pl -(c|d|m) {c=copy, d=delete, m=move} -p <pattern>\n" . 
               "        -l <fileExt2Search> [-e <fileExt2CMD>] [-f <fromDirs>] -t <toDir>\n" .
               "        [-a {allFiles}] [-r {recursive}]\n";
my $COPY = 1;
my $MOVE = 2;
my $DELETE = 3;
my $FALSE = 0;
my $TRUE = 1;

my @args = initialize(@ARGV);
proc(shift @args, shift @args, shift @args, shift @args, shift @args, shift @args, shift @args, shift @args);

sub Error {
    my $error = shift @_;
    
    print "Error! " . $error . "\n";
    print $SYNTAX;
    exit;
}

sub Warn {
    my $warning = shift @_;
    
    print "Warning! " . $warning . "\n";
}

sub isSwitch {
    my $switch = shift @_;
    if ($switch =~ /^-([acdeflmprt])$/) {
        return $1;
    } else {
        return 0;
    }
}

sub initialize {
    
    my $action;
    my @patterns;
    my @extensionsL;
    my @extensionsA;
    my @srcDir;
    my $destDir;
    my $all;
    my $recurse;
    
    my $switch;
    my @args = @_;
    
    for (my $i = 0; $i < @args; $i++) {
        if (isSwitch($args[$i])) {
            $switch = isSwitch($args[$i]);
            if ($switch eq "c") {$action = $COPY; $switch = undef;}
            if ($switch eq "m") {$action = $MOVE; $switch = undef;}
            if ($switch eq "d") {$action = $DELETE; $switch = undef;}
            if ($switch eq "a") {$all = $TRUE; $switch = undef;}
            if ($switch eq "r") {$recurse = $TRUE; $switch = undef;}
        } else {
            if ($switch eq "p") {
                push @patterns, $args[$i];
            } elsif ($switch eq "l") {
                push @extensionsL, $args[$i];
            } elsif ($switch eq "e") {
                push @extensionsA, $args[$i];
            } elsif ($switch eq "f") {
                -d $args[$i] ? push @srcDir, $args[$i] : Warn("Invalid input directory: " . $args[$i]);
            } elsif ($switch eq "t") {
                -d $args[$i] ? $destDir = $args[$i] : Warn("Invalid output directory: " . $args[$i]);
                $switch = undef;
            } else {
                Warn("Invalid parameter: " . $args[$i]);
            }
        }
    }
    
    if (! @extensionsA) {
        push @extensionsA, ".pb";
        push @extensionsA, ".dat";
	push @extensionsA, ".pb.str",
	push @extensionsA, "_orig.pb.str",
	push @extensionsA, "_orig.pb",
	push @extensionsA, "_orig.dat";
    }
    
    if (! @srcDir) {
        push @srcDir, getcwd();
    }
    
    if (! defined($all)) {
        $all = $FALSE;
    }
    
    if (! defined($recurse)) {
        $recurse = $FALSE;
    }
    
    if (! $all) {
        if (! @patterns) {
            Error("Missing pattern parameter");
        }
        if (! @extensionsL) {
            Error("Missing file extension to search parameter");
        }
    }
    
    if ($action != $DELETE) {
        if (! defined ($destDir)) {
            Error("Missing destination directory parameter");
        }
    }
    
    
    if (defined($action) && @extensionsA && @srcDir && defined($all) && defined($recurse)) {
        return ($action, \@patterns, \@extensionsL, \@extensionsA, processDirs(\@srcDir), processDestDir($destDir), $all, $recurse);
    } else {
        Error("Missing parameter");
    }
    
    
}

sub proc {
    my $action = processAction(shift @_);
    my $patterns = processPatterns(shift @_);
    my $extensionsL = processExtensions(shift @_);
    my @extensionsA = @{shift @_};
    my @srcDir = @{shift @_};
    my $destDir = shift @_;
    my $all = shift @_;
    my $recurse = shift @_;
    my $dir;
    
    foreach $dir (@srcDir) {
        processDir($dir, $action, $patterns, $extensionsL , \@extensionsA, $destDir, $all, $recurse);
    }
    return 1;
}

sub processDir {
    my $cwd = shift @_;
    my $action = shift @_;
    my $patterns = shift @_;
    my $extensionsL = shift @_;
    my @extensionsA = @{shift @_};
    my $destDir = shift @_;
    my $all = shift @_;
    my $recurse = shift @_;
    my @files;
    my $file;
    my $dir;
    
    opendir($dir, $cwd) or Warn("Invalid directory: $cwd");
    
    while (defined($file = readdir($dir))) {
        if ($recurse and -d "$cwd/$file" and $file !~ /^\.{1,2}$/) {
            processDir("$cwd/$file", $action, $patterns, $extensionsL , \@extensionsA, $destDir, $all, $recurse);
        } elsif (-f "$cwd/$file") {
            if ($all) {
                &$action("$cwd/$file", "$destDir/$file");
            } else {
                if ($file =~ /$extensionsL$/) {
                    if (hasPattern("$cwd/$file", $patterns)) {
                        foreach (@{getFiles($file, \@extensionsA)}) {
                            &$action("$cwd/$_", "$destDir/$_");
                        }
                    }
                }
            }
        }
    }
    
    closedir $dir;
    return 1;
}

sub getFiles {
    my $file = shift @_;
    my @extensionsA = @{shift @_};
    my @files;
    my $basename;
    my $ext;
    
    if ($file =~ /([^\x2E\x2F\x5F]+)[_\.]/) {
        $basename = $1;
        foreach $ext (@extensionsA) {

            push @files, "$basename$ext";
        }
    }
    
    return \@files;
}

sub hasPattern {
    my $file = shift @_;
    my $pattern = shift @_;
    my $data;
    my $f;
    
    open($f, $file) or Warn("Invalid file: $file");
    read $f, $data, -s $file;
    close($f);
    
    if ($data =~ /$pattern/gms) {
        return 1;
    } else {
        return 0;
    }
}

sub processExtensions {
    my @extensions = @{shift @_};
    
    if (@extensions) {
        return addOr(\@extensions);
    }
    
    return 0;
}

sub processPatterns {
    my @patterns = @{shift @_};
    
    if (@patterns > 1) {
        return addOr(\@patterns);
    } elsif (@patterns == 1) {
        return pop @patterns;
    } else {
        return 0;
    }
}

sub addOr {
    my @array = @{shift @_};
    
    my $str = "(" . $array[0] . ")";
    
    for (my $i = 1; $i < @array; $i++) {
        $str .= "|(" . $array[0] . ")";
    }
    
    return $str;
}

sub processAction {
    my $action = shift @_;
    
    if (defined $action) {
        if ($action == $COPY) {
            return \&copyF;
        } elsif ($action == $MOVE) {
            return \&moveF;
        } elsif ($action == $DELETE) {
            return \&deleteF;
        } else {
            Error("Invalid action: $action");
        }
    }
    return 0;
}

sub moveF {
    my $from = shift @_;
    my $to = shift @_;
   
    move($from, $to);
    return 1;
}

sub deleteF {
    my $from = shift @_;
   
    unlink($from);
    return 1;
}

sub copyF {
    my $from = shift @_;
    my $to = shift @_;
   
    copy($from, $to);
    return 1;
}

sub processDirs {
    my @dirs = @{shift @_};
    
    my @dirList;
    my $dir;
    
    foreach $dir (@dirs) {
        if ($dir =~ /\*/) {
            push @dirList, @{processDirStar($dir)};
        } elsif ($dir =~ /^\.{1,2}/) {
            push @dirList, processDirDots($dir);
        } else {
            push @dirList, $dir;
        }
    }
    
    return \@dirList;
}

sub processDirStar {
    my $dir = shift @_;
    
    if ($dir =~ /\*/) {
        return \{glob($dir)};
    } else {
        return [$dir];
    }
}

sub processDirDots {
    my $dir = shift @_;
    
    my $lastPart;
    my $newDir;
    my $up = 0;
    
    if ($dir =~ /^\.\/(.+?)/) {
        $lastPart = $1;
        $newDir = getcwd() . "/$lastPart";
    } elsif ($dir =~ /^\.\.\/(.+)/) {
        $lastPart = $1;
        while ($dir =~ /\.\.(?:\/)/g) {
            $up++;
        }
        $newDir = getcwd();
        for (my $i = 0; $i < $up; $i++) {
            if ($newDir =~ /(.+)\/([^\/]+)$/) {
                $newDir = $1;
            } else {
                Warn("Invalid directory: $dir");
                $newDir = $dir;
                last;
            }
        }
        $newDir .= "/$lastPart";
    } else {
        $newDir = $dir;
    }
    
    return $newDir;
}

sub processDestDir {
    my $destDir = shift @{processDirs(\@_)};
    my $newDir;
    
    if ($destDir =~ /^[^\/]/) {
        $newDir = getcwd() . "/$destDir";
    } else {
        $newDir = $destDir;
    }
    
    return $newDir;
}
