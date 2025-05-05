extends Node

signal voice_data_received(data, client_id)

# How often to send voice data (in seconds)
const VOICE_PACKET_INTERVAL = 0.1
var time_since_last_packet = 0.0

# Audio recording variables
var recording = false
var effect: AudioEffectRecord = null
var recording_bus_idx = -1
var mic_active = false
var is_speaking = false

# Speaker dictionaries
var speakers = {}
var active_speakers = []

# Mic status colors
var color_active = Color(0.27, 0.77, 0.35)  # Green
var color_muted = Color(0.8, 0.2, 0.2)      # Red
var color_inactive = Color(0.5, 0.5, 0.5)   # Gray

# UI References
@onready var mic_icon = $VoiceChatPanel/VBoxContainer/MarginContainer3/MicControls/MicIconContainer/MicIcon
@onready var mic_muted_icon = $VoiceChatPanel/VBoxContainer/MarginContainer3/MicControls/MicIconContainer/MicMutedIcon
@onready var mic_button = $VoiceChatPanel/VBoxContainer/MarginContainer3/MicControls/MicButton
@onready var speaking_indicator = $VoiceChatPanel/VBoxContainer/MarginContainer3/MicControls/SpeakingIndicator
@onready var speakers_list = $VoiceChatPanel/VBoxContainer/MarginContainer2/SpeakersList
@onready var empty_speaker = $VoiceChatPanel/VBoxContainer/MarginContainer2/SpeakersList/EmptySpeaker

func _ready():
	print("Voice Chat: Initializing...")
	# Hide the speaking indicator initially
	speaking_indicator.visible = false
	
	# Initialize audio recording
	print("Voice Chat: Setting up audio recording...")
	recording_bus_idx = AudioServer.get_bus_index("Record")
	if recording_bus_idx == -1:
		print("Voice Chat: Creating record bus...")
		recording_bus_idx = AudioServer.bus_count
		AudioServer.add_bus(recording_bus_idx)
		AudioServer.set_bus_name(recording_bus_idx, "Record")
	
	# Add recording effect to the bus
	effect = AudioEffectRecord.new()
	AudioServer.add_bus_effect(recording_bus_idx, effect)
	print("Voice Chat: Recording effect added to bus")
	
	# Connect to networking signals
	if has_node("/root/Main/NetworkingNode"):
		var net_node = get_node("/root/Main/NetworkingNode")
		net_node.connect("NET_VoiceData", _on_voice_data_received)
		# Connect to client ID signal to know when we're connected
		if net_node.clientID != null:
			print("Voice Chat: Already connected with ID: ", net_node.clientID)
			# Announce our presence to the server to make other clients aware
			net_node.announce_presence()
		net_node.connect("client_connected", _on_client_connected)
		print("Voice Chat: Connected to networking node")
	else:
		print("Voice Chat: WARNING - NetworkingNode not found!")
	
	# Set initial mic icon states - show muted by default
	update_mic_state(false)
	
	# Make sure empty speaker message is visible initially
	check_empty_speaker()

func _process(delta):
	if recording:
		time_since_last_packet += delta
		if time_since_last_packet >= VOICE_PACKET_INTERVAL:
			time_since_last_packet = 0.0
			send_voice_data()
		
		# Update our speaking indicator
		speaking_indicator.visible = is_speaking
	
	# Remove any speakers that haven't spoken in a while
	update_speakers_list()
	
	# Update the empty speaker visibility
	check_empty_speaker()

func check_empty_speaker():
	# Show empty speaker only if there are no active speakers
	empty_speaker.visible = (active_speakers.size() == 0)

func _on_mic_button_pressed():
	print("Voice Chat: Mic button pressed")
	var is_active = toggle_mic()
	update_mic_state(is_active)
	print("Voice Chat: Mic active: ", is_active)

func update_mic_state(is_active):
	if is_active:
		mic_button.text = "Mute"
		mic_icon.visible = true
		mic_muted_icon.visible = false
	else:
		mic_button.text = "Unmute"
		mic_icon.visible = false
		mic_muted_icon.visible = true

func toggle_mic():
	if mic_active:
		stop_recording()
		mic_active = false
	else:
		start_recording()
		mic_active = true
	
	return mic_active

func start_recording():
	if effect == null:
		print("Voice Chat: ERROR - Recording effect is null!")
		return
		
	print("Voice Chat: Starting recording...")
	effect.set_recording_active(true)
	recording = true
	print("Voice Chat: Recording started")
	
	# Check if recording was actually enabled
	if !effect.is_recording_active():
		print("Voice Chat: WARNING - Recording did not activate! Make sure microphone permissions are granted.")
		return

func stop_recording():
	if effect == null:
		print("Voice Chat: ERROR - Recording effect is null!")
		return
		
	print("Voice Chat: Stopping recording...")
	effect.set_recording_active(false)
	recording = false
	print("Voice Chat: Recording stopped")
	
	# Hide the speaking indicator when mic is off
	speaking_indicator.visible = false

