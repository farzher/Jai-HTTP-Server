// TODO: make it so the server doesn't crash under high concurrency
// wrk --latency -t6 -c10000 -d1 http://localhost/bench
// BACKLOG needs to be tweaked, and the way the request_pool works? not sure what's crashing us

BACKLOG               :: 1024;
MAX_EVENTS            :: BACKLOG;
REQUEST_BUFFER_LEN    :: 1024 * 2;

CORE_COUNT            :: #run -> int {
  #import "System";
  thread_count := get_number_of_processors();
  mylog("get_number_of_processors() =", thread_count);
  core_count := max(1, get_number_of_processors() / 2);
  mylog("setting CORE_COUNT (and THREAD_POOL_COUNT) to", core_count);
  return core_count;
}

// performance is signifigantly worse when we don't divide num processors by 2!
// 8700k (6 cores, 12 threads)
// wrk --latency -t6 -c100 -d10 http://localhost
// THREAD_POOL_COUNT :: #run get_number_of_processors()      # Req/Sec    52.76k
// THREAD_POOL_COUNT :: #run get_number_of_processors() / 2  # Req/Sec    81.54k
THREAD_POOL_COUNT     :: CORE_COUNT;

thread_pool           : [THREAD_POOL_COUNT] Thread;
epoll_fd_pool         : [THREAD_POOL_COUNT] s32;
epoll_events_pool     : [THREAD_POOL_COUNT] [MAX_EVENTS] epoll_event;

request_pool          : Table(Socket, Request);


listen_socket: Socket;
listen_called: bool;
http_listen :: (port: u16 = 80, ip: string = "0.0.0.0") {
  assert(!listen_called, "cannot call listen multiple times");
  listen_called = true;

  listen_socket = create_listen_socket(port, ip);
  log("HTTP Server listening on %:%", ip, port);

  // request_pool init
  // without this our code actually crashes when there's high concurrency!
  // Array bounds check failed
  // i think while this table is expanding in 1 thread it's being accessed out of bounds in another thread?
  init(*request_pool, BACKLOG+3); // why +3?

  // spin up the thread pool
  for * thread, i: thread_pool {
    epoll_fd_pool[i] = epoll_create1(0);
    if epoll_fd_pool[i] < 0  die("epoll_create1(0)");
    add_to_epoll_fd_list(epoll_fd_pool[i], listen_socket, null, EPOLLIN | EPOLLET /*| EPOLLONESHOT*/);

    thread.data = xx i;
    thread_init(thread, thread_pool_proc);
    thread_start(thread);
  }
}

listen_socket_ssl: Socket;
listen_called_ssl: bool;
https_listen :: (port: u16 = 443, ip: string = "0.0.0.0", certificate: string = "", privatekey: string = "") {
  assert(listen_called, "http_listen must be called first for now. because it does setup stuff that i'm lazy to deal with");
  assert(!listen_called_ssl, "cannot call listen multiple times");
  listen_called_ssl = true;

  ssl_init(certificate=certificate, privatekey=privatekey);

  listen_socket_ssl = create_listen_socket(port, ip);
  log("HTTPS Server listening on %:%", ip, port);

  for * thread, i: thread_pool {
    add_to_epoll_fd_list(epoll_fd_pool[i], listen_socket_ssl, null, EPOLLIN | EPOLLET /*| EPOLLONESHOT*/);
  }
}

create_listen_socket :: (port: u16, ip: string) -> Socket {
  listen_socket := socket(AF_INET, SOCK.SOCK_STREAM | .SOCK_NONBLOCK, 0);
  if listen_socket < 0  die("listen socket()");

  setnonblocking(listen_socket);
  setsockopt(listen_socket, SO_REUSEADDR);
  setsocktcpopt(listen_socket, TCP_NODELAY);

  listen_addr: sockaddr_in;
  listen_addr.sin_family = AF_INET;
  listen_addr.sin_addr.s_addr = inet_addr(to_c_string(ip));
  listen_addr.sin_port = htons(port);
  if bind(listen_socket, cast(*sockaddr)*listen_addr, size_of(type_of(listen_addr))) < 0 {
    die("listen bind()", errno());
  }
  if listen(listen_socket, BACKLOG) < 0  die("listen listen()");

  return listen_socket;
}


