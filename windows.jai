/* -farzher September 13, 2021
  http server using raw sockets

  i'm not sure exactly how tcp sockets are working here.
  it seems to reuse the same socket for some calls, but
  other times it'll close the socket and accept a new one

  known issues:
  1. the server requests a thread for every connection
     and if you have more connections than threads the new
     connections will get completely stuck while waiting
  2. todo using async polling apis instead of blocking api
*/

CONCURRENCY_ENUM :: enum u8 {THREAD_PER_REQUEST; THREAD_POOL; ASYNC;}
CONCURRENCY : CONCURRENCY_ENUM : .THREAD_PER_REQUEST;
#assert(CONCURRENCY != .ASYNC);




ListenThreadData   :: struct {ip:string; port:u16;};
listen_thread_data : ListenThreadData;
listen_thread      : Thread;
listen_called      : bool;
http_listen :: (ip: string = "0.0.0.0", port: u16 = 80) {
  listen_called = true;
  listen_thread_data.ip = ip;
  listen_thread_data.port = port;
  thread_init(*listen_thread, listen_thread_proc);
  thread_start(*listen_thread);
}

https_listen :: (port: u16 = 443, ip: string = "0.0.0.0", certificate: string = "", privatekey: string = "") {
  die("https_listen is not implement on windows");
}

#if CONCURRENCY == .THREAD_POOL {
  BACKLOG               :: 12;
  THREAD_POOL_COUNT     :: BACKLOG;
  connection_thread_pool: [THREAD_POOL_COUNT] Thread;
  connection_queue      : [..] MySocket;
  connection_queue_sema : Semaphore;
  connection_queue_lock : Mutex;
  work_add :: (work: MySocket) {
    lock(*connection_queue_lock);
    array_add(*connection_queue, work);
    unlock(*connection_queue_lock);
  }
  work_get :: () -> MySocket {
    lock(*connection_queue_lock);
    socket: MySocket = connection_queue[0];
    array_unordered_remove_by_index(*connection_queue, 0);
    unlock(*connection_queue_lock);
    return socket;
  }
} else {
  BACKLOG :: 1024;
}

listen_thread_proc :: (listen_thread: *Thread) -> s64 {
  ts: Temporary_Storage; context.temporary_storage = *ts;

  socket_init(); defer socket_uninit();

  listen_socket := socket_new();
  // listen_socket := socket_new(overlaped=true);
  defer closesocket(listen_socket);


  thread_data := listen_thread_data;

  bind(listen_socket, thread_data.ip, thread_data.port);
  listen(listen_socket, BACKLOG);
  ip_to_display := ifx thread_data.ip == "0.0.0.0" then "localhost" else thread_data.ip;
  log("HTTP Server listening on http://%:%", ip_to_display, thread_data.port);


  #if CONCURRENCY == .THREAD_POOL {
    array_reserve(*connection_queue, BACKLOG);
    init(*connection_queue_sema);
    init(*connection_queue_lock);
    for * thread: connection_thread_pool {
      thread_init(thread, thread_pool_proc);
      thread_start(thread);
    }
  }

  // iocp := CreateIoCompletionPort(INVALID_HANDLE_VALUE, null, 0, 0);

  while 1 {
    client_socket := accept(listen_socket);

    #if CONCURRENCY == .THREAD_POOL {
      work_add(client_socket);
      release(connection_queue_sema);
    } else if CONCURRENCY == .THREAD_PER_REQUEST {
      threads: [..]Thread; // leak
      thread: *Thread = array_add(*threads);
      thread.data = xx client_socket.socket;
      thread_init(thread, thread_request_proc);
      thread_start(thread);
    }

    tfree();
  }

  return 0;
}

thread_pool_proc :: (thread: *Thread) -> s64 {
  ts: Temporary_Storage; context.temporary_storage = *ts;

  while 1 {
    auto_release_temp();

    wait_for(*connection_queue_sema);
    client_socket := work_get();
    defer closesocket(client_socket);

    while 1 {
      auto_release_temp();

      request := recv_http_request(client_socket);
      if request.err then break;

      handle_request(*request);
    }
  }

  return 0;
}
thread_request_proc :: (thread: *Thread) -> s64 {
  ts: Temporary_Storage; context.temporary_storage = *ts;
  client_socket: MySocket;
  client_socket.socket = xx thread.data;
  defer closesocket(client_socket);

  while 1 {
    auto_release_temp();

    request := recv_http_request(client_socket);
    if request.err then break;

    handle_request(*request);
  }

  return 0;
}













recv_http_request :: (socket: MySocket) -> Request {
  request: Request;
  request.params.allocator = tallocator;

  request.socket         = socket;

  #if parseheaders request.headers.allocator = tallocator;
  #if parseheaders init(*request.headers);

  BUFFER_LEN :: 1024*10;
  request.raw.data = talloc(BUFFER_LEN);
  request.raw.count = 0;


  buffercursor := 0;
  startofline := 0;
  while 1 {
    bytes_received := recv(request.socket, request.raw.data + request.raw.count, xx(BUFFER_LEN - request.raw.count));

    if bytes_received == 0 { request.err = true; break; } // this maybe isn't an error? on connection that aren't keep-alive?
    if bytes_received < 0  { request.err = true; break; }

    // chunk: string;
    // chunk.data = request.raw.data + request.raw.count;
    // chunk.count = bytes_received;
    // mylog("chunk", chunk);

    if request.body.data then request.body.count += bytes_received;

    request.raw.count += bytes_received;
    bytes_read_this_chunk := 0;
    while request.body.data == null && buffercursor < request.raw.count - 1 { defer buffercursor+=1; defer bytes_read_this_chunk+=1;
      if request.raw[buffercursor] == #char "\r" && request.raw[buffercursor + 1] == #char "\n" {
        defer startofline = buffercursor + 2;

        line: string = ---;
        line.data = request.raw.data + startofline;
        line.count = buffercursor - startofline;

        if startofline == 0 {
          http_request_info := split(line, " ");
          request.method = to_METHOD(http_request_info[0]);
          request.path = http_request_info[1];
          // request.http_version = http_request_info[2];
          continue;
        }

        kv := split(line, ": ");
        #if parseheaders table_add(*request.headers, kv[0], kv[1]);

        if kv[0] == {
          case "Content-Length";    request.content_length = xx to_integer(kv[1]);
          case "Sec-WebSocket-Key"; request.websocket_key  = kv[1];
        }

        if request.raw[buffercursor+2] == #char "\r" && request.raw[buffercursor+2 + 1] == #char "\n" {
          // double newline, start of body
          request.body.data = request.raw.data + buffercursor+4;
          request.body.count = bytes_received - bytes_read_this_chunk - 4;
          break;
        }
      }
    }

    if request.body.data && request.body.count == request.content_length then break;
  }

  return request;
}




#import,dir "modules/mybasic";
#import,dir "modules/mysocket";

#import "Windows";
#import "File";
#import "Thread";
release :: (sema: Semaphore) {ReleaseSemaphore(sema.event, 1, null); }
