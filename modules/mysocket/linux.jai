using #import "Socket";
MySocket :: struct { // used for function overloading, ex: listen(Socket, s32) vs listen(MySocket, s32)
  socket: s32;
}

sendfile :: (out_fd: s32, in_fd: s32, offset: *off_t, count: size_t) -> ssize_t #foreign libc;

send :: inline (fd: s32, msg: string) -> s64 {
    return send(fd, cast(*void) msg.data, cast(size_t) msg.count, 0);
}

// write :: inline (fd: s32, msg: string) -> s64 {
//     return write(fd, cast(*void) msg.data, cast(size_t) msg.count);
// }

// write :: inline (fd: s32, buf: string, args: ..Any) -> s64 {
//     tmp := tprint(buf, ..args);
//     return write(fd, tmp.data, cast(size_t) tmp.count);
// }

#scope_file
#import "POSIX";
libc :: #system_library "libc";
















// socklen_t :: u32;

// in_addr :: struct {
//     s_addr     : u32;
// }

// sockaddr_in :: struct {
//     sin_family : u16;     // Address family
//     sin_port   : u16;     // Port number
//     sin_addr   : in_addr; // IP address
//     sin_zero   : [8]u8;    // Pad to size of 'sockaddr'
// };

// to_string :: (addr: sockaddr_in) -> string {
//     // TODO: This is hacky ass shit.
//     a := cast(u8) (addr.sin_addr.s_addr >> 0) & 0xff;
//     b := cast(u8) (addr.sin_addr.s_addr >> 8) & 0xff;
//     c := cast(u8) (addr.sin_addr.s_addr >> 16) & 0xff;
//     d := cast(u8) (addr.sin_addr.s_addr >> 24) & 0xff;
//     return tprint("%.%.%.%:%", a, b, c, d, addr.sin_port);
// }

// hostent :: struct {
//     h_name      : []u8;       /* official name of host */
//     h_aliases   : *[]u8;      /* alias list */
//     h_addrtype  : int;        /* host address type */
//     h_length    : int;        /* length of address */
//     h_addr_list : *[]u8;      /* list of addresses */
// }

// addrinfo :: struct {
//     ai_flags    : int;
//     ai_family   : int;
//     ai_socktype : int;
//     ai_protocol : int;
//     ai_addrlen  : socklen_t;
//     ai_addr     : *sockaddr;
//     ai_canonname: *u8;
//     ai_next     : *addrinfo;
// };

// setsockopt :: (socket: s32, level: s32, option_name: s32, option_value: *void, option_len: socklen_t) -> s32 #foreign libc "setsockopt";
// listen :: (sockfd: s32, backlog: int) -> s32 #foreign libc;
// connect :: (sockfd: s32, addr: *sockaddr, addrlen: *socklen_t) -> s32 #foreign libc;
// accept :: (sockfd: s32, addr: *sockaddr, addrlen: *socklen_t) -> s32 #foreign libc "accept";
// bind :: (sockfd: s32, addr: *sockaddr, addrlen: socklen_t) -> s32 #foreign libc;
// getsockname :: (sockfd: s32, addr: *sockaddr, addrlen: *socklen_t) -> s32 #foreign libc;

// fileno :: (file: *FILE) -> s32 #foreign libc; // this shouldn't be here
// sendfile :: (out_fd: s32, in_fd: s32, offset: *off_t, count: size_t) -> ssize_t #foreign libc;

// recv :: (fd: s32, buf: *u8, len: size_t, flags: s32) -> ssize_t #foreign libc;

// write :: inline (fd: s32, msg: string) -> s64 {
//     return write(fd, cast(*void) msg.data, cast(size_t) msg.count);
// }

// write :: inline (fd: s32, buf: string, args: ..Any) -> s64 {
//     tmp := tprint(buf, ..args);
//     return write(fd, tmp.data, cast(size_t) tmp.count);
// }


// accept :: (sockfd: s32, client: *sockaddr) -> s32 {
//     clientlen : u32 = size_of(sockaddr);
//     return accept(sockfd, client, *clientlen);
// }

