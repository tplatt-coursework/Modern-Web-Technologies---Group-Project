extends Node

signal NET_CodeBox(x)
signal NET_Run
signal NET_VoiceData(data, client_id)
signal client_connected(client_id)

const WS_ADDR = "ws://127.0.0.1:3500/ws"
#const WS_ADDR = "wss://tplatt.cs382.net/ws"
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
	
	# Add a connection monitor timer
	var connection_check_timer = Timer.new()
	connection_check_timer.wait_time = 5.0  # Check connection every 5 seconds
	connection_check_timer.one_shot = false
	connection_check_timer.autostart = true
	connection_check_timer.connect("timeout", _on_connection_check_timeout)
	add_child(connection_check_timer)

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

func _on_connection_check_timeout():
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		# Connection is good, refresh presence if we have a client ID
		if clientID != null:
			# Send a lightweight keep-alive presence announcement
			var payload = {
				"note":"User Present",
				"content":clientID
			}
			socket.send_text(JSON.stringify(payload))
	else:
		# Reduce console spam
		# print("NetworkingNode: Connection check failed - connection not open (state=", state, ")")
		# Try to reconnect if closed
		if state == WebSocketPeer.STATE_CLOSED:
			# Reduce console spam
			# print("NetworkingNode: Attempting to reconnect...")
			socket.connect_to_url(WS_ADDR)

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
	socket.send_text(JSON.stringify(payload))

func send_voice_data(voice_data):
	var payload = {
		"note":"Voice Data",
		"content":voice_data
	}
	socket.send_text(JSON.stringify(payload))

func announce_presence():
	# Send an empty voice packet to announce our presence
	if clientID != null:
		# Reduce console spam
		# print("NetworkingNode: Announcing presence with ID:", clientID)
		
		var payload = {
			"note":"User Present",
			"content":clientID
		}
		
		# Check socket state before sending
		var state = socket.get_ready_state()
		if state != WebSocketPeer.STATE_OPEN:
			# Reduce console spam
			# print("NetworkingNode: Cannot announce presence - connection not open (state=", state, ")")
			return
			
		# Send immediate announcement
		socket.send_text(JSON.stringify(payload))
		
		# Schedule multiple follow-up announcements for reliability
		announce_presence_delayed(0.2, payload)
		announce_presence_delayed(1.0, payload)
		announce_presence_delayed(2.0, payload)
		
		# Directly emit voice data signal to ensure the voice chat system recognizes us
		NET_VoiceData.emit("", clientID)
	else:
		# Reduce console spam
		# print("NetworkingNode: Cannot announce presence - no client ID yet")
		# Try again after getting client ID
		await get_tree().create_timer(1.0).timeout
		if clientID != null:
			announce_presence()

# Helper function to schedule delayed announcements
func announce_presence_delayed(delay_seconds, payload):
	var timer = get_tree().create_timer(delay_seconds)
	await timer.timeout
	
	# Check if socket is still available and open before sending
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(payload))
		# Silence debug message to reduce console spam
		# print("NetworkingNode: Sent delayed presence announcement after ", delay_seconds, " seconds")
	else:
		# Silence debug message to reduce console spam
		# print("NetworkingNode: Skipped delayed presence announcement - connection not open")
		pass

func parse_packet(packet):
	# Disable excessive printing to reduce console spam
	# print()
	var data = null
	
	# Safely parse the packet data
	var packet_text = packet.get_string_from_utf8()
	
	if packet_text.is_empty():
		# Silently handle empty packets
		return
		
	# First try to parse the main packet
	data = JSON.parse_string(packet_text)
	if data == null: 
		# Silent failure for JSON parsing to reduce console spam
		return
		
	# Make sure required fields exist
	if !data.has("code") or !data.has("source") or !data.has("response"):
		# Silent failure for malformed data to reduce console spam
		return
		
	var status = data["code"]
	var source = data["source"]
	var response = null
	
	# Safely try to parse the response
	if typeof(data["response"]) == TYPE_STRING:
		# Skip parsing if the response is empty or contains "Acknowledged"
		if data["response"].is_empty() or data["response"].contains("Acknowledged"):
			if status == "100":
				# Silent handling of acknowledgment messages
				return
			response = {"note": "Acknowledged"}
		else:
			response = JSON.parse_string(data["response"])
		
		# If parsing failed but it's not empty, use the raw string
		if response == null and !data["response"].is_empty():
			# Silently handle unparseable responses
			if status == "201":
				# Create a simple object with note field to pass validation
				response = {"note": "CodeBox Update", "content": data["response"]}
			else:
				# For non-201 status codes with unparseable responses, create a generic object
				response = {"note": "Raw Data", "content": data["response"]}
	else:
		# Silent handling of non-string responses
		return
		
	# Only output status for certain message types to reduce console spam
	if status == "200" and source == "ID Assigner":
		print("main/NetworkingNode: WebSocket Message Received. Status Code: "+str(status))
	elif status == "201" and typeof(response) == TYPE_DICTIONARY and response.has("note"):
		# Only print for certain message types
		if response["note"] == "Voice Data" or response["note"] == "Run Game":
			print("main/NetworkingNode: WebSocket Message Received. Status Code: "+str(status))
	elif status == "500":
		print("main/NetworkingNode: WebSocket Message Received. Status Code: "+str(status))
	
	match str(status):
		"100":
			# Silent handling of continue messages
			pass
		
		"200":
			if source == "ID Assigner":
				clientID = response
				print("main/NetworkingNode: Socket ID assigned to "+str(clientID))
				# Emit signal that client is connected with ID
				client_connected.emit(clientID)
				# Announce our presence to other clients
				announce_presence()
			elif source == "KeepAlive":
				# Silent handling of keep-alive messages
				pass
			else:
				# Silent handling of other 200 responses
				pass
		
		"201":
			if typeof(response) == TYPE_DICTIONARY and response.has("note"):
				if response["note"] == "CodeBox Update" and response.has("content"):
					# print("main/NetworkingNode: Updating Codebox.")
					NET_CodeBox.emit(response["content"])
				elif response["note"] == "Run Game":
					print("main/NetworkingNode: Running.")
					NET_Run.emit()
				elif response["note"] == "Voice Data" and response.has("content"):
					# print("main/NetworkingNode: Voice data received.")
					NET_VoiceData.emit(response["content"], source)
				elif response["note"] == "User Present":
					# print("main/NetworkingNode: User present:", source)
					# Send a response to make sure they see us too
					announce_presence()
					# Emit empty voice data to register the user in the voice chat
					NET_VoiceData.emit("", source)
				else:
					# Silent handling of other note types
					pass
			else:
				# Silent handling of malformed responses
				pass
		
		"500":
			print("main/NetworkingNode: Internal Server Error from WebSocket Connection")
		
		_:
			# Silent handling of unrecognized status codes
			pass
	
