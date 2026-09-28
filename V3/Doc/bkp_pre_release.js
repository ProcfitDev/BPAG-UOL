console.log(request.headers);
var canonical = request.method;

if(!request.headers["content-type"]){
    canonical += "\n";
}
if(!request.headers["content-md5"]){
    canonical += "\n";
}

for(var h in request.headers)  {
    if(h == "content-type" || h == "content-md5" || h == "date") {
        canonical += "\n" + request.headers[h];
    } else if (h.indexOf("x-uol-") >= 0){
        canonical += "\n" + h + ":" + request.headers[h];
    }
}

var urlParts = /^(?:\w+\:\/\/)?([^\/]+)(.*)$/.exec(request.url);

canonical += "\n" + urlParts[2];

console.log(canonical);
console.log(pm.environment.get("gibraltar-secret-key"));

var hmac = CryptoJS.HmacSHA256(canonical, pm.environment.get("gibraltar-secret-key"));

console.log(hmac);

var base64 = CryptoJS.enc.Base64.stringify(hmac);

console.log(base64);

pm.environment.set("gibraltar-auth", 
"UOLWS " + pm.environment.get("gibraltar-access-id") + ":" + base64 + ":S2:0.2");

console.log(pm.environment.get("gibraltar-auth"));