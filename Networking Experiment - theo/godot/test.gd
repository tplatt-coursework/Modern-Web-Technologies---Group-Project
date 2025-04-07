extends Node2D
var tcp_client = StreamPeerTCP.new()
var server_address = "127.0.0.1"
var server_port = 3500
var first_connect = true
var HTTP_CODE = {
	100: "Continue",
	200: "OK",
	300: "Redirect",
	400: "Client Error",
	500: "Internal Server Error"
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass





func tcp_receive(bytes):
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var data = tcp_client.get_data(bytes)
		if data[0]!=0: 
			print("Error in reading data")
		else:
			var response = data[1].get_string_from_utf8()
			var json = JSON.parse_string(response)
			print("Websocket Data Received")
			print("  Code:     "+str(json["code"])+" "+HTTP_CODE[200])
			print("  Response: "+str(json["response"]))
			print()

	else:
		print("Not connected.")



func tcp_send(data) -> void:
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var message = str(data) + "\n"
		var buffer = message.to_utf8_buffer()
		tcp_client.put_data(buffer)
	else:
		print("Not connected.")




func tcp_connect():
	var res = tcp_client.connect_to_host(server_address, server_port)
	if res == OK:
		if first_connect: 
			print("Connecting...")
		else:
			print("Attempting to reconnect...")
		await wait_for_connection()
		
		
	else:
		print("Failed to connect")

func wait_for_connection() -> void:
	var timeout = 5.0  # seconds
	var elapsed = 0.0
	while tcp_client.get_status() != StreamPeerTCP.STATUS_CONNECTED and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		print("Connected.")
		first_connect=false
	else:
		print("Connection timed out.")
		tcp_client.disconnect_from_host()
		await get_tree().create_timer(10).timeout
	$Network_Timer.start()





func _on_timer_timeout() -> void:
	tcp_client.poll()
	var status = tcp_client.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		var bytes_available = tcp_client.get_available_bytes()
		if bytes_available > 0:
			tcp_receive(bytes_available)
	elif status == StreamPeerTCP.STATUS_NONE:
		tcp_connect()





func _on_button_2_pressed() -> void:
	print("Button Pressed: FOO")
	tcp_send("foobar")

func _on_button_pressed() -> void:
	
	print("Button Pressed: BAR")
	tcp_send({"Foo":{"bar":42}})

# Note: This test is run on Godot 4.3
