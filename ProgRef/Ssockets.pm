package Ssockets;

require Exporter;
@ISA = 'Exporter';
@EXPORT = qw (connectsocket listensocket);

use Socket;

use vars qw($error);

sub connectsocket 
{
    my ($SOCKETHANDLE, $remotehost_name, 
        $service_name, $protocol_name) = @_;
    my ($port_num, $sock_type);
    my ($protocol_num);
    my ($remote_ip_addr, $remote_socket);
    
    $protocol_num = getprotobyname($protocol_name);
    unless ($protocol_num)
    {
        $error = "Couldn't find protocol $protocol_name";
        return;
    }
    $sock_type =  $protocol_name eq 'tcp' 
        ? SOCK_STREAM : SOCK_DGRAM;
    
    unless (socket($SOCKETHANDLE, PF_INET, 
                   $sock_type, $protocol_num))
    {
        $error = "Couldn't create a socket, $!";
        return;
    }
    
    if ($service_name =~ /^\d+$/ ) 
    { 
        $port_num = $service_name;
    } 
    else 
    {
        $port_num = (getservbyname($service_name, 
                                     $protocol_name))[2];
        unless($port_num)
        {
            $error = "Can't find service $service_name";
            return;
        }
    }
    
    $remote_ip_addr = gethostbyname($remotehost_name);
    unless ($remote_ip_addr)
    {
        $error 
            = "Can't resolve $remotehost_name to an IP address";
        return;
    }
    $remote_socket = sockaddr_in($port_num, $remote_ip_addr);
    unless(connect($SOCKETHANDLE, $remote_socket))
    {
        $error = 
            "Unable to connect to $remotehost_name: $!";
        return;
    }
    return(1);
}

sub listensocket
{
    my ($SOCKETHANDLE, $service_name, 
        $protocol_name, $queuelength) = @_;
    my ($port_num, $sock_type, $protocol_num,
        $local_socket);
    
    $protocol_num = (getprotobyname($protocol_name))[2];
    unless ($protocol_num)
    {
        $error = "Couldn't find protocol $protocol_name";
        return;
    }
    $sock_type = $protocol_name eq "tcp" 
        ? SOCK_STREAM : SOCK_DGRAM ;
    
    if( $service_name =~ /^\d+$/) 
    {
        $port_num = $service_name;
    } 
    else 
    {
        $port_num = (getservbyname($service_name, 
                                     $protocol_name))[2];
        unless($port_num)
        {
            $error = "Can't find service $service_name";
            return;
        }
    }
    
    unless(socket($SOCKETHANDLE, PF_INET, 
                  $sock_type, $protocol_num))
    {
        $error = "Couldn't create a socket: $!";
        return;
    }
    unless(setsockopt($SOCKETHANDLE,SOL_SOCKET,
                      SO_REUSEADDR,pack("l",1)))
    {
        $error = "Couldn't set socket options: $!";
        return;
    }
    $local_socket = sockaddr_in($port_num, INADDR_ANY);
    unless(bind($SOCKETHANDLE, $local_socket))
    {
        $error = "Failed to Bind to socket: $!";
        return;
    }
    unless(listen($SOCKETHANDLE, $queuelength))
    {
        $error = "Couldn't listen on socket: $!";
        return;
    }
    return(1);
}

1;

