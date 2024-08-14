

#load "websocket.jai";

#if OS == .WINDOWS #load "windows.jai";
#if OS == .LINUX   #load "linux.jai";

// the main entry point is http_listen, which is defined in linux.jai and windows.jai




// todo: this method of looping through middlewares is slow @perf
middlewares: [..]Middleware;

Middleware :: struct {
  method: METHOD;
  path: string;
  cb: (*Request)->();
}

get    :: (path: string, cb: (*Request)->()) {array_add(*middlewares, .{method=.GET,    cb=cb, path=normalize_path(path)}); }
post   :: (path: string, cb: (*Request)->()) {array_add(*middlewares, .{method=.POST,   cb=cb, path=normalize_path(path)}); }
put    :: (path: string, cb: (*Request)->()) {array_add(*middlewares, .{method=.PUT,    cb=cb, path=normalize_path(path)}); }
delete :: (path: string, cb: (*Request)->()) {array_add(*middlewares, .{method=.DELETE, cb=cb, path=normalize_path(path)}); }
any    :: (path: string, cb: (*Request)->()) {array_add(*middlewares, .{method=.ANY,    cb=cb, path=normalize_path(path)}); }






send_html     :: #bake_arguments send_response(content_type="text/html");
send_text     :: #bake_arguments send_response(content_type="text/plain");
send_json     :: #bake_arguments send_response(content_type="application/json");
send_response :: (request: *Request, content: string, status_code: u16 = 200, content_type: string = "text/plain", content_encoding: string = "") {
  // todo: status_code 404 is responding with "404 OK" lol
  content_encoding_header := ifx content_encoding then tprint("\r\nContent-Encoding: %", content_encoding) else "";
  http_response := tprint("HTTP/1.1 % OK\r\nContent-Length: %\r\nContent-Type: %; charset=UTF-8%\r\n\r\n%", status_code, content.count, content_type, content_encoding_header, content);

  request.response_sent = true;

  #if OS == .WINDOWS {
    mysocket_write(request.socket, http_response);
  } else {
    bytes_sent := mysocket_write(request.socket, http_response);
    if bytes_sent < http_response.count {
      write_data := alloc_string(http_response.count - bytes_sent);
      memcpy(write_data.data, http_response.data + bytes_sent, write_data.count);
      request.write_data       = write_data;
      request.write_bytes_sent = 0;
      continue_write(request);
    }
  }
}

send_file :: (request: *Request, raw_filename: string) {
  filename := normalize_filename(raw_filename);

  file_cache_record, success := file_cache_get_or_create(filename);
  if !success return;

  // for very small files, it's possible that brotli encoding is longer than the raw content.
  // in that case the brotli api will return the brotli encoding as ""
  // and so we will return the raw content instead, even though the client accepts br encoding
  are_we_returning_br := does_request_accept_encoding(request, "br") && file_cache_record.brotli != "";

  content := ifx are_we_returning_br then file_cache_record.brotli else file_cache_record.rawcontent;
  content_encoding := ifx are_we_returning_br then "br" else "";
  content_type := extension2contenttype(filename);
  send_response(request, content, content_type=content_type, content_encoding=content_encoding);
}


parseheaders :: true;
Request :: struct {
  #as socket      : MySocket;

  raw             : string; // entire raw http request
  body            : string; // pointer into raw
  path            : string; // pointer into raw

  content_length  : u32;
  method          : METHOD;
  websocket_key   : string;
  accept_encoding : string;

  params          : Table(string, string);
  #if parseheaders {
    headers       : Table(string, string);
  }

  response_sent   : bool;
  err             : bool;

  #if OS == .LINUX {
    buffercursor     : u32;
    startofline      : u32;

    write_data       : string;
    write_bytes_sent : int;

    epoll_fd         : s32;
  }

  get_param :: (request: *Request, name: string) -> string {
    val, found := table_find(*request.params, name);
    if !found return "";
    return val;
  }
}
operator == :: inline (a: Request, b: Request) -> bool {return a.socket == b.socket; }

does_request_accept_encoding :: (request: *Request, encoding: string) -> bool {
  if !request.accept_encoding return false;
  for encoding: split(request.accept_encoding, ",") {
    if trim(encoding, " ") == encoding return true;
  }
  return false;
}

