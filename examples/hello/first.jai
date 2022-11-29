


#import,file "../../module.jai"; // #import "http_server";

main :: () {

  http_listen(port=80);
  // https_listen(certificate="cert.pem", privatekey="privkey.pem");


  // log every request
  any("*", (request: *Request) {;
    mylog(request.method, request.path);
    // mylog(request.raw);
    // mylog(request.body);
    // for v, k: request.headers  mylog(k, "\t", v);
  });


  get("/hello", (request: *Request) {; send_html(request, "hello world!"); });


  get("/hello/:name", (request: *Request) {;
    send_html(request, tprint("Hello %!", request.params["name"]));
  });


  get("/json", (request: *Request) {;
    json := #string END
      {"apiversion": "1", "author": "farzher", "color": "#118888", "head": "default", "tail": "default"}
    END
    send_json(request, json);
  });


  {
    ws_server := websocket_listen("/ws");
    ws_server.onopen = (ws: *Websocket) {;
      ws.send(ws, "welcome");
      mylog("new websocket connected");
    };
    ws_server.onclose = (ws: *Websocket) {; mylog("websocket died :(", <<ws); };
    ws_server.onmsg = (ws: *Websocket, msg: string) {
      ws.broadcast(ws, msg); // broadcasts the message to all other connected websockets
      ws.send(ws, msg);      // let's echo the msg back to ourself aswell
    };
  }


  static("public");







  while 1  sleep_milliseconds(60_000); // uhh, the program just exits instantly without this xxx
}





#import "Basic";
mylog :: (args: ..Any) {for args print("% ", it); print("\n"); }

#import "Hash_Table";
operator [] :: (t: Table(string, string), index: string) -> string {
  result, found := table_find(*t, index);
  if !found return "";
  return result;
}
operator []= :: (t: *Table(string, string), index: string, value: string) {;
  table_add(t, index, value);
}
