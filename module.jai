

#load "websocket.jai";

#if OS == .WINDOWS #load "windows.jai";
#if OS == .LINUX   #load "linux.jai";








send_html :: (request: *Request, html: string, status_code: u16 = 200, content_type: string = "text/html", content_encoding: string = "") {
  // todo: status_code 404 is responding with 404 OK; lol
  content_encoding_header := ifx content_encoding then tprint("Content-Encoding: %\r\n", content_encoding) else "";
  http_response := tprint("HTTP/1.1 % OK\r\nConnection: Keep-Alive\r\nContent-Length: %\r\nContent-Type: %; charset=UTF-8\r\n%Server: Jai\r\n\r\n%", status_code, html.count, content_type, content_encoding_header, html);

  mysocket_write(request.socket, http_response);
  // mylog("Respon:", request.socket.socket);
  request.response_sent = true;
}

send_json :: (request: *Request, json: string) {
  http_response := tprint("HTTP/1.1 200 OK\r\nConnection: Keep-Alive\r\nContent-Length: %\r\nContent-Type: application/json\r\n\r\n%", json.count, json);
  mysocket_write(request.socket, http_response);
  request.response_sent = true;
}

send_file :: (request: *Request, filename: string) {
  file_cache_record, success := file_cache_get_or_create(filename);
  if !success return;

  content_type := extension2contenttype(filename);
  content := ifx does_request_accept_encoding(request, "br") then file_cache_record.brotli else file_cache_record.rawcontent;
  content_encoding := ifx does_request_accept_encoding(request, "br") then "br" else "";
  send_html(request, content, content_type=content_type, content_encoding=content_encoding);
}


parseheaders :: true;
Request :: struct {
  #as socket      : MySocket;
  raw             : string;
  raw_allocated   : int;
  body            : string;
  path            : string;
  params          : Table(string, string);
  content_length  : u32;
  method          : METHOD;
  response_sent   : bool;
  err             : bool;

  websocket_key   : string;
  accept_encoding : string;

  #if parseheaders {
    headers       : Table(string, string);
  }

  #if OS == .LINUX {
    buffercursor  : u32;
    startofline   : u32;
  }
}
operator == :: inline (a: Request, b: Request) -> bool {
  return a.socket == b.socket;
}

does_request_accept_encoding :: (request: *Request, encoding: string) -> bool {
  if !request.accept_encoding return false;
  #import "String";
  for encoding: split(request.accept_encoding, ",") {
    if trim(encoding, " ") == encoding return true;
  }
  return false;
}

handle_request :: (request: *Request) {
  path_normal := normalize_path(request.path);

  if request.websocket_key {
    if table_find_pointer(*websocket_servers, path_normal) {
      websocket_handle_request(request);
    } else {
      // todo: received a websocket request for a path we're not listening to. maybe some kind of notification, send a proper decline response?
    }
  }

  // let the user's middleware handle the request!
  for middleware: middlewares {

    if request.response_sent then break; // once a middleware handles the request, we stop. this is first because webhook could've handled it already

    if middleware.method != .ANY && middleware.method != request.method then continue;
    // if middleware.path != "*" && middleware.path != request.path then continue;
    if middleware.path != "*" && !is_path_match(middleware.path, path_normal) then continue;

    middleware_contains_params := contains_prams(middleware.path);
    if middleware_contains_params {
      #import "String";
      middleware_path_split := split(middleware.path, "/");
      request_path_split := split(path_normal, "/");
      for middleware_path_split {
        if !contains_prams(it) continue;
        param_name := middleware_path_split[it_index];
        param_name.data += 1;
        param_name.count -= 1;
        // array_add(request.params, request_path_split[it_index]);
        // request.params[param_name] = request_path_split[it_index];
        // table_add(request.params, param_name, request_path_split[it_index]);
        request.params[param_name] = request_path_split[it_index];
      }
    }

    middleware.cb(request);
  }

  // if none of the middleware responded to this request, 404
  if !request.response_sent then send_html(request, tprint("<pre>Cannot % %</pre>", request.method, request.path), status_code=404);


  contains_prams :: (s: string) -> bool {
    #import "String";
    return contains(s, ":");
  }

  is_path_match :: (a: string, b: string) -> bool {
    #import "String";
    if !contains_prams(a) return a == b;

    parts_a := split(a, "/");
    parts_b := split(b, "/");
    if parts_a.count != parts_b.count return false;

    for parts_a {
      part_a := parts_a[it_index];
      part_b := parts_b[it_index];
      if !contains_prams(part_a) {
        if part_a != part_b return false;
      }
    }

    return true;
  }
}









