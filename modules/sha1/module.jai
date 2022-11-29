/*******************************************************************************
 * Teeny SHA-1
 *
 * The below sha1digest() calculates a SHA-1 hash value for a
 * specified data buffer and generates a hex representation of the
 * result.  This implementation is a re-forming of the SHA-1 code at
 * https://github.com/jinqiangshou/EncryptionLibrary.
 *
 * Copyright (c) 2017 CTrabant
 *
 * License: MIT, see included LICENSE file for details.
 *
 * To use the sha1digest() function either copy it into an existing
 * project source code file or include this file in a project and put
 * the declaration (example below) in the sources files where needed.
 ******************************************************************************/

sha1_binary :: (data: string) -> [20] u8 {

  SHA1ROTATELEFT :: inline (value: $T, bits: T) -> T {
    return (((value) << (bits)) | ((value) >> (32 - (bits))));
  }

  W : [80] u32;
  H := u32.[0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0];
  a: u32;
  b: u32;
  c: u32;
  d: u32;
  e: u32;
  f: u32;
  k: u32;

  idx : u32;
  widx : u32;
  didx : u32;

  wcount: s32;
  temp: u32;
  databits : u64 = (cast(u64)data.count) * 8;
  loopcount : u32 = (cast(u32)data.count + 8) / 64 + 1;
  tailbytes : u32 = 64 * loopcount - cast(u32)data.count;
  datatail : [128] u8;


  /* Pre-processing of data tail (includes padding to fill out 512-bit chunk):
     Add bit '1' to end of message (big-endian)
     Add 64-bit message length in bits at very end (big-endian) */
  datatail[0] = 0x80;
  datatail[tailbytes - 8] = cast(u8) (databits >> 56 & 0xFF);
  datatail[tailbytes - 7] = cast(u8) (databits >> 48 & 0xFF);
  datatail[tailbytes - 6] = cast(u8) (databits >> 40 & 0xFF);
  datatail[tailbytes - 5] = cast(u8) (databits >> 32 & 0xFF);
  datatail[tailbytes - 4] = cast(u8) (databits >> 24 & 0xFF);
  datatail[tailbytes - 3] = cast(u8) (databits >> 16 & 0xFF);
  datatail[tailbytes - 2] = cast(u8) (databits >> 8 & 0xFF);
  datatail[tailbytes - 1] = cast(u8) (databits >> 0 & 0xFF);

  /* Process each 512-bit chunk */
  for 0 .. loopcount-1 {
    /* Compute all elements in W */
    memset (*W, 0, size_of(type_of(W)));

    /* Break 512-bit chunk into sixteen 32-bit, big endian words */
    widx = 0; while widx <= 15 { defer widx += 1;
      wcount = 24;

      /* Copy byte-per byte from specified buffer */
      while (didx < data.count && wcount >= 0)
      {
        W[widx] += ((cast(u32)data[didx]) << wcount);
        didx+=1;
        wcount -= 8;
      }
      /* Fill out W with padding as needed */
      while (wcount >= 0)
      {
        W[widx] += ((cast(u32)datatail[didx - data.count]) << wcount);
        didx+=1;
        wcount -= 8;
      }
    }

    /* Extend the sixteen 32-bit words into eighty 32-bit words, with potential optimization from:
       "Improving the Performance of the Secure Hash Algorithm (SHA-1)" by Max Locktyukhin */
    widx = 16; while widx <= 31 { defer widx+=1;
      W[widx] = SHA1ROTATELEFT ((W[widx - 3] ^ W[widx - 8] ^ W[widx - 14] ^ W[widx - 16]), 1);
    }
    widx = 32; while widx <= 79 { defer widx+=1;
      W[widx] = SHA1ROTATELEFT ((W[widx - 6] ^ W[widx - 16] ^ W[widx - 28] ^ W[widx - 32]), 2);
    }

    /* Main loop */
    a = H[0];
    b = H[1];
    c = H[2];
    d = H[3];
    e = H[4];

    idx = 0; while idx <= 79 { defer idx+=1;
      if (idx <= 19)
      {
        f = (b & c) | ((~b) & d);
        k = 0x5A827999;
      }
      else if (idx >= 20 && idx <= 39)
      {
        f = b ^ c ^ d;
        k = 0x6ED9EBA1;
      }
      else if (idx >= 40 && idx <= 59)
      {
        f = (b & c) | (b & d) | (c & d);
        k = 0x8F1BBCDC;
      }
      else if (idx >= 60 && idx <= 79)
      {
        f = b ^ c ^ d;
        k = 0xCA62C1D6;
      }
      temp = SHA1ROTATELEFT (a, 5) + f + e + k + W[idx];
      e = d;
      d = c;
      c = SHA1ROTATELEFT (b, 30);
      b = a;
      a = temp;
    }

    H[0] += a;
    H[1] += b;
    H[2] += c;
    H[3] += d;
    H[4] += e;
  }

  digest: [20] u8;
  // idx = 0; while idx < 5 { defer idx += 1;
  for idx: 0..5-1 {
    digest[idx * 4 + 0] = cast,no_check(u8) (H[idx] >> 24);
    digest[idx * 4 + 1] = cast,no_check(u8) (H[idx] >> 16);
    digest[idx * 4 + 2] = cast,no_check(u8) (H[idx] >> 8);
    digest[idx * 4 + 3] = cast,no_check(u8) (H[idx]);
  }
  return digest;
}
sha1_string :: (data: string, allocator: Allocator = temp) -> string {
  digest := sha1_binary(data);
  hex := alloc_string(size_of(type_of(digest)) << 1, allocator=allocator);
  for digest {
    hexbytes := byte2hexstr(it);
    hex[it_index*2+0] = hexbytes[0];
    hex[it_index*2+1] = hexbytes[1];
  }
  return hex;

  byte2hexstr :: (n: u8) -> [2] u8 { // should only accept u_ints
    digits :: "0123456789ABCDEF";
    hex_len :: size_of(type_of(n)) << 1;
    result: [2] u8;
    i := 0;
    j := (hex_len-1)*4;
    while i<hex_len { defer {i+=1; j-=4;}
      result[i] = digits[(n>>j) & 0x0f];
    }
    return result;
  }
}
#import "Basic";


// main :: () {
//   idk := sha1_string("sup");
//   print("%\n", idk);
// }