// accept :: (sockfd: s32) -> s32, sockaddr_in {
//     addr : sockaddr_in;
//     addrlen : u32 = size_of(sockaddr);
//     fd := accept(sockfd, cast(*sockaddr)*addr, *addrlen);
//     return fd, addr;
// }

// bind :: (socket : s32, address: string, port: u16, family: u16 = AF_INET) -> s32 {
//     server_address : sockaddr_in;
//     server_address.sin_family = family;
//     // TODO: Eliminate inet_addr() call.
//     addr := to_c_string(address);
//     server_address.sin_addr = inet_addr(addr);
//     server_address.sin_port = htons(port);
//     free(addr);
//     return bind(socket, cast(*sockaddr)*server_address, size_of(sockaddr_in));
// }

// bind :: (socket : s32, address: u32, port: u16, family: u16 = AF_INET) -> s32 {
//     server_address : sockaddr_in;
//     server_address.sin_family = family;
//     server_address.sin_addr.s_addr = htonl(address);
//     server_address.sin_port = htons(port);
//     return bind(socket, cast(*sockaddr)*server_address, size_of(sockaddr_in));
// }


// // This is obsolete though
// gethostbyaddr :: (addr: *void, len: socklen_t, type: int) -> *hostent #foreign libc;

// getaddrinfo :: (node: []u8, service: []u8, hints: *addrinfo, res: **addrinfo) -> s32 #foreign libc;


// htonl :: (hostlong : u32) -> u32 #foreign libc;
// htons :: (hostshort : u16) -> u16 #foreign libc;
// ntohl :: (netlong : u32) -> u32 #foreign libc;
// ntohs :: (netshort : u16) -> u16 #foreign libc;

// inet_aton :: (cp : *u8, inp : *in_addr) -> s32 #foreign libc;
// inet_addr :: (cp : *u8) -> in_addr #foreign libc;
// inet_network :: (cp : *u8) -> in_addr #foreign libc;
// inet_ntoa :: (in : in_addr) -> *u8 #foreign libc;
// inet_makeaddr :: (net : int, host : int) -> in_addr #foreign libc;
// inet_lnaof :: (in : in_addr) -> in_addr #foreign libc;
// inet_netof :: (in : in_addr) -> in_addr #foreign libc;

// // Maximum queue length specifiable by listen.
// SOMAXCONN :: 128;

// // Flags we can use with send/ and recv.
// // Added those for 1003.1g not all are supported yet
// MSG_OOB                 :: 1;
// MSG_PEEK                :: 2;
// MSG_DONTROUTE           :: 4;
// MSG_TRYHARD             :: 4; // Synonym for MSG_DONTROUTE for DECnet
// MSG_CTRUNC              :: 8;
// MSG_PROBE               :: 0x10; // Do not send. Only probe path f.e. for MTU
// MSG_TRUNC               :: 0x20;
// MSG_DONTWAIT            :: 0x40; // Nonblocking io
// MSG_EOR                 :: 0x80; // End of record
// MSG_WAITALL             :: 0x100; // Wait for a full request
// MSG_FIN                 :: 0x200;
// MSG_SYN                 :: 0x400;
// MSG_CONFIRM             :: 0x800; // Confirm path validity
// MSG_RST                 :: 0x1000;
// MSG_ERRQUEUE            :: 0x2000; // Fetch message from error queue
// MSG_NOSIGNAL            :: 0x4000; // Do not generate SIGPIPE
// MSG_MORE                :: 0x8000; // Sender will send more
// MSG_WAITFORONE          :: 0x10000; // recvmmsg(): block until 1+ packets avail
// MSG_SENDPAGE_NOPOLICY   :: 0x10000; // sendpage() internal : do no apply policy
// MSG_SENDPAGE_NOTLAST    :: 0x20000; // sendpage() internal : not the last page
// MSG_BATCH               :: 0x40000; // sendmmsg(): more messages coming
// MSG_EOF                 :: MSG_FIN;
// MSG_NO_SHARED_FRAGS     :: 0x80000; // sendpage() internal : page frags are not shared
// MSG_SENDPAGE_DECRYPTED  :: 0x100000; // sendpage() internal : page may carry
//                                     // plain text and require encryption
// MSG_ZEROCOPY            :: 0x4000000;  // Use user data in kernel path
// MSG_FASTOPEN            :: 0x20000000; // Send data in TCP SYN
// MSG_CMSG_CLOEXEC        :: 0x40000000; /* Set close_on_exec for file
//                                          descriptor received through
//                                          SCM_RIGHTS */