middlewares: [..]Middleware;

Middleware :: struct {
  method: METHOD;
  path: string;
  cb: (*Request)->();
}

get :: (path: string, cb: (*Request)->()) {
  middleware: Middleware;
  middleware.path = normalize_path(path);
  middleware.cb = cb;
  middleware.method = .GET;
  array_add(*middlewares, middleware);
}

post :: (path: string, cb: (*Request)->()) {
  middleware: Middleware;
  middleware.path = normalize_path(path);
  middleware.cb = cb;
  middleware.method = .POST;
  array_add(*middlewares, middleware);
}

any :: (path: string, cb: (*Request)->()) {
  middleware: Middleware;
  middleware.path = normalize_path(path);
  middleware.cb = cb;
  middleware.method = .ANY;
  array_add(*middlewares, middleware);
}



static_folder: string;
cwd: string;
static :: (folder: string) {

  assert(folder.count > 0, "folder to serve can't be an empty string");
  assert(static_folder.count == 0, "you can't currently static serve more than 1 folder");

  static_folder = folder;
  tmpcwd := get_working_directory();
  cwd.data = alloc(tmpcwd.count);
  cwd.count = tmpcwd.count;
  memcpy(cwd.data, tmpcwd.data, tmpcwd.count);
  tfree();

  get("*", (request: *Request) {;
    path := join(cwd, "/", static_folder, request.path); #import "String";

    if ends_with(request.path, "/") {
      path = tstr + path + "index.html";
    }

    send_file(request, path);
    tfree();
  });
}



File_Cache_Record :: struct {
  rawcontent: string;
  brotli: string;
}
file_cache: Table(string, File_Cache_Record);
file_cache_get_or_create :: (filename: string) -> File_Cache_Record, bool {
  record, found := table_find(*file_cache, filename);
  if found then return record, true;

  filetext, success := read_entire_file(filename);
  if !success return .{}, false;

  file_cache_record := table_set(*file_cache, filename, .{});
  file_cache_record.rawcontent = filetext;

  content_type := extension2contenttype(filename);
  is_filecontent_text := find_index_from_left("content_type", "text/") == 0;

  #import,dir "modules/brotli";
  compressed := ifx is_filecontent_text then brotli_compress_text(filetext) else brotli_compress(filetext);
  file_cache_record.brotli = compressed;

  return file_cache_record, true;
}






METHOD :: enum u8 {ANY; GET; POST; PUT; DELETE;}
to_METHOD :: (str: string) -> METHOD {
  if str == {
    case "GET";     return .GET;
    case "POST";    return .POST;
    case "PUT";     return .PUT;
    case "DELETE";  return .DELETE;
    case;           return .ANY;
  }
}




extension2contenttype :: (filename: string) -> string {
  index_of_dot := find_index_from_right(filename, ".");
  if index_of_dot == -1 return "text/html";

  extension: string;
  extension.data = filename.data + index_of_dot;
  extension.count = filename.count - index_of_dot;

  if extension == {
    case ".css";  return "text/css";
    case ".js";   return "text/javascript";
    case ".mps";  return "audio/mpeg";
    case ".png";  return "image/png";
    case ".webm"; return "video/webm";
    case ".webp"; return "image/webp";
    case ".gif";  return "image/gif";
    case ".ico";  return "image/x-icon";
    case ".jpg";  return "image/jpeg";
    case ".jpeg"; return "image/jpeg";
  }

  return "text/html";
}


normalize_path :: (path: string) -> string { return trim(path, "/"); }








mysocket_read :: (socket: Socket, buffer: *u8, bufferlen: s32) -> s64 {

  #if OS == .LINUX
    if ssl_is_socket_ssl(socket) // perf hash table lookup
      return ssl_read(socket, buffer, xx bufferlen);

  return recv(socket, buffer, xx bufferlen, 0);
}

mysocket_write :: (socket: Socket, buffer: string) -> s64 {

  #if OS == .LINUX
    if ssl_is_socket_ssl(socket) // perf hash table lookup
      return ssl_write(socket, buffer.data, xx buffer.count);

  return send(socket, buffer.data, xx buffer.count, 0);
}
