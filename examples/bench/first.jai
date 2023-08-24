#import,file "../../module.jai"; // #import "http_server";

main :: () {

  http_listen(port=80);

  get("/", (request: *Request) {; send_html(request, "Hello World"); });

  while 1  sleep_milliseconds(60_000); // uhh, the program just exits instantly without this xxx
}

#import "Basic";