thread_pool_proc :: (thread: *Thread) -> s64 {
  ts: Temporary_Storage; context.temporary_storage = *ts;
  thread_id := cast(s32)thread.data;
  epoll_fd := epoll_fd_pool[thread_id];

  client_addr: sockaddr_in;
  client_addr_len: socklen_t = size_of(type_of(client_addr));

  // poll forever
  while 1 {
    epoll_ret := epoll_wait(epoll_fd, xx *epoll_events_pool[thread_id], MAX_EVENTS, -1);
    if epoll_ret < 0  die("epoll_wait()");

    for i: 0 .. epoll_ret-1 {
      event := epoll_events_pool[thread_id][i];
      // mylog("fd:", event.data.fd, "ev:", event.events);
      if event.events == 0 continue; // not sure why this is here, but it is called sometimes
      if event.data.fd <= 2 continue; // are these stdin, out, and err? why are they here

      // received a new event on the listen_socket. this means a client is ready to be accepted
      if event.data.fd == listen_socket || event.data.fd == listen_socket_ssl {
        the_listen_socket := event.data.fd;
        while 1 {
          client_socket := accept(the_listen_socket, cast(*sockaddr)*client_addr, *client_addr_len);

          if client_socket < 0 then break;

          setnonblocking(client_socket);
          setsocktcpopt(client_socket, TCP_NODELAY); // @crash setsocktcpopt err: 9 socket: 190 option: 1 val: 1
          add_to_epoll_fd_list(epoll_fd, client_socket, null, EPOLLIN/* | EPOLLET | EPOLLONESHOT*/);

          if event.data.fd == listen_socket_ssl then ssl_make_socket_ssl(client_socket);

          new_request_from_pool(client_socket);
          handle_client_socket_accepted_or_read_ready(client_socket, epoll_fd);
        }

        continue;
      }

      // not the listen socket, must be a client_socket ready to read or write ... right?
      if event.events & EPOLLIN {
        client_socket := event.data.fd;
        handle_client_socket_accepted_or_read_ready(client_socket, epoll_fd);
        // add_to_epoll_fd_list(epoll_fd, client_socket, null, EPOLLIN | EPOLLET | EPOLLONESHOT, mod=true);
        continue;
      }

      if event.events & EPOLLOUT {
        client_socket := event.data.fd;
        request := table_find_pointer(*request_pool, client_socket);
        if !request || !request.write_data continue;
        continue_write(request);
        continue;
      }
    }

    tfree();
  }

  return 0;
}

make_mysocket :: (socket: Socket) -> MySocket {
  mysocket: MySocket;
  mysocket.socket = socket;
  return mysocket;
}

new_request_from_pool :: (client_socket: Socket) -> *Request {
  request: *Request = find_or_add(*request_pool, client_socket);
  request.content_length = 0;
  request.body.data      = null;
  request.response_sent  = false;
  request.err            = false;
  request.socket         = make_mysocket(client_socket);
  request.buffercursor   = 0;
  request.startofline    = 0;

  request.websocket_key.data = null;
  request.websocket_key.count = 0;

  if !request.raw.data {
    request.raw = alloc_string(REQUEST_BUFFER_LEN);
  }
  request.raw.count = 0;

  #if parseheaders table_reset(*request.headers);

  return request;
}

handle_client_socket_accepted_or_read_ready :: (client_socket: Socket, epoll_fd: s32) {
  while 1 {

    // if this socket is a websocket, not a request
    ws := table_find_pointer(*all_websockets, client_socket);
    if ws {
      websocket_read_frame(ws);
      return;
    }


    request := read_http_request(client_socket);
    if request == null  return; // we're waiting to read, need to come back later
    if request.err {
      // ssl has a massive memory leak when run with high concurrency... this doesn't fix it...
      ssl_delete(client_socket); // i thik this is memory leaking the ssl pointers

      close(client_socket);
      return;
    }

    request.epoll_fd = epoll_fd;
    handle_request(request);

    new_request_from_pool(client_socket); // reset this requests data when we're done with it
  }
}


// todo: i think i have to rewrite this to handle read() not giving us a full line
// this is slowwwwww. maybe i should use faster string compares
read_http_request :: (socket: Socket) -> *Request {
  request: *Request = table_find_pointer(*request_pool, socket);
  if request == null then die("no request for socket", socket);
  // assert(request != null);

  while 1 {
    bytes_received := mysocket_read(request.socket, request.raw.data + request.raw.count, xx(REQUEST_BUFFER_LEN - request.raw.count));

    if bytes_received < 0 && errno() == EWOULDBLOCK  return null;
    if bytes_received == 0 {
      if request.raw.count == REQUEST_BUFFER_LEN {
        mylog("pretty sure this means we ran out of buffer space for this request so we had to drop it!");
        send_text(request, tprint("Request too large. Max request size is % bytes.", REQUEST_BUFFER_LEN), status_code=413);
      }
      request.err = true;
      break;
    }
    if bytes_received < 0  { request.err = true; break; }


    request.raw.count += bytes_received;

    if request.body.data then request.body.count += bytes_received;


    bytes_read_this_chunk := 0;
    while request.body.data == null && request.buffercursor < request.raw.count - 1 {
      defer request.buffercursor+=1;
      defer bytes_read_this_chunk+=1;

      if request.raw[request.buffercursor] == #char "\r" && request.raw[request.buffercursor + 1] == #char "\n" {
        defer request.startofline = request.buffercursor + 2;

        line: string = ---;
        line.data = request.raw.data + request.startofline;
        line.count = request.buffercursor - request.startofline;

        if request.startofline == 0 {
          http_request_info := split(line, " ");
          request.method = to_METHOD(http_request_info[0]);
          request.path = http_request_info[1];
          // request.http_version = http_request_info[2];
          continue;
        }

        kv := split(line, ": ");
        #if parseheaders table_add(*request.headers, kv[0], kv[1]);

        if kv[0] == {
          case "Content-Length";    request.content_length   = xx to_integer(kv[1]);
          case "Sec-WebSocket-Key"; request.websocket_key    = kv[1];
          case "Accept-Encoding";   request.accept_encoding  = kv[1];
        }

        if request.raw[request.buffercursor+2] == #char "\r" && request.raw[request.buffercursor+2 + 1] == #char "\n" {
          // double newline, start of body
          request.body.data = request.raw.data + request.buffercursor+4;
          request.body.count = bytes_received - bytes_read_this_chunk - 4;
          break;
        }
      }
    }

    if request.body.data && request.body.count == request.content_length then break;
  }

  return request;
}


