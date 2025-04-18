extends Node

signal NET_CodeBox(x)
signal NET_Run

#const WS_ADDR = "ws://127.0.0.1:3500/"
const WS_ADDR = "ws://node:3500/"
var socket = WebSocketPeer.new()
var clientID = null
var reconnect_attempts = 3

var WS_STATUS = {
	0: "STATE_CONNECTING", # Socket has been created. The connection is not yet open.
	1: "STATE_OPEN",       # The connection is open and ready to communicate.
	2: "STATE_CLOSING",    # The connection is in the process of closing. This means a close request has been sent to the remote peer but confirmation has not been received.
	3: "STATE_CLOSED"      # The connection is closed.
}


func _ready():
	socket.connect_to_url(WS_ADDR)

func _process(delta):
	socket.poll()
	var state = socket.get_ready_state()
	$Connection_Status.text = WS_STATUS[state]
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			parse_packet(socket.get_packet())
	
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.
		$ReconnectTimer.start()

func _on_reconnect_timer_timeout() -> void:
	$ReconnectTimer.stop()
	if reconnect_attempts==0:
		$Connection_Status.text = "Failed to connect. Restart the application and server and try again."
		return
	reconnect_attempts -= 1
	$Connection_Status.text = "Attempting to reconnect..."
	socket.connect_to_url(WS_ADDR)
	await get_tree().create_timer(5.0).timeout
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		set_process(true)
	else:
		$Connection_Status.text = "Connection timed out."
		$ReconnectTimer.start()


func send_run():
	var payload = {
		"note":"Run Game"
	}
	socket.send_text(JSON.stringify(payload))
	
func send_codebox(message):
	var payload = {
		"note":"CodeBox Update",
		"content":str(message)
	}
	socket.send_text(payload)



func parse_packet(packet):
	print()
	var data = JSON.parse_string(packet.get_string_from_utf8())
	if data == null: 
		print("main/NetworkingNode: Error: Failed to parse data: "+str(packet.get_string_from_utf8()))
		return
	var status   = data["code"]
	var source   = data["source"] 
	var response = JSON.parse_string(data["response"]) #this is awful... json doesnt play nice
	print("main/NetworkingNode: WebSocket Message Received. Status Code: "+str(status))
	
	match str(status):
		"100":
			print("main/NetworkingNode: Continue.")
		
		"200":
			if source == "ID Assigner":
				clientID = response
				print("main/NetworkingNode: Socket ID assigned to "+str(clientID))
			else:
				print("main/NetworkingNode: Response:"+str(response))
		
		"201":
			if response["note"]!=null :
				if response["note"] == "CodeBox Update" && response["content"] != null:
					print("main/NetworkingNode: Updating Codebox.")
					NET_CodeBox.emit(response["content"])
				elif response["note"] == "Run Game":
					print("main/NetworkingNode: Running.")
					NET_Run.emit()
				else:print("main/NetworkingNode: Message Not Foratted Properly.")
			else:print("main/NetworkingNode: Message Not Foratted Properly.")
		
		"500":
			print("main/NetworkingNode: Internal Server Error from WebSocket Connection")
		
		_:
			print("main/NetworkingNode: Unrecognized Status Code: "+str(status))
		
	
