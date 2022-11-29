# Jai-HTTP-Server
Focused on maximum performance.

Features: HTTP / HTTPS / Websockets / epoll threading / Brotli compression

Designed for Linux, but also runs on Windows for development.

### Example [examples/hello/first.jai](https://github.com/farzher/Jai-HTTP-Server/blob/master/examples/hello/first.jai)
```c
#import "http_server";

main :: () {
  http_listen(port=80);

  // log every request
  any("*", (request: *Request) { mylog(request.method, request.path); });

  // using path parameters
  get("/hello/:name", (request: *Request) {;
    send_html(request, tprint("Hello %!", request.params["name"]));
  });
  
  // websocket chat server
  ws_server := websocket_listen("/chat");
  ws_server.onmsg = (ws: *Websocket, msg: string) { ws.broadcast(ws, msg); };

  // serve all files in the public folder
  static("public");
}
```

### Usage
0. have the compiler v0.1.47
1. run `examples/hello/run.bat` or `examples/hello/run.sh`
