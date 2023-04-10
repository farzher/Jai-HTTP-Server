# Jai-HTTP-Server
Focused on maximum performance.

Features: HTTP / HTTPS / Websockets / epoll threading / Brotli compression

Designed for Linux, but also runs on Windows for development.

## Example [examples/hello/first.jai](https://github.com/farzher/Jai-HTTP-Server/blob/master/examples/hello/first.jai)
```c
#import "http_server";

main :: () {
  http_listen(port=80);

  // log every request
  any("*", (request: *Request) { mylog(request.method, request.path); });

  // using path parameters
  get("/hello/:name", (request: *Request) {
    send_html(request, tprint("Hello %!", request.params["name"]));
  });

  // serve static files from the public folder
  static("public");

  // websocket chat server
  ws_server := websocket_listen("/chat");
  ws_server.onmsg = (ws: *Websocket, msg: string) { ws.broadcast(ws, msg); };
}
```

## Benchmarks

- CPU: `Intel 8700k (6 cores, 12 threads)`
- OS: `Ubuntu-22.04 (WSL)`
- Benchmark Command: `wrk --latency -t6 -c100 -d10 http://localhost`

![image](https://user-images.githubusercontent.com/1005136/230886599-d12452b7-7d65-4f73-b1f1-f5a54d3e4926.png)




#### Jai - [Jai-HTTP-Server](https://github.com/farzher/Jai-HTTP-Server) | Req/Sec    100.19k
```
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   156.26us  160.79us   9.55ms   91.77%
    Req/Sec   100.19k     4.45k  108.06k    77.69%

  Latency Distribution
     50%  117.00us
     75%  192.00us
     90%  295.00us
     99%  663.00us

  6030627 requests in 10.10s, 741.91MB read

Requests/sec: 597118.74
Transfer/sec:     73.46MB
```


#### Go - [fasthttp](https://github.com/valyala/fasthttp) | Req/Sec    83.65k
```
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   377.51us    1.04ms  30.35ms   93.91%
    Req/Sec    83.65k    19.41k  112.94k    54.33%

  Latency Distribution
     50%  110.00us
     75%  202.00us
     90%  637.00us
     99%    5.44ms

  5002200 requests in 10.04s, 706.03MB read

Requests/sec: 498380.73
Transfer/sec:     70.34MB
```


#### C - [nginx](https://nginx.org/en/) | Req/Sec    26.98k
```
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     2.32ms    4.56ms  51.44ms   88.15%
    Req/Sec    26.98k     4.33k   45.43k    67.67%

  Latency Distribution
     50%  389.00us
     75%    1.38ms
     90%    8.05ms
     99%   20.90ms

  1617850 requests in 10.07s, 397.99MB read

Requests/sec: 160681.34
Transfer/sec:     39.53MB
```



#### Node.js - [express](https://github.com/expressjs/express) | Req/Sec     1.11k
```
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    14.54ms    2.43ms  53.01ms   92.01%
    Req/Sec     1.11k   126.14     1.29k    81.33%

  Latency Distribution
     50%   13.74ms
     75%   14.73ms
     90%   16.58ms
     99%   26.07ms

  66124 requests in 10.01s, 15.13MB read

Requests/sec:   6607.94
Transfer/sec:      1.51MB
```









## Usage
0. have the compiler v0.1.60
1. run `examples/hello/run.bat` or `examples/hello/run.sh`
