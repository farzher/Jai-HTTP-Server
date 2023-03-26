/* -farzher September 13, 2021
  some extra windows bindings that i needed
*/



using #import "Windows";

MOD_ALT      :: 0x0001;
MOD_CONTROL  :: 0x0002;
MOD_SHIFT    :: 0x0004;
MOD_WIN      :: 0x0008;
MOD_NOREPEAT :: 0x4000;

WM_HOTKEY                       :: 0x0312;
WM_CLIPBOARDUPDATE              :: 0x031D;

SetForegroundWindow :: (hwnd: HWND) -> BOOL #foreign user32;
SetBkMode :: (hdc: HDC, mode: s32) -> s32 #foreign gdi;

TRANSPARENT :: 1;
OPAQUE      :: 2;


SetLayeredWindowAttributes :: (hwnd: HWND, crkey: COLORREF, balpha: u8, dwflags: DWORD) -> BOOL #foreign user32;
LWA_ALPHA    :: 0x02;
LWA_COLORKEY :: 0x01;


DWM_BB_ENABLE :: 0x00000001;
DWM_BB_BLURREGION :: 0x00000002;
HRGN :: HANDLE;
DWM_BLURBEHIND :: struct {
  dwFlags: DWORD ;
  fEnable: BOOL  ;
  hRgnBlur: HRGN  ;
  fTransitionOnMaximized: BOOL  ;
};
DwmEnableBlurBehindWindow :: (hwnd: HWND, pbb: *DWM_BLURBEHIND) -> HRESULT #foreign Dwmapi;

MARGINS :: struct {
  cxLeftWidth: s32;
  cxRightWidth: s32;
  cyTopHeight: s32;
  cyBottomHeight: s32;
}
DwmExtendFrameIntoClientArea :: (hwnd: HWND, pMarInset: *MARGINS) -> HRESULT #foreign Dwmapi;



TPM_BOTTOMALIGN :: 0x0020;
TPM_LEFTALIGN :: 0x0000;
CreatePopupMenu :: () -> HMENU #foreign user32;
TrackPopupMenu :: (hmenu: HMENU, uflags: u32, x: s32, y: s32, nreserved: s32, hwnd: HWND, prcrect: *RECT) -> BOOL #foreign user32;
InsertMenuW :: (hmenu: HMENU, uposition: u32, uflags: u32, uidnewitem: u64, lpnewitem: LPCWSTR) -> BOOL #foreign user32;


GetMessageW :: (lpMsg: *MSG, hwnd: HWND, wMsgFilterMin: u32, wMsgFilterMax: u32) -> BOOL #foreign user32;

// GetQueuedCompletionStatus :: (CompletionPort: HANDLE, lpNumberOfBytesTransferred: *DWORD, lpCompletionKey: *u64, lpOverlapped: *LPOVERLAPPED, dwMilliseconds: DWORD) -> BOOL
LPOVERLAPPED :: struct {}

KEYEVENTF_EXTENDEDKEY :: 0x0001;
KEYEVENTF_KEYUP       :: 0x0002;

MF_BYPOSITION :: 0x00000400;
MF_STRING :: 0x00000000;

TPM_RETURNCMD :: 0x0100;

INPUT :: struct {
    type: enum DWORD {
        INPUT_MOUSE;
        INPUT_KEYBOARD;
        INPUT_HARDWARE;
    };
    union {
        mi: MOUSEINPUT;
        ki: KEYBDINPUT;
        hi: HARDWAREINPUT;
    }
}
MOUSEINPUT :: struct {
    dx         : s32; // LONG
    dy         : s32; // LONG
    mouseData  : DWORD;
    dwFlags    : DWORD;
    time       : DWORD;
    dwExtraInfo: u64; // ULONG_PTR
}
KEYBDINPUT :: struct {
    wVk        : u16; // WORD
    wScan      : u16; // WORD
    dwFlags    : DWORD;
    time       : DWORD;
    dwExtraInfo: u64; // ULONG_PTR
}
HARDWAREINPUT :: struct {
    uMsg   : DWORD;
    wParamL: u16; // WORD
    wParamH: u16; // WORD
}


PostMessageW :: (hwnd: HWND, msg: u32, wparam:WPARAM, lparam: LPARAM) -> BOOL #foreign user32;


RegisterHotKey :: (hwnd: HWND, id: s32, fsModifiers: u32, vk: u32) -> BOOL #foreign user32;
SendInput :: (cInputs: u32, pInputs: *INPUT, cbSize: s32) -> u32 #foreign user32;
SetFocus :: (hwnd: HWND) -> HWND #foreign user32;

