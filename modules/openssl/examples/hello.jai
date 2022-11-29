












main :: () {
  ssl_init(certificate="localhost.crt", privatekey="localhost.key");


  sockfd: s32;
  newsockfd: s32;

  sockfd = socket(AF_INET, .SOCK_STREAM, 0);
  setsockopt(sockfd, SO_REUSEADDR);
  if (sockfd < 0) die("sock err");

  ip := "0.0.0.0";
  port :u16= 1337;
  listen_addr: sockaddr_in;
  listen_addr.sin_family = AF_INET;
  listen_addr.sin_addr.s_addr = inet_addr(to_c_string(ip));
  listen_addr.sin_port = htons(port);

  if bind(sockfd, cast(*sockaddr)*listen_addr, size_of(type_of(listen_addr))) < 0 {
    die("listen bind()", posix.errno());
  }

  if listen(sockfd, 5) < 0  die("listen listen()");

  client_addr: sockaddr_in;
  client_addr_len: socklen_t = size_of(type_of(client_addr));
  newsockfd = accept(sockfd, cast(*sockaddr)*client_addr, *client_addr_len);
  ssl_make_socket_ssl(newsockfd);

  buffer := talloc_string(1000);
  bytes_read := ssl_read(newsockfd, buffer.data, xx buffer.count);
  mylog("bytes_read", bytes_read);
  buffer.count = bytes_read;
  mylog(buffer);
  // SSL_write(ssl, "Hi :3\n", 6);

  mylog("we didn't crash");
}

#import "Socket";
posix :: #import "POSIX";
#import,dir "../../mybasic";
#import,dir "../";


setsockopt :: (socket: s32, option: s32, optval: s32 = 1) {
  if setsockopt(socket, SOL_SOCKET, option, *optval, size_of(type_of(optval))) < 0 {
    die("setsockopt err:", posix.errno(), "socket:", socket, "option:", option, "val:", optval);
  }
}







