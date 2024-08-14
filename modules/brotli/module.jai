






// allocates the compressed string!
brotli_compress_text   :: #bake_arguments brotli_compress(mode=BROTLI_MODE_TEXT);
brotli_compress :: (str: string, quality: s32 = 11, lgwin_idkwhatthisis: s32 = 22, mode: BrotliEncoderMode = BROTLI_MODE_GENERIC) -> compressed: string {
  assert(quality >= 1 && quality <= 11);

  compressed := alloc_string(str.count);

  // this call modifies compressed.count
  BrotliEncoderCompress(quality, lgwin_idkwhatthisis, mode, xx str.count, xx str.data, xx *compressed.count, xx compressed.data);

  if !compressed.count {
    // failed to compress. or compressed string was larger than original string
    free(compressed);
    return "";
  }

  // realloc to shrink the compressed buffer to its compressed size
  if compressed.count < str.count {
    compressed.data = realloc(compressed.data, compressed.count, str.count);
  }

  return compressed;
}






#import "Basic";

BROTLI_BOOL :: s32;
using BrotliEncoderMode :: enum s32 {BROTLI_MODE_GENERIC :: 0; BROTLI_MODE_TEXT :: 1; BROTLI_MODE_FONT :: 2;}


#if OS == .LINUX {


    BrotliEncoderCompress :: (
        quality: s32,
        lgwin: s32,
        mode: BrotliEncoderMode,
        input_size: size_t,
        input_buffer: *u8,
        encoded_size: *size_t,
        encoded_buffer: *u8
    ) -> BROTLI_BOOL #foreign brotli;

    #scope_file

    brotli :: #library,no_dll "linux/libbrotli";
    libm :: #system_library,link_always "libm";
    #import "POSIX";




} else {
    // not linux, not implemented

    BrotliEncoderCompress :: (
        quality: s32,
        lgwin: s32,
        mode: BrotliEncoderMode,
        input_size: size_t,
        input_buffer: *u8,
        encoded_size: *size_t,
        encoded_buffer: *u8
    ) -> BROTLI_BOOL {
        <<encoded_size = 0;
        return 0;
    }
}


#scope_file
size_t :: u64;