handle_request :: (request: *Request) {

  contains_prams :: (s: string) -> bool {
    return contains(s, ":");
  }

  is_path_match :: (a: string, b: string) -> bool {
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

  path_normal := normalize_path(request.path);

  if request.websocket_key {
    if table_find_pointer(*websocket_servers, path_normal) {
      websocket_handle_request(request);
    } else {
      // todo: received a websocket request for a path we're not listening to. maybe some kind of notification, send a proper decline response?
    }
  }

  // let the user's middleware handle the request!
  // use tries instead of a for loop ... @perf
  for middleware: middlewares {

    if request.response_sent then break; // once a middleware handles the request, we stop. this is first because webhook could've handled it already

    if middleware.method != .ANY && middleware.method != request.method then continue;
    // if middleware.path != "*" && middleware.path != request.path then continue;
    if middleware.path != "*" && !is_path_match(middleware.path, path_normal) then continue;

    table_reset(*request.params); // maybe this should happen somewhere else?
    middleware_contains_params := contains_prams(middleware.path);
    if middleware_contains_params {
      middleware_path_split := split(middleware.path, "/");
      request_path_split := split(path_normal, "/");
      for middleware_path_split {
        if !contains_prams(it) continue;
        param_name := middleware_path_split[it_index];
        param_name.data += 1;
        param_name.count -= 1;
        // array_add(request.params, request_path_split[it_index]);
        // request.params[param_name] = request_path_split[it_index];
        table_add(*request.params, param_name, request_path_split[it_index]);
        // request.params[param_name] = request_path_split[it_index];
      }
    }

    middleware.cb(request);
  }

  // if none of the middleware responded to this request, 404
  if !request.response_sent then send_text(request, tprint("Cannot % %", request.method, request.path), status_code=404);
}


cwd: string;
the_static_folder_to_serve: string;
static :: (folder: string) {
  assert(folder.count > 0, "folder to serve can't be an empty string");
  assert(the_static_folder_to_serve.count == 0, "you can't currently static serve more than 1 folder");

  cwd = copy_string(get_working_directory());
  the_static_folder_to_serve = folder;

  get("*", (request: *Request) {;

    // if the path ends wht a / then we consider it a folder, and we'll add index.html to the end of the path to load that.
    path: string;
    if ends_with(request.path, "/") {
      path = tjoin(cwd, "/", the_static_folder_to_serve, request.path, "index.html");
    } else {
      path = tjoin(cwd, "/", the_static_folder_to_serve, request.path);
    }

    send_file(request, path);
  });
}




// when we cache a file, we store both the raw content and also the brotli compressed version of it
File_Cache_Record :: struct {rawcontent: string; brotli: string; }
file_cache: Table(string, File_Cache_Record);

file_cache_get_or_create :: (filename: string) -> File_Cache_Record, bool {

  #if OS != .WINDOWS { // don't actually cache files on windows. for better development experience
    record, found := table_find(*file_cache, filename);
    if found then return record, true;
  }

  filetext, success := read_entire_file(filename);
  if !success return .{}, false;


  // just incase filename is in temporary storage
  // we have to leak a copy of it here to store in the table that won't turn to garbage
  filename_allocated := copy_string(filename);
  file_cache_record := table_set(*file_cache, filename_allocated, .{});
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


// Content-Type aka MIME type
extension2contenttype :: (filename: string) -> string {
  index_of_dot := find_index_from_right(filename, ".");
  if index_of_dot == -1 return "text/html";

  extension := substr(filename, index_of_dot, filename.count-index_of_dot);

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
    case ".svg";  return "image/svg+xml";
    case ".ini";  return "text/plain";
    case ".txt";  return "text/plain";
    case ".exe";  return "application/octet-stream";
  }

  return "text/html";
}


normalize_path :: (path: string) -> string { return trim(path, "/"); }

normalize_filename :: (raw_filename: string) -> string {
  filename := raw_filename;

  { // strip questionmark from filename if it exists ex: main.js?293849203
    questionmark_location_in_filename := find_index_from_left(filename, #char "?");
    if questionmark_location_in_filename != -1 {
      filename.count = questionmark_location_in_filename;
    }
  }

  { // replace %xx with xx conveted to a hex byte
    start_index := 0;
    while true {
      percent_location_in_filename := find_index_from_left(filename, #char "%", start_index);
      percent_escape_exists := percent_location_in_filename != -1;
      if !percent_escape_exists break;
      // todo check that there's actually 2 hex chars after the percent
      // ^ this probably can currently crash the server
      // todo make sure it's valid hex? not sure how this should be handled if it's not? probably just ignored?
      hex_chars := substr(filename, percent_location_in_filename + 1, 2);
      string_byte := hex_chars_to_byte(hex_chars);

      filename.data[percent_location_in_filename] = string_byte;
      copy_starting_from := percent_location_in_filename + 1 + 2;
      memcpy(filename.data + percent_location_in_filename + 1, filename.data + copy_starting_from, filename.count-copy_starting_from);
      filename.count -= 2;

      start_index = percent_location_in_filename + 1;
    }
  }

  return filename;
}

hex_char_to_int :: (char: u8) -> u8 {
  if char >= #char "a" return (char - #char "a" + 0xA);
  if char >= #char "A" return (char - #char "A" + 0xA);
  if char >= #char "0" return (char - #char "0");
  return 1;
}
hex_chars_to_byte :: (chars: string) -> u8 {
  assert(chars.count == 2);
  return hex_char_to_int(chars[0]) * 16 + hex_char_to_int(chars[1]);
}







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



#import "String";
