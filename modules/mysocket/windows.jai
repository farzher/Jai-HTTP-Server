

#import "Socket";
MySocket :: struct { // used for function overloading, ex: listen(Socket, s32) vs listen(MySocket, s32)
  #as socket: SOCKET;
}


init :: () {
  wsa: WSADATA;
  if WSAStartup(WINSOCK_VERSION, *wsa) {
    mylog("WSAStartup Failed. Error Code:", WSAGetLastError());
  }
}
uninit :: () {WSACleanup(); }

socket :: ($overlaped := false) -> MySocket {
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
    s := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_IP, null, 0, WSA_FLAG_OVERLAPPED);
    if( s == INVALID_SOCKET ) {
      mylog("WSASocket(g_sdListen) failed: %\n", WSAGetLastError());
    }

    mysocket: MySocket;
    mysocket.socket = s;
    return mysocket;

    // info: addrinfo;
    // addrlocal: *addrinfo;

    // hints.ai_flags  = AI_PASSIVE;
    // hints.ai_family = AF_INET;
    // hints.ai_socktype = SOCK_STREAM;
    // hints.ai_protocol = IPPROTO_IP;

    // if( getaddrinfo(null, port, *hints, *addrlocal) != 0 ) {
    //   mylog("getaddrinfo() failed with error %\n", WSAGetLastError());
    // }

    // if( addrlocal == null ) {
    //   mylog("getaddrinfo() failed to resolve/convert the interface\n");
    // }

    // s := WSASocket(addrlocal.ai_family, addrlocal.ai_socktype, addrlocal.ai_protocol, null, 0, WSA_FLAG_OVERLAPPED);
    // if( s == INVALID_SOCKET ) {
    //   mylog("WSASocket(g_sdListen) failed: %\n", WSAGetLastError());
    // }
    // freeaddrinfo(addrlocal);

    // mysocket: MySocket;
    // mysocket.socket = s;
    // return mysocket;

    // // nZero = 0;
    // // nRet = setsockopt(g_sdListen, SOL_SOCKET, SO_SNDBUF, (char *)&nZero, sizeof(nZero));
    // // if( nRet == SOCKET_ERROR ) {
    // //   myprintf("setsockopt(SNDBUF) failed: %d\n", WSAGetLastError());
    // //   return(FALSE);
    // // }
  }
}
closesocket :: (s: MySocket) { closesocket(s.socket);}

bind :: (s: MySocket, ip: string, port: u16) {
  socketinfo: sockaddr_in;
  socketinfo.sin_family = AF_INET;
  // socketinfo.sin_addr = inet_addr(to_c_string(ip));
  socketinfo.sin_addr.S_un.S_addr = inet_addr(to_c_string(ip));
  // socketinfo.sin_addr.s_addr = xx inet_addr(to_c_string(ip));
  socketinfo.sin_port = htons(port);
  if bind(s.socket, cast(*sockaddr)*socketinfo, size_of(sockaddr_in)) < 0 {
    mylog("bind error", WSAGetLastError());
  }
}

listen :: (s: MySocket, backlog: s32) {
  if listen(s.socket, backlog) == SOCKET_ERROR {
    mylog("listen error", WSAGetLastError());
  }
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

recv :: (s: MySocket, buffer: *u8, bufferlen: s32) -> bytes_received: s32 {
  bytes_received := recv(s.socket, buffer, bufferlen, 0);
  if bytes_received < 0 then mylog("Recv failed with error:", WSAGetLastError(), "for socket:", s.socket);
  if bytes_received > bufferlen then mylog("recv error!, went past end of buffer");
  return bytes_received;
}






send :: (s: MySocket, msg: string) -> s32 {
  sent_byte_count := send(s.socket, msg.data, xx msg.count, 0);
  if sent_byte_count == SOCKET_ERROR {
    mylog("[TCP] Send failed with error:", WSAGetLastError());
  }
  return sent_byte_count;
}




#scope_file
// #import "../modules/winsock2";
#import "../modules/mybasic";















// MySocket :: struct { // used for function overloading, ex: listen(Socket, s32) vs listen(MySocket, s32)
//   socket: Socket;
//   response_buffer: [BUFFER_LENGTH]u8;
// }
// BUFFER_LENGTH :: 1024*8;
// // BUFFER_LENGTH :: 20*4;
// // response_buffer: [BUFFER_LENGTH]u8;
// Err :: enum u8 {NONE; CLOSED; ERR; }
// recv :: (s: MySocket) -> string, Err {
//   memset(s.response_buffer.data, 0, BUFFER_LENGTH);
//   str: string;
//   str.data = s.response_buffer.data;
//   while str.count==0 || str[str.count-1] < 32 {
//     result := recv(s.socket, s.response_buffer.data, BUFFER_LENGTH, 0);

//     if result == 0 then return str, .CLOSED;

//     if result < 0 {
//       mylog("[TCP] Recv failed with error:", WSAGetLastError());
//       return str, .ERR;
//     }

//     str.count += result;
//   }
//   return str, .NONE;
// }
// // recv :: (s: MySocket) -> string, Err {
// //   memset(s.response_buffer.data, 0, BUFFER_LENGTH);
// //   result := recv(s.socket, s.response_buffer.data, BUFFER_LENGTH, 0);

// //   if result == 0 {
// //     return "", .CLOSED;
// //   }

// //   if result < 0 {
// //     mylog("[TCP] Recv failed with error:", WSAGetLastError());
// //     return "", .ERR;
// //   }

// //   return to_string(s.response_buffer.data), .NONE;

// //   // str := to_string(s.response_buffer.data);
// //   // if str[str.count-1] < 32 {
// //   //   // i think we're not done reading this request?
// //   //   // wtf this code is so bad, what am i doing
// //   //   result := recv(s.socket, s.response_buffer.data+str.count, xx(BUFFER_LENGTH-str.count), 0);
// //   //   str = to_string(s.response_buffer.data);
// //   // }
// //   // return str, .NONE;
// // }
