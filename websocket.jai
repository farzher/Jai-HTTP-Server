


// this is what a websocket frame looks like.
// first 2 bytes are always the same.
// if payload len is 126 then the payload len is actually the next u16
// if payload len is 127 then the payload len is actually the next u64
// if mask bit is set, then the next u32 is the mask key
// the rest of the data is payload len bytes of the actual payload.
// if mask is set you need to xor payload bytes with mask bytes (payload[i] = payload[i] ^ mask[i%4])

//  0               1               2               3                bytes
//  0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7  bits
// +-+-+-+-+-------+-+-------------+-------------------------------+
// |F|R|R|R| opcode|M| payload len |    extended payload len       |
// |I|S|S|S|  (4)  |A|     (7)     | if payload len is 126 u16     |
// |N|V|V|V|       |S|             | if payload len is 127 u64     |
// | |1|2|3|       |K|             |                               |
// +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
// |     extended payload len continued, if payload len == 127     |
// + - - - - - - - - - - - - - - - +-------------------------------+
// |     extended payload len ...  | Masking-key, if MASK set to 1 |
// +-------------------------------+-------------------------------+
// | Masking-key (continued)       |          Payload Data         |
// +-------------------------------- - - - - - - - - - - - - - - - +
// :                     Payload Data continued ...                :
// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
// |                     Payload Data continued ...                |
// +---------------------------------------------------------------+

Websocket_Parsing_Frame_State :: struct {

  parsing_stage         : enum {FIRST_TWO_BYTES; REST_OF_HEADER; READING_PAYLOAD;};

  buffer                : string;
  payload               : string; // a pointer into buffer
  payload_continuation  : string; // when reading !fin CONTINUATION frames, payloads from the buffer will be copied into this buffer

  bytes_needed          : s32 = 2; // we always need at least the first 2 bytes
  bytes_read            : int;

  op_code               : Websocket.OPCODE;
  rsv_bits              : u8;
  is_fin                : bool;
  is_masked             : bool;
  mask                  : u32;

  header_len            : u8;
  payload_len_bytecount : u8;
  payload_len           : u64;
}




all_websockets    : Table(Socket, Websocket);
websocket_servers : Table(string, Websocket_Server);

Websocket :: struct {
  #as socket    : MySocket;

  err           : bool;
  pingms        : u16;
  pingsentatms  : float64;
  server        : *Websocket_Server;

  // state         : STATE;
  parsing_state : Websocket_Parsing_Frame_State;

  broadcast    :: websocket_broadcast;
  send         :: websocket_send;
  send_ping    :: websocket_send_ping; // this should really be public? just here for testing

  STATE  :: enum {CONNECTING; OPEN; CLOSING; CLOSED;}
  OPCODE :: enum {CONTINUATION :: 0; TEXT :: 1; BINARY :: 2; CLOSE :: 8; PING :: 9; PONG :: 10;}
}

Websocket_Server :: struct {
  onopen        : (*Websocket)->();
  onmsg         : (*Websocket, string)->();
  onclose       : (*Websocket)->();

  path          : string;
  websockets    : [..] *Websocket;
}


// listens for websockets trying to connect at this path
websocket_listen :: (path: string = "") -> *Websocket_Server {
  assert(listen_called, "http_listen must be called before websocket_listen");
  assert(table_find_pointer(*websocket_servers, path) == null, "websocket already listening on this path");

  ws_server: Websocket_Server;
  ws_server.path = normalize_path(path);

  return table_set(*websocket_servers, ws_server.path, ws_server);
}

// broadcast msg to all OTHER websockets on the server
websocket_broadcast :: (ws: *Websocket, payload: string, op_code: Websocket.OPCODE = .TEXT) {
  for ws.server.websockets {
    if it == ws continue; // don't broadcast to ourselves
    websocket_send(it, payload, op_code);
  }
}

// the most common way to send a message to a websocket. besides broadcast
websocket_send :: (ws: *Websocket, payload: string = "", op_code: Websocket.OPCODE = .TEXT) {

  fin_bit :: 0b_10000000;

  // fast path for small payloads
  if (payload.count <= 125) {
    header_byte_count := 2;
    buffer := talloc_string(header_byte_count + payload.count);
    buffer[0] = xx op_code | fin_bit;
    buffer[1] = cast(u8)payload.count;
    if payload.count then memcpy(*buffer[2], payload.data, payload.count);
    websocket_send_bytes(ws, buffer);
    return;
  }


  header: string;

  if (payload.count < 65536) {
    header = talloc_string(4);
    header[0] = xx op_code | fin_bit;
    header[1] = 126;
    memcpy(*header[2], *endian_swap(cast(u16)payload.count), 2);

  } else {
    header = talloc_string(10);
    header[0] = xx op_code | fin_bit;
    header[1] = 127;
    memcpy(*header[2], *endian_swap(cast(u64)payload.count), 8);
  }

  websocket_send_bytes(ws, header);
  websocket_send_bytes(ws, payload);
}





