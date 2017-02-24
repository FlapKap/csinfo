import socket
import json
HOST_ADDRESS = "localhost"
HOST_PORT = 50000
MSG_BUFFER = 16384

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

s.connect((HOST_ADDRESS, HOST_PORT))

while True:
    stringin = s.recv(MSG_BUFFER)
    jsonin = json.loads(stringin.decode('ascii'))
    parsed = json.dumps(jsonin, sort_keys=True,indent=4)
    print(parsed)