continue_write :: (request: *Request) {
  while request.write_bytes_sent < request.write_data.count {
    remaining_bytes_to_write := substr(request.write_data, request.write_bytes_sent);
    bytes_written := mysocket_write(request.socket, remaining_bytes_to_write);

    if bytes_written < 0 {
      if errno() == EWOULDBLOCK {
        add_to_epoll_fd_list(request.epoll_fd, request.socket.socket, null, EPOLLOUT, mod=true);
        return;
      }
      mylog("well, this is really bad: Error writing to socket: %", errno());
      return;
    }

    request.write_bytes_sent += bytes_written;
  }

  free(request.write_data.data); request.write_data.data = null;
  add_to_epoll_fd_list(request.epoll_fd, request.socket.socket, null, EPOLLIN, mod=true); // Reset the socket to listen for reads
}


// // todo: async? caching?
// send_file :: (request: *Request, filename: string) {

//   fd := open(to_c_string(filename), O_RDONLY);
//   if fd == -1 return;
//   defer close(fd);

//   stats: stat_t;
//   fstat(fd, *stats);
//   if S_ISDIR(stats.st_mode) {
//     send_file(request, tprint("%/index.html", filename));
//     return;
//   }
//   if !S_ISREG(stats.st_mode) return; // this is not a regular file! (probably a folder), don't sendfile it
//   length := stats.st_size;

//   content_type := extension2contenttype(filename);
//   http_response_headers := tprint("HTTP/1.1 200 OK\r\nConnection: Keep-Alive\r\nContent-Length: %\r\nContent-Type: %; charset=UTF-8\r\nServer: Jai\r\n\r\n", length, content_type);
//   send(request.socket, http_response_headers);
//   sendfile(request.socket, fd, null, xx stats.st_size);

//   request.response_sent = true;
// }





setsockopt :: (socket: s32, option: s32, optval: s32 = 1) {
  if setsockopt(socket, SOL_SOCKET, option, *optval, size_of(type_of(optval))) < 0 {
    die("setsockopt err:", errno(), "socket:", socket, "option:", option, "val:", optval);
  }
}
setsocktcpopt :: (socket: s32, option: s32, optval: s32 = 1) {
  if setsockopt(socket, xx IPPROTO.TCP, option, *optval, size_of(type_of(optval))) < 0 {
    die("setsocktcpopt err:", errno(), "socket:", socket, "option:", option, "val:", optval);
  }
}
setnonblocking :: (fd: s32) {
  old_option := fcntl(fd, F_GETFL);
  new_option := old_option | O_NONBLOCK;
  fcntl(fd, F_SETFL, new_option);
}

add_to_epoll_fd_list :: (epoll_fd: s32, fd: s32, ptr: *void, ep_events: u32, $mod: bool = false) {
  // mylog("adding to epoll list", fd);
  event: epoll_event;
  if ptr event.data.ptr = ptr;
  else   event.data.fd = fd;
  event.events = ep_events;

  #if !mod if epoll_ctl(epoll_fd, .ADD, fd, *event)  die("add epoll_ctl() ADD");
  #if  mod if epoll_ctl(epoll_fd, .MOD, fd, *event)  die("add epoll_ctl() MOD");
}
// remove_from_epoll_fd_list :: (fd: s32) {
//   if epoll_ctl(epoll_fd, EPOLL_CTL_DEL, fd, null)  die("remove epoll_ctl()");
// }




get_sockaddr_in_from_socket :: (socket: s32) -> sockaddr_in {
  addr_in: sockaddr_in;
  sizeof_sockaddr_in : u32 = size_of(type_of(addr_in));
  getpeername(socket, cast(*sockaddr)*addr_in, *sizeof_sockaddr_in);
  return addr_in;
}
get_ip_string_from_socket :: (socket: s32) -> string {
  addr_in := get_sockaddr_in_from_socket(socket);

  INET_ADDRSTRLEN :: 16;
  cstr := talloc(INET_ADDRSTRLEN);
  inet_ntop(AF_INET, *addr_in.sin_addr.s_addr, cstr, INET_ADDRSTRLEN);
  return fromcstr(cstr);
}





#import,dir "modules/openssl";
#import,dir "modules/mybasic";
#import,dir "modules/mysocket";

#import "POSIX";
#import "Linux";
#import "File";
#import "Thread";

TCP_NODELAY    :: 1;
SO_KEEPALIVE   :: 0x0008;
