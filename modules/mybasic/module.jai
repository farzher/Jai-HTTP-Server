/* -farzher September 13, 2021
  just a collection of common functions i use
*/



using Basic :: #import "Basic";
// #import "Basic"()(ENABLE_ASSERT=false);

#import "String";
mylog :: (args:..Any) {
  if args.count == 0 { print("\n"); return; }

  formatstr: string;
  push_tallocator();
  for args  formatstr = join(formatstr, "% ");
  formatstr[formatstr.count-1] = #char "\n"; // replace the trailing space with a newline
  print(formatstr, ..args);
}

code2string :: (code: Code) -> string #expand {
  #import "Program_Print";
  #import "Compiler";
  code_node := compiler_get_nodes(code);
  builder: String_Builder;
  print_expression(*builder, code_node);
  return builder_to_string(*builder, allocator=tallocator);
}
logx :: (code: Code, loc := #caller_location) -> string #expand {
// Type_Of_Code :: struct (c: Code) { T :: #run type_of(#insert c); }
// logx :: (code: Code) -> Type_Of_Code(code).T #expand {
  result := #insert code;

  // loc := #location(); // todo get location of calling line ... ?
  // tmp := split(loc.fully_pathed_filename, "/");
  // filename := tmp[tmp.count-1];
  filename := substr(loc.fully_pathed_filename, get_working_directory().count +1/*remove leading slash*/);
  log("[%:%] % = %", filename, loc.line_number, #run code2string(code), result);

  // log("% = %", #run code2string(code), result);
  return result;
}
// main :: () {
//   str := "sup guys";
//   c := logx(str);
//   logx(c);
// }

_lastmylogms: float64;
mylogms :: (args: ..Any) {
  ms := getms() - _lastmylogms;

  print("[%ms] ", formatFloat(ms, trailing_width=2));
  mylog(..args);

  _lastmylogms = getms();
}


unsafe_cast :: (val: *$T, $type: Type) -> type #expand {
  return <<cast(*type)(val);
}
Cast :: (val: $T, $type: Type) -> type #expand {
  return cast(type)(val);
}


die :: (args: ..Any) {
  mylog("[Fatal Error]");
  mylog(..args);
  exit(1);
}

RELEASE :: #run () -> bool {
  Compiler :: #import "Compiler";
  return Compiler.get_build_options().optimization_level == .RELEASE;
}();