#scope_module

websocket_handle_request :: (request: *Request) {

  websocket_send_request_handshake_accepted :: (request: *Request) {

    hash_ws_key :: (Sec_WebSocket_Key: string) -> string {
      data := tjoin(Sec_WebSocket_Key, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
      websocket_key_hash := base64_encode(xx sha1_binary(data)); #import,dir "modules/sha1"; #import "Base64";
      return websocket_key_hash;
    }
    websocket_key_response := hash_ws_key(request.websocket_key);

    http_response := tprint("HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Accept: %\r\n\r\n", websocket_key_response);
    send(request.socket, http_response);
    request.response_sent = true;
  }

  websocket_send_request_handshake_accepted(request);

  ws := websocket_new(request);
  if ws.server.onopen then ws.server.onopen(ws);

  websocket_read_frame(ws);
  if ws.err then mylog("unhandled websocket error!!!!");

}

websocket_read_frame :: (ws: *Websocket) {

  // state := *ws.parsing_state;
  using ws.parsing_state;
  // this using is messy, but i'm too lazy to rewrite all the code here


  // ensure we have a buffer allocated
  INITIAL_BUFFER_LEN :: 1024*1;
  if buffer.data == null {
    buffer = alloc_string(INITIAL_BUFFER_LEN);
  }

  Error :: (msg: string) #expand { mylog("[websocket_read_frame Error]", msg); `ws.err = true; break; }

  while 1 {
    if ws.err then return;
    if buffer.count < bytes_needed - bytes_read then die("why?");
    bytes_received := recv(ws.socket, buffer.data + bytes_read, xx (bytes_needed - bytes_read) );

    #if OS==.LINUX if bytes_received < 0 && errno() == EWOULDBLOCK return;

    if bytes_received == 0 Error(""); // this maybe isn't an error? on connection that aren't keep-alive?
    if bytes_received < 0  Error("");

    bytes_read += bytes_received;


    while 1 {
      // mylog(parsing_stage, bytes_read, bytes_needed);
      if parsing_stage == {

        case .FIRST_TWO_BYTES; {
          if bytes_read < bytes_needed break;

          is_fin    = xx buffer[0] & 0b_10000000;
          rsv_bits  = xx buffer[0] & 0b_01110000;
          op_code   = xx buffer[0] & 0b_00001111;
          is_masked = xx buffer[1] & 0b_10000000;

          if rsv_bits Error("none of these bits RSV extension bits should be set because we don't handle them.");

          if buffer[1] & 0b_01111111 == {
            case 126; payload_len_bytecount = 2;
            case 127; payload_len_bytecount = 8;
            case;     payload_len_bytecount = 0;
          }

          header_len = 2 + payload_len_bytecount;
          if is_masked then header_len += 4;

          bytes_needed = header_len;
          parsing_stage = .REST_OF_HEADER;
          continue;
        }


        case .REST_OF_HEADER; {
          if bytes_read < bytes_needed break;

          if is_masked then mask = unsafe_cast(*buffer[header_len-4], u32);

          if payload_len_bytecount == {
            case 2; payload_len = endian_swap(unsafe_cast(*buffer[2], u16));
            case 8; payload_len = endian_swap(unsafe_cast(*buffer[2], u64));
            case;   payload_len = buffer[1] & 0b_01111111;
          }

          // prevent obvious dos attack
          if payload_len > 1024*1024*1 Error("we don't accept payloads greater than 1MB, goodbye, sorry!");

          // if we need more bytes than our current buffer can fit, time to realloc.
          bytes_needed = xx (header_len + payload_len);
          if buffer.count < bytes_needed {
            buffer.data = realloc(buffer.data, bytes_needed, buffer.count);
            buffer.count = bytes_needed;
          }

          payload.data = buffer.data + header_len;
          payload.count = xx payload_len;

          parsing_stage = .READING_PAYLOAD;
          continue;
        }


        case .READING_PAYLOAD; {
          if bytes_read < bytes_needed break;

          if #complete op_code == {

            case .CLOSE; {
              websocket_delete(ws);
              return;
            }

            case .PING; {
              mylog("received a ping ???, we probably need to respond with the payload in our pong"); // todo
              websocket_send(ws, op_code = .PONG);
            }

            case .PONG; {
              msdiff := getms() - ws.pingsentatms;
              mylog("PONG:", msdiff);
              if msdiff < 0 || msdiff > 10000 {
                // ping too large, kill it
                websocket_send(ws, op_code = .CLOSE);
                websocket_delete(ws);
                return;
              }
              ws.pingms = xx msdiff;
            }

            case .TEXT;         #through;
            case .BINARY;       #through;
            case .CONTINUATION; {
              apply_mask_to_payload :: () #expand {
                if is_masked {
                  maskbytes := unsafe_cast(*mask, [4]u8);
                  for i: 0..payload.count-1 {
                    payload[i] = payload[i] ^ maskbytes[i % 4];
                  }
                }
              }
              apply_mask_to_payload();

              // this is complexity for dealing with the annoying fact that a single message can be sent via multiple CONTINUATION frames.
              // we have to allocate a new buffer and copy this frame's payload into it
              if !is_fin || payload_continuation.data {
                if !payload_continuation.data {
                  payload_continuation = alloc_string(payload.count);
                  memcpy(payload_continuation.data, payload.data, payload.count);
                } else {
                  payload_continuation.data = realloc(payload_continuation.data, payload_continuation.count + payload.count, payload_continuation.count);
                  payload_continuation.count = payload_continuation.count + payload.count;
                  memcpy(payload_continuation.data + payload_continuation.count - payload.count, payload.data, payload.count);
                }
              }

              if is_fin {
                if !payload_continuation.data {
                  if ws.server.onmsg then ws.server.onmsg(ws, payload);
                } else {
                  if ws.server.onmsg then ws.server.onmsg(ws, payload_continuation);
                  free(payload_continuation);
                  payload_continuation.data = null;
                  payload_continuation.count = 0;
                }
              }
            }

            case;
              Error(tprint("we don't handle this op_code: %", op_code));
          }


          // have to reset the parsing information ... for the next frame ... this is messy
          // important that this always runs after a frame is finished being read
          parsing_stage = .FIRST_TWO_BYTES;
          bytes_read = 0;
          bytes_needed = 2;
          break;
        }
      }
    }
  }
}