NtSetTimerResolution :: (DesiredResolution: s32, SetResolution: bool = true, CurrentResolution: *s32 = null) -> s32 #foreign ntdll;

AddClipboardFormatListener :: (hwnd: HWND) -> HANDLE #foreign user32;
SetClipboardViewer :: (hwnd: HWND) -> HANDLE #foreign user32;

SetPriorityClass :: (hProcess: HANDLE, dwPriorityClass: DWORD) -> BOOL #foreign kernel32;
// HIGH_PRIORITY_CLASS :: 0x00000080;


// RGBQUAD :: struct {
//     rgbBlue: u8;
//     rgbGreen: u8;
//     rgbRed: u8;
//     rgbReserved: u8;
// }

// BITMAPINFO :: struct {
//     bmiHeader: BITMAPINFOHEADER;
//     bmiColors: [1]RGBQUAD;
// }

// GetObjectW :: (h: HANDLE, c: s32, pv: *void) -> s32 #foreign gdi;

DROPFILES :: struct {
    pFiles: DWORD;
    pt: POINT;
    fNC: BOOL;
    fWide: BOOL;
}

EnumClipboardFormats :: (uFormat: u32) -> u32 #foreign user32;
IsClipboardFormatAvailable :: (uFormat: u32) -> BOOL #foreign user32;

COLORREF :: DWORD;
GetPixel :: (hdc: HDC, x: s32, y: s32) -> COLORREF #foreign gdi;

// HDROP :: HANDLE;
DragQueryFileA :: (hDrop: HDROP, iFire: u32, lpszFile: LPSTR, cch: u32) -> u32 #foreign shell32;
// DragQueryFileW :: (hDrop: HDROP, iFire: u32, lpszFile: LPSTR, cch: u32) -> u32 #foreign shell32;

WM_APP :: 0x8000;

Shell_NotifyIconA :: (dwMessage: DWORD, lpData: *NOTIFYICONDATA) -> BOOL #foreign shell32;
NOTIFYICONDATA :: struct {
  cbSize: DWORD;
  hWnd: HWND  ;
  uID: u32  ;
  uFlags: u32  ;
  uCallbackMessage: u32  ;
  hIcon: HICON ;
  szTip: [128]u8;
  dwState: DWORD ;
  dwStateMask: DWORD ;
  szInfo: [256]u8;
  union {
    uTimeout: u32;
    uVersion: u32;
  }
  szInfoTitle: [64]u8;
  dwInfoFlags: DWORD;
  guidItem: GUID;
  hBalloonIcon: HICON;
}

InsertMenuA :: (hMenu: HMENU, uPosition: u32, uFlags: u32, uIDNewItem: *u32, lpNewItem: LPCSTR = "") -> BOOL #foreign user32;

SetWindowTheme :: (hwnd: HWND, pszSubAppName: LPCWSTR, pszSubIdList: LPCWSTR) #foreign UxTheme;

// DialogBoxParamW :: (hInstance: HINSTANCE, lpTemplate: LPCWSTR, hWndParent: HWND, lpDialogFunc: *void, dwInitParam: LPARAM) -> s32 #foreign user32;

NIF_MESSAGE ::  0x01;
NIF_ICON    ::  0x02;
NIF_TIP     ::  0x04;
NIF_STATE   ::  0x08;
NIF_INFO    ::  0x10;
NIF_GUID    ::  0x20;
NIF_REALTIME::  0x40;
NIF_SHOWTIP ::  0x80;

NIM_ADD :: 0x00;
NIM_SETVERSION :: 0x04;

DwmFlush :: () -> HRESULT #foreign Dwmapi;


ShellExecuteA :: (hwnd: HWND, lpOperation: *u8, lpFile: *u8, lpParmeters: *u8, lpDirectory: *u8, nShowCmd: int) -> s32 #foreign shell32;


#scope_file
ntdll       :: #system_library "Ntdll";
kernel32    :: #system_library "kernel32";
winmm       :: #system_library "winmm";
user32      :: #system_library "user32";
shell32     :: #system_library "shell32";
Crt         :: #system_library "msvcrt";
gdi         :: #system_library "Gdi32";
gl          :: #system_library "opengl32";
Dwmapi      :: #system_library "Dwmapi";
DbgHelp     :: #system_library "DbgHelp";
Advapi32    :: #system_library "Advapi32";
Shlwapi     :: #system_library "shlwapi";
comdlg32    :: #system_library "comdlg32";
UxTheme     :: #system_library "UxTheme";