default_allocator :: context.default_allocator;
tallocator :: temp;
tfree :: reset_temporary_storage;
tget :: get_temporary_storage_mark;
tset :: set_temporary_storage_mark;
push_trelease :: auto_release_temp;
push_treset :: auto_release_temp;
push_tallocator :: () #expand {
  old_allocator           := context.allocator;
  `defer context.allocator = old_allocator;

  context.allocator        = tallocator;
};

printF :: () { print("F"); }

map :: (array: [] $T, f: (T) -> $R) -> [..] R {
  result: [..] R;
  for array array_add(*result, f(it));
  return result;
}

mapnumber :: (value: float, from1: float, from2: float, to1: float, to2:float, exponent:float=0, clamp:=true) -> float {
  Math :: #import "Math";
  adist := from2 - from1;
  bdist := to2 - to1;
  ratio := (value - from1) / adist;
  isnegative := ratio < 0;

  if exponent {
    ratio = Math.pow(Math.abs(ratio), exponent);
    if isnegative then ratio = -ratio;
  }

  if clamp {
    if ratio > 1 then ratio = 1;
    else if ratio < -1 then ratio = -1;
  }

  return bdist*ratio + to1;
}

time :: ($code: Code, name: string, count:=1) #expand {
  starttime := get_time();
  for 1 .. count  #insert code;
  difftime := get_time()-starttime;

  fixedname := talloc_string(9);
  for 0..fixedname.count-1   fixedname[it] = #char" ";
  memcpy(fixedname.data, name.data, min(9, name.count) );

  mylog(fixedname, "time:", difftime, "seconds.");
}
bench :: time;
bench :: (name: string, $code: Code, count:=1) #expand {
  bench(code, name, count=count);
}

substr :: inline (str: string, index: int, count: int = 0) -> string #must {
  if count == 0 count = str.count - index;

  c: string = ---;
  c.data = str.data + index;
  c.count = count;
  return c;
}

fromcstr :: (cstr: *u8) -> string {
  ret: string;
  if (cstr == null) return ret;
  ret.data = xx cstr;
  ret.count = c_style_strlen(xx cstr);
  return ret;
}

getms :: () -> float64 { return cast(float64)(get_time()*1000); }
getutc :: () -> u32 {
  systemtime: SYSTEMTIME;
  GetSystemTime(*systemtime);
  filetime: FILETIME;
  SystemTimeToFileTime(*systemtime, *filetime);

  WINDOWS_TICK      :: 10_000_000;
  SEC_TO_UNIX_EPOCH :: 11644473600;

  utc: *u64 = xx *filetime;
  return cast(u32)( <<utc / WINDOWS_TICK - SEC_TO_UNIX_EPOCH);
}

chance :: (percent: float = .5) -> bool {
  Random :: #import "Random";
  return Random.random_get_zero_to_one() < percent;
}

offset_of :: (type: Type, name: string) -> int #expand {
  _offset_of :: (info: *Type_Info_Struct, name: string) -> int {
    for * info.members {
      ptr := *it.name;
      if name == it.name return it.offset_in_bytes;
    }
    assert(false, "member doesn't exist"); return 0; // not all control paths return a value
  }

  return #run _offset_of(type_info(type), name);
}


#if OS == .WINDOWS {
  Mouse: struct {
    WC :: #import "Window_Creation";

    Point :: struct {x: s32; y: s32;}

    pos :: (hwnd: WC.Window_Type) -> Point {
      x, y := WC.get_mouse_pointer_position(hwnd, false);
      pos: Point = ---;
      pos.x = xx x;
      pos.y = xx y;
      return pos;
    }

    pos_global :: () -> Point {
      Windows :: #import "Windows";
      p: Windows.POINT = ---;
      Windows.GetCursorPos(*p);
      pos: Point = ---;
      pos.x = p.x;
      pos.y = p.y;
      return pos;
    }
  }
}


// .-. Error: An operator procedure must, as one of its first two arguments, take either a struct or a pointer to a struct. (Custom operators are not for basic types like strings or numbers.)
// operator + :: (a: string, b: string) -> string {
//   result := talloc_string(a.count+b.count);
//   memcpy(result.data        , a.data, a.count);
//   memcpy(result.data+a.count, b.data, b.count);
//   return result;
// }

// tstr
TStr :: struct {#as str: string; }
tstr: TStr;
to_tstr :: (str: string) -> TStr {
   s: TStr = ---;
   s.str = str;
   return s;
}
tstr_join :: (a:string, b:string) -> string {
    bytes := 0;
    bytes += a.count;
    bytes += b.count;
    if !bytes return "";

    result: string;
    result.count = bytes;
    result.data  = talloc(bytes);
    assert(result.data != null);

    cursor := result.data;
    memcpy(cursor, a.data, a.count);
    cursor += a.count;
    memcpy(cursor, b.data, b.count);

    cursor += b.count;
    assert(cursor == result.data + result.count);

    return result;
}
operator + :: (a: TStr, b: TStr) -> TStr {
  return to_tstr(tstr_join(a.str, b.str));
}
operator + :: (a: TStr, b: string) -> TStr #symmetric {
   return a + to_tstr(b);
}
operator + :: (a: TStr, b: int) -> TStr #symmetric {
   return to_tstr(tprint("%+%", a.str, b));
}



interp :: (_str: string) -> string #expand {
  #insert -> string {
    String :: #import "String";

    builder: String_Builder;

    str := String.replace(_str, "\n", "\\n");

    codestart := 0;
    strstart := 0;

    for i: 0 .. str.count-1 {

      //
      if (str[i] == #char"#" || str[i] == #char"%") && str[i+1] == #char"{" {

        append(*builder, tstr+ "+\""+String.slice(str, strstart, i-strstart)+"\"");

        i += 2;
        codestart = i;
        continue;
      }

      if codestart {
        if str[i] == #char"}" {
          code := String.slice(str, codestart, i-codestart);
          code = String.replace(code, "'", "\"");
          append(*builder, tstr+ "+("+code+")");
          i += 1;
          strstart = i;
          codestart = 0;
        }
      }

      if i == str.count-1 {
        append(*builder, tstr+ "+\""+String.slice(str, strstart, strstart+i+1)+"\"");
      }
    }

    return tstr+ "return tstr" + builder_to_string(*builder) + ";";
  }
}



Global :: (str: string) #expand {
  Compiler :: #import "Compiler";
  #run Compiler.add_build_string(str);
}


using #import "Hash_Table";
operator [] :: (t: Table(string, string), index: string) -> string {
  result, found := table_find(*t, index);
  if !found return "";
  return result;
}
operator []= :: (t: *Table(string, string), index: string, value: string) {;
  table_add(t, index, value);
}
my_find_or_add :: (table: *Table, key: table.Key_Type) -> *table.Value_Type, found: bool {
  value := table_find_pointer(table, key);
  if value return value, true;

  value = table_add(table, key, .{});
  return value, false;
}







#scope_file
#if OS == .WINDOWS {
  #import "Windows";
  kernel32 :: #foreign_system_library "kernel32";
  stdinhandle: HANDLE;
  ReadConsoleA :: (hConsoleHandle: HANDLE, buff : *u8, chars_to_read : s32,  chars_read : *s32, lpInputControl := *void ) -> BOOL #foreign kernel32;

  #scope_export
  stdin :: (allocator: Allocator = .{}) -> string {
    if !stdinhandle  stdinhandle = GetStdHandle( STD_INPUT_HANDLE );

    MAX_BYTES_TO_READ :: 1024;
    temp : [MAX_BYTES_TO_READ] u8;
    result: string = ---;
    bytes_read : s32;

    if !ReadConsoleA( stdinhandle, temp.data, xx temp.count, *bytes_read ) return "";

    bytes_read -= 2; // remove the \r\n at the end

    result.data  = alloc(bytes_read, allocator);
    result.count = bytes_read;
    memcpy(result.data, temp.data, bytes_read);
    return result;
  }
}
#if OS == .LINUX {
  #import "POSIX";
  #scope_export
  stdin :: (allocator: Allocator = .{}) -> string {
    temp: [4096] u8;
    bytes_read := read(STDIN_FILENO, temp.data, temp.count-1);

    bytes_read -= 1; // remove the \n at the end

    result: string = ---;
    result.data  = alloc(bytes_read, allocator);
    result.count = bytes_read;
    memcpy(result.data, temp.data, bytes_read);
    return result;
  }
}

