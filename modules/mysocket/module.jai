using,except(MSG) #import "Socket";

// used for function overloading, ex: listen(Socket, s32) vs listen(MySocket, s32)
MySocket :: struct {#as socket: Socket; }

// socket_init
// socket_init
// socket_init
// socket_init
// socket_init
// socket_init
// socket_init
// socket_init
// socket_init
// socket_init

socket_uninit :: () {WSACleanup();}

socket_close :: (socket: Socket) {
  #if OS == .LINUX   close(socket);
  #if OS == .WINDOWS closesocket(socket);
}

#if OS == .LINUX {

  #import "POSIX";
  libc :: #system_library "libc";

  sendfile :: (out_fd: s32, in_fd: s32, offset: *off_t, count: size_t) -> ssize_t #foreign libc;

  send :: inline (fd: s32, msg: string) -> s64 {
      return send(fd, cast(*void) msg.data, cast(size_t) msg.count, 0);
  }

  recv :: (s: MySocket, buffer: *u8, bufferlen: u32) -> bytes_received: s64 {
    return recv(s.socket, buffer, bufferlen, 0);
  }
}

#if OS == .WINDOWS {
  socket_new :: ($overlaped := false) -> MySocket {
    #if !overlaped {
      s := socket(AF_INET, .SOCK_STREAM, 0);
      if s == INVALID_SOCKET {
        mylog("Could not create socket:", WSAGetLastError());
      }

      mysocket: MySocket;
      mysocket.socket = s;
      return mysocket;
    }

    #if overlaped {
      s := WSASocket(AF_INET, .SOCK_STREAM, IPPROTO_IP, null, 0, WSA_FLAG_OVERLAPPED);
      if( s == INVALID_SOCKET ) {
        mylog("WSASocket(g_sdListen) failed: %\n", WSAGetLastError());
      }

      mysocket: MySocket;
      mysocket.socket = s;
      return mysocket;
    }
  }


  bind :: (s: MySocket, ip: string, port: u16) {
    socketinfo: sockaddr_in;
    socketinfo.sin_family = AF_INET;
    // socketinfo.sin_addr = inet_addr(to_c_string(ip));
    socketinfo.sin_addr.S_un.S_addr = inet_addr(to_c_string(ip));
    // socketinfo.sin_addr.s_addr = xx inet_addr(to_c_string(ip));
    socketinfo.sin_port = htons(port);
    if bind(s.socket, cast(*sockaddr)*socketinfo, size_of(sockaddr_in)) < 0 {
      mylog("bind error", WSAGetLastError());
      mylog("port", port, "already in use (probably)");
      exit(1);
    }
  }

  send :: (s: MySocket, msg: string) -> s32 {
    sent_byte_count := send(s.socket, msg.data, xx msg.count, 0);
    if sent_byte_count == SOCKET_ERROR {
      mylog("[TCP] Send failed with error:", WSAGetLastError());
    }
    return sent_byte_count;
  }

  recv :: (s: MySocket, buffer: *u8, bufferlen: s32) -> bytes_received: s32 {
    bytes_received := recv(s.socket, buffer, bufferlen, 0);
    if bytes_received < 0 then mylog("Recv failed with error:", WSAGetLastError(), "for socket:", s.socket);
    if bytes_received > bufferlen then mylog("recv error!, went past end of buffer");
    return bytes_received;
  }

  accept :: (s: MySocket) -> MySocket {
    // client_socket := accept(s.socket, null, null);
    socketinfo: sockaddr_in;
    socketinfo_sizeof: s32 = size_of(sockaddr_in);
    client_socket := accept(s.socket, cast(*sockaddr)*socketinfo, *socketinfo_sizeof);
    if client_socket == INVALID_SOCKET {
      mylog("accept failed with error code:", WSAGetLastError());
    }
    // mylog(socketinfo);

    optval: s32 = 1;
    // optsize: s32 = size_of(type_of(optval));
    setsockopt(client_socket, SOL_SOCKET, SO_KEEPALIVE, xx *optval, size_of(type_of(optval)));
    // getsockopt(client_socket, SOL_SOCKET, SO_KEEPALIVE, xx *optval, *optsize);
    // mylog("yo", optval);

    tmp: MySocket;
    tmp.socket = client_socket;
    return tmp;
  }
}

#import,dir "../mybasic";
