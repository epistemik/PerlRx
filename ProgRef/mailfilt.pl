#!/usr/local/bin/perl5

use Net::SMTP;
use strict;

my (%mailheader,@message,@mailbody,$keyword,
    $value,$field,$error);
my ($filtscript);
my ($user) = $ENV{'USER'} || $ENV{'LOGNAME'} || 
             getlogin || (getpwuid($>))[0];
my ($homedir) = (getpwnam($user))[7];

close(STDERR);
close(STDOUT);
my $state=1;

while(<STDIN>)
{
    chomp;
    push @message,$_;
    if (length($_) eq 0)
    {
        $state=0;
        next;
    }
    if ($state)
    {
        if ( m/^From\s/)
        {
            next;
        }
        elsif ( m/(^[\w\-\.]+):\s*(.*\S)\s*$/)
        {
            $keyword = lc($1);
            $value = $2;
            $mailheader{$keyword} = $value;
        }
        else
        {
            $mailheader{$keyword} .= "\n" . $_;
        }
    }
    else
    {
        push @mailbody,$_;
    }
}
close(STDIN);

$filtscript = read_parse_script("$homedir/.mailfilt.cfg");

eval $filtscript;

if ($@)
{
    write_local_mail(join("\n",@message));
    write_local_error($@);
}

sub read_parse_script
{
    my($file) = @_;
    my $permissions = (stat($file))[2];
    
    unless ($permissions & 00600)
    {
        write_local_error("Bad permissions on config file $file");
        return(undef);
    }
    unless(open(D,"<$file"))
    {
        write_local_error("Can't open config $file, $!");
        return(undef);
    }
    {
        local $/;
        $file=<D>;
    }
    close(D) 
        || write_local_error("Can't close config $file, $!");
    $file;
}

sub write_local_error
{
    my ($error) = @_;

    my $message  = "To: $user\n";
    $message .= "From: Mailfilter (local program) <$user>\n";
    $message .= "Subject: Mail Filter Error\n\n";
    $message .= "$error\n";
    write_local_mail($message);
}

sub write_local_mail
{
    my ($message) = @_;
    my ($sec,$min,$hour,$mday,$mon) = (localtime(time))[0-4];
    my $tempfile = "/tmp/ml.$user.$mday$mon$hour$min$sec.$$";
    open(T,">$tempfile") || die "Cant open temp file,$!";
    print T $message,"\n";
    close(T);
    system('/bin/rmail -d $user < $tempfile');
    unlink("/tmp/ml.$$");
}

sub forward_mail
{
    my ($to) = @_;
    $mailheader{to} = $mailheader{'apparently-to'} 
                      unless $mailheader{to};
    my $subject = $mailheader{subject} ? 
        "FWD: $mailheader{subject}" : "FWD: <no subject>";


    unless(mail_a_message($subject,$to,
                          clean_address($mailheader{to}),
                          join("\n",@message)))
    {
        write_local_mail(join("\n",@message));
        write_local_error("Forwarding mail, $SMTPwrap::error");
    }
}

sub anonymous_forward
{
    my ($toaddress) = @_;
    my $message;
    my @fields = qw(Date From Reply-To Organization 
                    X-Mailer Mime-Version Subject 
                    Content-Type Content-Transfer-Encoding);

    foreach $field (@fields)
    {
        $message .= "$field: " . $mailheader{$field} 
                 . "\n" if defined($mailheader{$field});
    }

    $message .= "\n";
    $message .= join("\n",@mailbody);
    $message .= "\n";

    unless(send_smtp($toaddress,$mailheader{from},$message))
    {
        write_local_mail(join("\n",@message));
        write_local_error("Anonymous Forward, $SMTPwrap::error");
    }
}

sub send_smtp
{
    my ($to,$from,$message) = @_;
    my $smtp = Net::SMTP->new('mail');
    unless($smtp)
    {
        $error = "Couldn't open connection to mail server";
        return 0;
    }
    unless($smtp->mail($from))
    {
        $error = "Bad 'From' address specified";
        return 0;
    }
    unless($smtp->to($to))
    {
        $error = "Bad 'To' address specified";
        return 0;
    }
    unless($smtp->data())
    {
        $error = "Not ready to accept data";
        return 0;
    }
    $smtp->datasend($message);
    unless($smtp->dataend())
    {
        $error = "Bad response when sending data";
        return 0;
    }
    unless($smtp->quit())
    {
        $error = "Error closing SMTP connection";
        return 0;
    }
    1;
}

sub mail_a_message
{
    my ($subject,$to,$from,$message) = @_;
    my ($newmessage);

    $newmessage .= "To: $to\n";
    $newmessage .= "From: $from\n";
    $newmessage .= "Subject: $subject\n";
    $newmessage .= "\n" . $message;
    
    send_smtp($to,$from,$newmessage);
}

sub return_address
{
    my ($hash) = shift;

    $$hash{'reply-to'} || $$hash{'from'} ||
        $$hash{'return-path'} || $$hash{'apparently-from'};
}

sub clean_address
{
    local($_) = @_;
    s/\s*\(.*\)\s*//;
    1 while s/.*<(.*)>.*/$1/;
    s/^\s*(.*\S)\s*$/$1/;
    $_;
}

1;