#scope_file

websocket_new :: (request: Request) -> *Websocket {
  ws := table_add(*all_websockets, request.socket, .{});
  ws.socket = request.socket;

  path_normal := normalize_path(request.path);

  websocket_server := table_find_pointer(*websocket_servers, path_normal);
  assert(websocket_server != null);

  ws.server = websocket_server;
  array_add(*websocket_server.websockets, ws);

  return ws;
}

websocket_delete :: (ws: *Websocket) {
  if ws.server.onclose then ws.server.onclose(ws);

  socket_close(ws.socket); // not sure if this is necessary. also it might already be closed?

  // is unordered a problem?
  table_remove(*all_websockets, ws.socket);
  array_unordered_remove_by_value(*ws.server.websockets, ws);

  free(ws.parsing_state.buffer);               // these may or may not be allocated. freeing null isn't a problem, right?
  free(ws.parsing_state.payload_continuation); // these may or may not be allocated. freeing null isn't a problem, right?
}


websocket_send_bytes :: (ws: *Websocket, bytes: string) {
  if ws.err return;

  sent_byte_count := send(ws.socket, bytes);
  if sent_byte_count == -1 {
    ws.err = true;
    websocket_delete(ws);
  }
}
websocket_send_ping :: (ws: *Websocket) {
  websocket_send(ws, op_code = .PING);
  ws.pingsentatms = getms();
}



endian_swap :: (val: u64) -> u64 {
  val = ((val <<  8) & 0xFF00FF00FF00FF00 ) | ((val >>  8) & 0x00FF00FF00FF00FF );
  val = ((val << 16) & 0xFFFF0000FFFF0000 ) | ((val >> 16) & 0x0000FFFF0000FFFF );
  return (val << 32) | (val >> 32);
}
endian_swap :: (val: u16) -> u16 {
  return (val << 8) | (val >> 8 );
}


operator == :: inline (a: Websocket, b: Websocket) -> bool {
  return a.socket.socket == b.socket.socket;
}

// #poke_name Basic operator==;
array_unordered_remove_by_value :: inline (array: *[..] $T, item: T, $stop_after_first := false) -> s64 {
  // Probably want to say something to debug memory trackers here.
  // Need to make sure it doesn't cost anything in Release.
  removed := 0;
  for <<array  if it == item {
    removed += 1;
    remove it;

    if stop_after_first  break;   // Early-out optimization.
  }

  return removed;
}


// todo:
  // need to heartbeat kill hanging clients. close them if they take too long to respond.
  // static small buffer for small fast websockets that don't need a big allocation would be nice.



