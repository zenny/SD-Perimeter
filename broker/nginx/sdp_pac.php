<?php
header("Content-type: application/x-ns-proxy-autoconfig");
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");

$servername = "localhost";
$username = "sdpuser";
$password = "sdpdbpass";
$dbname = "sdpdb";

$clientip = getenv("REMOTE_ADDR");

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);
// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

$query_user = "SELECT user_id from squid_user_helper where log_remote_ip='$clientip'";
$pac_user_result = $conn->query($query_user);
$pac_user = $pac_user_result->fetch_assoc(); 
$pac_user_name = $pac_user['user_id'];

$query_domains = "SELECT GROUP_CONCAT(CONCAT('dnsDomainIs(host,\"',r.address_domain,'\")') SEPARATOR ' ||\n        ') domains FROM squid_rules_helper r, squid_group_helper u WHERE u.user='$pac_user_name' and u.ugroup = r.ugroup_name";
$query_proxy = "SELECT gateway_ip from gateway where gateway_name='sdp-broker'";

$pac_domains_result = $conn->query($query_domains);
$pac_proxy_result = $conn->query($query_proxy);

$pac_domains_assoc = $pac_domains_result->fetch_assoc();
$pac_proxy_assoc = $pac_proxy_result->fetch_assoc();

?>
//PAC file for <?php echo $clientip; ?>, <?php echo $pac_user['user_id'] ?> from <?php echo gethostname(); ?>

function FindProxyForURL(url, host) {

    //Normalize the URL for pattern matchin
    url = url.toLowerCase();
    host = host.toLowerCase();

    //Resources to proxy
    if (<?php echo $pac_domains_assoc['domains'] ?>)
    return "PROXY 10.255.4.1:3128";

    // All other traffic send direct.
    return "DIRECT";

}
