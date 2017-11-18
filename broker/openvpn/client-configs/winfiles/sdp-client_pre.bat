@ECHO OFF

fwknop.exe -A udp/1195 --use-hmac -D 10.10.10.10 -s --key-base64-hmac= --key-base64-rijndael=