// // TODO: Not sure what to do with this defintion
// // #if defined(CONFIG_COMPAT)
// //MSG_CMSG_COMPAT :: 0x80000000; // This message needs 32; bit fixups
// //#else
// //MSG_CMSG_COMPAT :: 0;          // We never have 32; bit fixups
// //#endif


// /* Setsockoptions(2) level. Thanks to BSD these must match IPPROTO_xxx */
// SOL_IP                   :: 0;
// /* SOL_ICMP :: 1;       No-no-no! Due to Linux :-) we cannot use SOL_ICMP=1; */
// SOL_TCP                  :: 6;
// SOL_UDP                  :: 17;
// SOL_IPV6                 :: 41;
// SOL_ICMPV6               :: 58;
// SOL_SCTP                 :: 132;
// SOL_UDPLITE              :: 136;     /* UDP-Lite (RFC 3828) */
// SOL_RAW                  :: 255;
// SOL_IPX                  :: 256;
// SOL_AX25                 :: 257;
// SOL_ATALK                :: 258;
// SOL_NETROM               :: 259;
// SOL_ROSE                 :: 260;
// SOL_DECNET               :: 261;
// SOL_X25                  :: 262;
// SOL_PACKET               :: 263;
// SOL_ATM                  :: 264;     /* ATM layer (cell level) */
// SOL_AAL                  :: 265;     /* ATM Adaption Layer (packet level) */
// SOL_IRDA                 :: 266;
// SOL_NETBEUI              :: 267;
// SOL_LLC                  :: 268;
// SOL_DCCP                 :: 269;
// SOL_NETLINK              :: 270;
// SOL_TIPC                 :: 271;
// SOL_RXRPC                :: 272;
// SOL_PPPOL2TP             :: 273;
// SOL_BLUETOOTH            :: 274;
// SOL_PNPIPE               :: 275;
// SOL_RDS                  :: 276;
// SOL_IUCV                 :: 277;
// SOL_CAIF                 :: 278;
// SOL_ALG                  :: 279;
// SOL_NFC                  :: 280;
// SOL_KCM                  :: 281;
// SOL_TLS                  :: 282;
// SOL_XDP                  :: 283;

// SOL_SOCKET               :: 0x1;

// // IPX options
// IPX_TYPE                 :: 1;


// /*
//  * Option flags per-socket.
//  */
// SO_DEBUG                  :: 0x0001;		/* turn on debugging info recording */
// SO_ACCEPTCONN             :: 0x0002;		/* socket has had listen() */
// SO_REUSEADDR              :: 0x0002;		/* allow local address reuse */
// SO_KEEPALIVE              :: 0x0008;		/* keep connections alive */
// SO_DONTROUTE              :: 0x0010;		/* just use interface addresses */
// SO_BROADCAST              :: 0x0020;		/* permit sending of broadcast msgs */
// SO_USELOOPBACK            :: 0x0040;		/* bypass hardware when possible */
// SO_LINGER                 :: 0x0080;		/* linger on close if data present */
// SO_OOBINLINE              :: 0x0100;		/* leave received OOB data in line */

// /*
//  * Additional options, not kept in so_options.
//  */
// SO_SNDBUF                 :: 0x1001;		/* send buffer size */
// SO_RCVBUF                 :: 0x1002;		/* receive buffer size */
// SO_SNDLOWAT               :: 0x1003;		/* send low-water mark */
// SO_RCVLOWAT               :: 0x1004;		/* receive low-water mark */
// SO_SNDTIMEO               :: 0x1005;		/* send timeout */
// SO_RCVTIMEO               :: 0x1006;		/* receive timeout */
// SO_ERROR                  :: 0x1007;		/* get error status and clear */
// SO_TYPE                   :: 0x1008;		/* get socket type */


// #scope_file

// #import "Basic";
// #import "POSIX";
// libc :: #system_library "libc";
