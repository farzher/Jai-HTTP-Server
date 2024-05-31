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

- CPU: `Intel 12700 (8 cores, 16 threads (E cores disabled))`
- OS: `Ubuntu-22.04 (WSL)`

![image](https://i.imgur.com/o1eqImu.png)




#### Jai - [Jai-HTTP-Server](https://github.com/farzher/Jai-HTTP-Server) | Req/Sec (526.51k, 1.16M)
```
$ wrk --latency -t1 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   114.99us   41.34us 375.00us   71.77%
    Req/Sec   526.51k     2.29k  529.79k    60.00%
  Latency Distribution
     50%   90.00us
     75%  163.00us
     90%  178.00us
     99%  199.00us

$ wrk --latency -t8 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    80.23us   55.36us   3.82ms   93.89%
    Req/Sec   146.36k    12.96k  181.13k    68.18%
  Latency Distribution
     50%   75.00us
     75%   97.00us
     90%  120.00us
     99%  182.00us
```


#### Go - [fasthttp](https://github.com/valyala/fasthttp) | Req/Sec (353.35k, 916.12k)
```
$ wrk --latency -t1 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   150.86us   44.43us 568.00us   89.11%
    Req/Sec   353.35k     3.13k  357.22k    80.00%
  Latency Distribution
     50%  138.00us
     75%  150.00us
     90%  186.00us
     99%  306.00us

$ wrk --latency -t8 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   186.13us  520.34us  12.54ms   97.15%
    Req/Sec   115.16k     4.19k  126.00k    71.59%
  Latency Distribution
     50%   74.00us
     75%  210.00us
     90%  395.00us
     99%    1.29ms
```


#### C - [nginx](https://nginx.org/en/) | Req/Sec (262.32k, 635.78k)
```
$ wrk --latency -t1 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   229.60us  135.18us   1.73ms   86.47%
    Req/Sec   262.32k    22.41k  294.30k    80.00%
  Latency Distribution
     50%  187.00us
     75%  248.00us
     90%  374.00us
     99%  773.00us

$ wrk --latency -t8 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.17ms    3.11ms  43.37ms   90.78%
    Req/Sec    85.28k    21.01k  209.25k    93.90%
  Latency Distribution
     50%   89.00us
     75%  263.00us
     90%    3.85ms
     99%   15.81ms
```



#### Node.js - [express](https://github.com/expressjs/express) | Req/Sec (15.08k, 14.92k)
```
$ wrk --latency -t1 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     6.64ms  492.35us  11.33ms   85.09%
    Req/Sec    15.08k   486.73    15.59k    81.82%
  Latency Distribution
     50%    6.45ms
     75%    6.52ms
     90%    7.58ms
     99%    8.13ms

$ wrk --latency -t8 -c100 -d1 http://localhost
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     5.98ms    1.45ms  12.59ms   84.73%
    Req/Sec     2.01k     0.88k    7.51k    97.56%
  Latency Distribution
     50%    6.23ms
     75%    6.30ms
     90%    7.28ms
     99%    7.99ms
```









## Usage
0. have the compiler Version: beta 0.1.090, built on 12 April 2024.
1. run `examples/hello/run.bat` or `examples/hello/run.sh`
