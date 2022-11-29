







main :: () {
  str := "pants on the ground pants on the ground pants on the ground pants on the ground pants on the ground pants on the ground pants on the ground pants on the ground pants on the ground pants on the ground pants on the ground ";

  compressed := talloc_string(str.count);
  BrotliEncoderCompress(11, 22, 1, xx str.count, xx str.data, xx *compressed.count, xx compressed.data);

  print("%\n", compressed);
  print("%\n", compressed.count);

  // if the compressed string is larger than str.count, compressed will be an empty string ""
}

#import "Basic";
#import,file "../module.jai";
