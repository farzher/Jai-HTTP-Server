/* -farzher September 13, 2021
  just a collection of common functions i use
*/

using Basic :: #import "Basic";

#import "String";
mylog :: (args: ..Any) {for args print("% ", it); print("\n"); }
die :: (args: ..Any) {mylog("[die]"); mylog(..args); exit(1); }

unsafe_cast :: (val: *$T, $type: Type) -> type #expand {return <<cast(*type)(val); }
Cast :: (val: $T, $type: Type) -> type #expand {return cast(type)(val); }

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