func send_voice_data():
	if effect == null:
		print("Voice Chat: ERROR - Recording effect is null!")
		return
		
	if !effect.is_recording_active():
		print("Voice Chat: WARNING - Recording not active when trying to send data")
		return
		
	var recording_obj = effect.get_recording()
	if recording_obj == null:
		print("Voice Chat: WARNING - Recording object is null")
		return
		
	var data = recording_obj.get_data()
	if data.size() == 0:
		# Not an error, just no sound data
		return
		
	# Only send if there's actual voice (not just silence)
	var amplitude = get_voice_amplitude(data)
	is_speaking = amplitude > 0.01  # Adjust threshold as needed
	
	if is_speaking:
		print("Voice Chat: Sending voice data, size: ", data.size())
		if has_node("/root/Main/NetworkingNode"):
			var net_node = get_node("/root/Main/NetworkingNode")
			net_node.send_voice_data(data.to_base64_string())
		else:
			print("Voice Chat: ERROR - NetworkingNode not found when trying to send!")
		
	# Reset the recording to avoid accumulating audio
	effect.set_recording_active(false)
	effect.set_recording_active(true)

func get_voice_amplitude(data):
	var sum = 0.0
	for i in range(min(data.size(), 2000)):  # Sample a portion for efficiency
		sum += abs(data[i])
	return sum / min(data.size(), 2000)

func _on_voice_data_received(data_base64, client_id):
	print("Voice Chat: Received voice data from: ", client_id)
	emit_signal("voice_data_received", data_base64, client_id)
	
	# Create speaker if it doesn't exist
	if !speakers.has(client_id):
		var player = AudioStreamPlayer.new()
		add_child(player)
		speakers[client_id] = {"player": player, "last_active": Time.get_ticks_msec(), "label": null}
		
		# Add to UI
		add_speaker_to_ui(client_id)
		
		# Update empty speaker visibility
		check_empty_speaker()
	else:
		# Update last active time
		speakers[client_id]["last_active"] = Time.get_ticks_msec()
		
		# Make speaker active in UI
		update_speaker_ui(client_id, true)
	
	# If data is empty, this is just a presence announcement
	if data_base64.is_empty():
		print("Voice Chat: Received presence announcement from: ", client_id)
		return
	
	# Convert Base64 back to audio data
	var data = Marshalls.base64_to_raw(data_base64)
	
	# Create audio stream from the data
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100  # Standard sample rate
	stream.stereo = false
	stream.data = data
	
	# Play the received audio
	var player = speakers[client_id]["player"]
	player.stream = stream
	player.play()

func add_speaker_to_ui(client_id):
	# Create speaker icon (use same texture as our mic icon)
	var speaker_icon = TextureRect.new()
	speaker_icon.custom_minimum_size = Vector2(16, 16)
	speaker_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	speaker_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Use the mic icon texture
	if mic_icon.texture:
		speaker_icon.texture = mic_icon.texture
	
	# Create speaker label with just the ID prefix
	var speaker_label = Label.new()
	speaker_label.text = client_id.substr(0, 5)
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create speaker container
	var speaker_container = HBoxContainer.new()
	speaker_container.add_child(speaker_icon)
	speaker_container.add_child(speaker_label)
	speaker_container.name = "Speaker_" + client_id
	
	speakers_list.add_child(speaker_container)
	
	speakers[client_id]["label"] = speaker_container
	
	# Add to active speakers
	if !active_speakers.has(client_id):
		active_speakers.append(client_id)

func update_speaker_ui(client_id, is_active):
	if speakers.has(client_id) and speakers[client_id]["label"] != null:
		var container = speakers[client_id]["label"]
		var icon = container.get_child(0)
		
		if is_active:
			icon.modulate = color_active  # Green
		else:
			icon.modulate = color_inactive  # Gray

func update_speakers_list():
	var current_time = Time.get_ticks_msec()
	var speakers_to_remove = []
	
	# Check for inactive speakers (no audio for 5 seconds)
	for client_id in speakers.keys():
		var elapsed = current_time - speakers[client_id]["last_active"]
		
		# If they've been inactive for 5 seconds, update UI
		if elapsed > 5000:
			update_speaker_ui(client_id, false)
		
		# If they've been inactive for 60 seconds, mark for cleanup
		if elapsed > 60000:
			speakers_to_remove.append(client_id)
	
	# Remove very old speakers
	for client_id in speakers_to_remove:
		if speakers.has(client_id) and speakers[client_id]["label"] != null:
			speakers[client_id]["label"].queue_free()
			speakers[client_id]["player"].queue_free()
			speakers.erase(client_id)
			
			# Remove from active speakers
			if active_speakers.has(client_id):
				active_speakers.erase(client_id)
				
	# Update empty speaker visibility after cleanup
	if speakers_to_remove.size() > 0:
		check_empty_speaker() 

func _on_client_connected(client_id):
	print("Voice Chat: Client connected with ID: ", client_id)
	# If this is our first connection, announce our presence
	if has_node("/root/Main/NetworkingNode"):
		var net_node = get_node("/root/Main/NetworkingNode")
		net_node.announce_presence() 
