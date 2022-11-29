libc :: #foreign_system_library "libc";

using EPOLL_EVENTS :: enum_flags u32 {
  EPOLLIN       :: 0x001;
  EPOLLPRI      :: 0x002;
  EPOLLOUT      :: 0x004;
  EPOLLRDNORM   :: 0x040;
  EPOLLRDBAND   :: 0x080;
  EPOLLWRNORM   :: 0x100;
  EPOLLWRBAND   :: 0x200;
  EPOLLMSG      :: 0x400;
  EPOLLERR      :: 0x008;
  EPOLLHUP      :: 0x010;
  EPOLLRDHUP    :: 0x2000;
  EPOLLEXCLUSIVE:: 1 << 28;
  EPOLLWAKEUP   :: 1 << 29;
  EPOLLONESHOT  :: 1 << 30;
  EPOLLET       :: 1 << 31;
};
/* Valid opcodes ( "op" parameter ) to issue to epoll_ctl().  */
EPOLL_CTL_ADD :: 1;        /* Add a file descriptor to the interface.  */
EPOLL_CTL_DEL :: 2;        /* Remove a file descriptor from the interface.  */
EPOLL_CTL_MOD :: 3;        /* Change file descriptor epoll_event structure.  */


epoll_data :: struct {
  union {
    ptr: *void;
    fd: s32;
    _u32: u32;
    _u64: u64;
  }
};

epoll_event :: struct {
  events: EPOLL_EVENTS;        /* Epoll events */
  data: epoll_data;   /* User data variable */
};

epoll_create  :: (size: s32) -> s32 #foreign libc;
epoll_create1 :: (flags: s32) -> s32 #foreign libc;
epoll_ctl     :: (epfd: s32, op: s32, fd: s32, event: *epoll_event) -> s32 #foreign libc;
epoll_wait    :: (epfd: s32, events: *epoll_event, maxevents: s32, timeout: s32) -> s32 #foreign libc;
epoll_pwait   :: (epfd: s32, events: *epoll_event, maxevents: s32, timeout: s32, ss: *__sigset_t) -> s32 #foreign libc;

// _SIGSET_NWORDS :: (1024 / (8 * size_of(u32)));
// __sigset_t :: struct {
//   __val: [_SIGSET_NWORDS]u32;
// }

#import "POSIX";
