extends Node

const WS_ADDR = "ws://127.0.0.1:3500/"
var socket = WebSocketPeer.new()
var HTTP_CODE = {
	100: "Continue",
	200: "OK",
	300: "Redirect",
	400: "Client Error",
	500: "Internal Server Error"
}

var STATUS = {
	0: "STATE_CONNECTING",
	1: "STATE_OPEN",
	2: "STATE_CLOSING",
	3: "STATE_CLOSED"
}
#STATE_CONNECTING = 0
#Socket has been created. The connection is not yet open.
#● STATE_OPEN = 1
#The connection is open and ready to communicate.
#● STATE_CLOSING = 2
#The connection is in the process of closing. This means a close request has been sent to the remote peer but confirmation has not been received.
#● STATE_CLOSED = 3



func _ready():
	socket.connect_to_url(WS_ADDR)

func _process(delta):
	socket.poll()
	var state = socket.get_ready_state()
	$Status_Label.text = "Connection Status:"+ STATUS[state]
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			print("Packet: ", socket.get_packet().get_string_from_utf8())
			$Server_Response.text = str(socket.get_packet())
	
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.



func _on_json_button_pressed() -> void:
	socket.send_text("{'Foo':{'bar':42}}")
	pass # Replace with function body.

func _on_string_button_pressed() -> void:
	socket.send_text("foobar")
	pass # Replace with function body.
