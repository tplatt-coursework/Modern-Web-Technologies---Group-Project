extends Node2D
var tcp_client = StreamPeerTCP.new()
var server_address = "127.0.0.1"
var server_port = 3500

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var res = tcp_client.connect_to_host(server_address, server_port)
	
	if res == OK:
		print("Connecting...")
		await wait_for_connection()
	else:
		print("Failed to connect")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func tcp_receive(data):
	print("Received: " + data)
	if data.type == "server_message":
		if data.command == "update_button":
			$textField.text = data.data

func tcp_send(data) -> void:
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var message = str(data) + "\n"
		var buffer = message.to_utf8_buffer()
		print("Send: ", message)
		var sent = tcp_client.put_data(buffer)
	else:
		print("Not connected.")
	
	
func wait_for_connection() -> void:
	var timeout = 20.0  # seconds
	var elapsed = 0.0
	while tcp_client.get_status() != StreamPeerTCP.STATUS_CONNECTED and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		tcp_client.poll()
	
	if tcp_client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		print("Connected.")
	else:
		print("Connection timed out.")
	
# the bar button
func _on_button_2_pressed() -> void:
	print("Button Pressed: BAR")
	tcp_send("BAR")


# the foo button
func _on_button_pressed() -> void:
	print("Button Pressed: FOO")
	tcp_send("FOO")


func _on_timer_timeout() -> void:
	print("timer!")
	var status = tcp_client.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if tcp_client.get_available_bytes() > 0:
			var data = tcp_client.get_string()
			print(data)
			var json_data = JSON.parse_string(data)
			if json_data:
				print("Received from server:", json_data)
	else:
		print("Not Connected.")


# Note: This test is run on Godot 4.3
