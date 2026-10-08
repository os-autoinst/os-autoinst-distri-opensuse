from websocket import create_connection
ws = create_connection("ws://localhost:8000/websocket")
message='hello, world'
print("Sending ",message)
ws.send(message)
print("Sent")
print("Receiving...")
result =  ws.recv()
print("Received '%s'" % result)
ws.close()
assert result == message.upper()
