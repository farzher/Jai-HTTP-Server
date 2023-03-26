


#import,file "../../module.jai"; // #import "http_server";

main :: () {

  http_listen(port=80);

  static(".");

  while 1  sleep_milliseconds(60_000); // uhh, the program just exits instantly without this xxx
}



#import "Basic";
mylog :: (args: ..Any) {for args print("% ", it); print("\n"); }
