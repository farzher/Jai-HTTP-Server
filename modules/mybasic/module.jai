/* -farzher September 13, 2021
  just a collection of common functions i use
*/

using Basic :: #import "Basic";

#import "String";
mylog :: (args:..Any) {
  if args.count == 0 { print("\n"); return; }

  formatstr: string;
  push_tallocator();
  for args  formatstr = join(formatstr, "% ");
  formatstr[formatstr.count-1] = #char "\n"; // replace the trailing space with a newline
  print(formatstr, ..args);
}



unsafe_cast :: (val: *$T, $type: Type) -> type #expand {
  return <<cast(*type)(val);
}
Cast :: (val: $T, $type: Type) -> type #expand {
  return cast(type)(val);
}


die :: (args: ..Any) {mylog("[die]"); mylog(..args); exit(1); }

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

tjoin :: #bake_arguments join(allocator=tallocator);

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
