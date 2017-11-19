function FindProxyForURL(url, host) {

// Normalize the URL for pattern matching
url = url.toLowerCase();
host = host.toLowerCase();

// If the requested website is hosted within the internal network, send direct.
    //if (isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
        //isInNet(dnsResolve(host), "172.16.0.0",  "255.240.0.0") ||
        //isInNet(dnsResolve(host), "192.168.0.0",  "255.255.0.0") ||
        //isInNet(dnsResolve(host), "127.0.0.0", "255.255.255.0"))
    //return "DIRECT";

// Don't proxy public site
    if (dnsDomainIs(host, "www.google.com") )
    return "PROXY 10.255.4.1:3128";

// DEFAULT RULE: All other traffic, send direct.
    return "DIRECT";
}
