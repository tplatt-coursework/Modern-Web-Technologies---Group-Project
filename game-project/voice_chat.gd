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

# Local audio playback (for hearing yourself)
var local_audio_player = null
var local_audio_enabled = false  # Set to false to disable hearing yourself
var visual_feedback_enabled = true  # Enable visual feedback by default
var feedback_tone_enabled = false  # Enable subtle feedback tone (not your voice)
var is_web_mode = false  # Track if we're in web mode
var web_mic_permission_requested = false
var web_mic_permission_granted = false
var web_error_count = 0
var web_error_threshold = 10

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
	
	# Check if we're running in web mode
	is_web_mode = OS.get_name() == "HTML5"
	
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
	
	# Initialize local audio playback
	local_audio_player = AudioStreamPlayer.new()
	add_child(local_audio_player)
	print("Voice Chat: Local audio player initialized")
	print("Voice Chat: Local audio feedback is DISABLED by default")
	print("Voice Chat: Use the speaking indicator for visual feedback")
	
	# Web mode - simplify UI and automatically enable microphone after a delay
	if is_web_mode:
		print("Voice Chat: Web mode detected - using simplified controls")
		$VoiceChatPanel/VBoxContainer/WebMessage.visible = true
		# Hide complex controls in web mode
		$VoiceChatPanel/VBoxContainer/WebButtonControls.visible = false
		
		# Display browser-specific instructions
		$VoiceChatPanel/VBoxContainer/WebMessage.text = "Click 'Allow' when browser asks for microphone permission"
		$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1, 1.0))
		
		# Add status update timer for web mode
		var status_timer = Timer.new()
		status_timer.wait_time = 2.0
		status_timer.one_shot = false
		status_timer.connect("timeout", _on_web_status_update)
		add_child(status_timer)
		status_timer.start()
		
		# Setup permission request timer with a slight delay
		var permission_timer = Timer.new()
		permission_timer.wait_time = 1.0
		permission_timer.one_shot = true
		permission_timer.connect("timeout", _on_browser_permission_request)
		add_child(permission_timer)
		permission_timer.start()
	else:
		# Desktop mode - use all controls
		$VoiceChatPanel/VBoxContainer/WebMessage.visible = false
		$VoiceChatPanel/VBoxContainer/WebButtonControls.visible = false
	
	# Show initial feedback message
	show_feedback_message("Voice feedback: Visual indicator ENABLED, Audio feedback DISABLED")
	
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
	
	# Start heartbeat timer to keep connections alive - more frequent (3 seconds)
	var heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 3.0  # Send heartbeat every 3 seconds
	heartbeat_timer.one_shot = false
	heartbeat_timer.autostart = true
	heartbeat_timer.connect("timeout", _on_heartbeat_timer_timeout)
	add_child(heartbeat_timer)
	
	# Also add a backup safety timer that forcibly refreshes speakers
	var safety_timer = Timer.new()
	safety_timer.wait_time = 10.0  # Force refresh every 10 seconds
	safety_timer.one_shot = false
	safety_timer.autostart = true
	safety_timer.connect("timeout", _on_safety_timer_timeout)
	add_child(safety_timer)

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
		# Reduce console spam
		# print("Voice Chat: ERROR - Recording effect is null!")
		return
		
	if !effect.is_recording_active():
		# Reduce console spam
		# print("Voice Chat: WARNING - Recording not active when trying to send data")
		return
		
	var recording_obj = effect.get_recording()
	if recording_obj == null:
		web_error_count += 1
		
		# Only log every few errors to avoid console spam
		if web_error_count % 50 == 0:  # Increased from 10 to 50 for less frequent logging
			print("Voice Chat: WARNING - Recording object is null (count: " + str(web_error_count) + ")")
			
		# If we hit the error threshold in web mode, show a message and try to reset
		if is_web_mode and web_error_count >= web_error_threshold and web_error_count % web_error_threshold == 0:
			print("Voice Chat: Attempting to reset recording after repeated errors")
			$VoiceChatPanel/VBoxContainer/WebMessage.text = "Microphone not working. Try reloading page"
			$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
			
			# Try to reset the recording
			effect.set_recording_active(false)
			await get_tree().create_timer(0.5).timeout
			effect.set_recording_active(true)
		return
		
	var data = recording_obj.get_data()
	if data.size() == 0:
		# Not an error, just no sound data
		return
		
	# Reset error count since we successfully got data
	web_error_count = 0
		
	# Only send if there's actual voice (not just silence)
	var amplitude = get_voice_amplitude(data)
	var was_speaking = is_speaking
	is_speaking = amplitude > 0.01  # Adjust threshold as needed
	
	# If this is first successful voice detection in web mode, update the UI
	if is_web_mode and is_speaking and !web_mic_permission_granted:
		web_mic_permission_granted = true
		$VoiceChatPanel/VBoxContainer/WebMessage.text = "Microphone working!"
		$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1.0))
	
	# Update speaking indicator
	if visual_feedback_enabled:
		speaking_indicator.visible = is_speaking
		
		# Make speaking indicator pulse when active
		if is_speaking and not was_speaking:
			var tween = create_tween()
			tween.tween_property(speaking_indicator, "modulate", Color(1, 1, 1, 1), 0.1)
			tween.tween_property(speaking_indicator, "modulate", Color(0.8, 1, 0.8, 0.8), 0.2)
			tween.set_loops(2)
	
	if is_speaking:
		# Reduce console spam
		# print("Voice Chat: Sending voice data, size: ", data.size())
		if has_node("/root/Main/NetworkingNode"):
			var net_node = get_node("/root/Main/NetworkingNode")
			net_node.send_voice_data(data.to_base64_string())
			
			# Play audio locally only if explicitly enabled by the user
			if local_audio_enabled:
				play_local_audio(data)
			# Play feedback tone if enabled (very subtle "click" sound)
			elif feedback_tone_enabled and not was_speaking:
				play_feedback_tone()
		else:
			# Reduce console spam
			# print("Voice Chat: ERROR - NetworkingNode not found when trying to send!")
			pass
		
	# Reset the recording to avoid accumulating audio
	effect.set_recording_active(false)
	effect.set_recording_active(true)

func get_voice_amplitude(data):
	var sum = 0.0
	for i in range(min(data.size(), 2000)):  # Sample a portion for efficiency
		sum += abs(data[i])
	return sum / min(data.size(), 2000)

func play_local_audio(audio_data):
	# Only play local audio if the feature is enabled
	if !local_audio_enabled:
		return
		
	# Create an audio stream from the data for local playback
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100  # Standard sample rate
	stream.stereo = false
	stream.data = audio_data
	
	# Play the audio locally
	local_audio_player.stream = stream
	local_audio_player.volume_db = -10  # Lower volume for local feedback to avoid echo
	local_audio_player.play()

func _on_voice_data_received(data_base64, client_id):
	# Reduce console spam
	# print("Voice Chat: Received voice data from: ", client_id)
	emit_signal("voice_data_received", data_base64, client_id)
	
	# Check if this is our own clientID - we might be getting our own voice data back
	if has_node("/root/Main/NetworkingNode"):
		var net_node = get_node("/root/Main/NetworkingNode")
		if client_id == net_node.clientID:
			# Reduce console spam
			# print("Voice Chat: Ignoring own voice data")
			return
	
	# Create speaker if it doesn't exist
	if !speakers.has(client_id):
		var player = AudioStreamPlayer.new()
		add_child(player)
		speakers[client_id] = {"player": player, "last_active": Time.get_ticks_msec(), "label": null}
		
		# Add to UI
		add_speaker_to_ui(client_id)
		
		# Update empty speaker visibility
		check_empty_speaker()
		
		# Reduce console spam
		# print("Voice Chat: Added new speaker to UI: ", client_id)
	else:
		# Update last active time
		speakers[client_id]["last_active"] = Time.get_ticks_msec()
		
		# Make speaker active in UI
		update_speaker_ui(client_id, true)
	
	# If data is empty, this is just a presence announcement
	if data_base64.is_empty():
		# Reduce console spam
		# print("Voice Chat: Received presence announcement from: ", client_id)
		# Respond back to ensure bidirectional awareness
		if has_node("/root/Main/NetworkingNode"):
			var net_node = get_node("/root/Main/NetworkingNode")
			net_node.announce_presence()
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
	
	# Don't remove speakers, just update their UI state
	for client_id in speakers.keys():
		var elapsed = current_time - speakers[client_id]["last_active"]
		
		# If they've been inactive for 2 minutes, only update UI
		if elapsed > 120000:
			update_speaker_ui(client_id, false)
		else:
			update_speaker_ui(client_id, true)
		
		# NEVER automatically remove speakers - let the server handle this

func _on_client_connected(client_id):
	print("Voice Chat: Client connected with ID: ", client_id)
	# If this is our first connection, announce our presence
	if has_node("/root/Main/NetworkingNode"):
		var net_node = get_node("/root/Main/NetworkingNode")
		net_node.announce_presence() 

func _on_heartbeat_timer_timeout():
	# Send a heartbeat to keep all connections active
	if has_node("/root/Main/NetworkingNode"):
		var net_node = get_node("/root/Main/NetworkingNode")
		if net_node.clientID != null:
			# Reduce console spam
			# print("Voice Chat: Sending heartbeat")
			net_node.announce_presence()
	
	# Also refresh the UI for all speakers - this is crucial to keep them visible
	var current_time = Time.get_ticks_msec()
	for client_id in speakers.keys():
		# Keep all speakers active by refreshing their last_active timestamp
		speakers[client_id]["last_active"] = current_time
		update_speaker_ui(client_id, true)
	
	# Also check if we need to update the empty speaker message
	check_empty_speaker()

# Toggle local audio feedback
func toggle_local_audio():
	local_audio_enabled = !local_audio_enabled
	print("Voice Chat: Local audio feedback set to: ", local_audio_enabled)
	return local_audio_enabled 

func _input(event):
	# Only handle keyboard input in desktop mode
	if is_web_mode:
		return
		
	# Add keyboard shortcut to toggle local audio feedback with the 'L' key
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		var is_enabled = toggle_local_audio()
		# Show temporary visual feedback
		var feedback_text = "Voice local feedback: " + ("ON" if is_enabled else "OFF")
		print(feedback_text)
		show_feedback_message(feedback_text)
	
	# Add keyboard shortcut to toggle feedback tone with the 'T' key
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		feedback_tone_enabled = !feedback_tone_enabled
		var feedback_text = "Voice tone feedback: " + ("ON" if feedback_tone_enabled else "OFF")
		print(feedback_text)
		show_feedback_message(feedback_text)
		
	# Add keyboard shortcut to toggle visual feedback with the 'V' key
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		visual_feedback_enabled = !visual_feedback_enabled
		var feedback_text = "Visual feedback: " + ("ON" if visual_feedback_enabled else "OFF")
		print(feedback_text)
		show_feedback_message(feedback_text)

func show_feedback_message(text):
	# Create a temporary label for feedback
	var feedback = Label.new()
	feedback.text = text
	feedback.position = Vector2(20, 140)  # Position below the voice chat panel
	feedback.modulate = Color(1, 1, 1, 1)
	add_child(feedback)
	
	# Animate fading out
	var tween = create_tween()
	tween.tween_property(feedback, "modulate", Color(1, 1, 1, 0), 2.0)
	tween.tween_callback(feedback.queue_free)

func _on_safety_timer_timeout():
	# Reduce console spam
	# print("Voice Chat: Running safety refresh of speakers")
	
	# Force refresh all known speakers
	for client_id in speakers.keys():
		# Keep all speakers active for a longer period
		speakers[client_id]["last_active"] = Time.get_ticks_msec()
		update_speaker_ui(client_id, true)
	
	# Request a fresh presence announcement from all clients
	if has_node("/root/Main/NetworkingNode"):
		var net_node = get_node("/root/Main/NetworkingNode")
		if net_node.clientID != null:
			net_node.announce_presence()
	
	# Ensure empty speaker message is updated
	check_empty_speaker()

# Play a subtle tone to indicate voice is being detected
func play_feedback_tone():
	# Create a very short, subtle tone
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	# Generate a short, subtle "click" sound
	var data = []
	for i in range(0, 4000):
		var value = 0
		if i < 100:
			value = sin(i * 0.3) * 0.3 * (100 - i) / 100.0
		data.append(int(value * 32767))
	
	stream.data = PackedByteArray(data)
	
	# Play at very low volume
	local_audio_player.stream = stream
	local_audio_player.volume_db = -25
	local_audio_player.play()

func _on_browser_permission_request():
	if !is_web_mode:
		return
	
	print("Voice Chat: Browser - requesting microphone permission")
	$VoiceChatPanel/VBoxContainer/WebMessage.text = "Requesting microphone access..."
	web_mic_permission_requested = true
	
	# In web mode, attempt to activate the microphone automatically
	start_recording()
	
	# Check if it was successful
	if effect != null && effect.is_recording_active():
		print("Voice Chat: Browser - microphone permission granted")
		web_mic_permission_granted = true
		mic_active = true
		update_mic_state(true)
		$VoiceChatPanel/VBoxContainer/WebMessage.text = "Microphone active"
		$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1.0))
	else:
		print("Voice Chat: Browser - microphone permission denied or error")
		web_mic_permission_granted = false
		mic_active = false
		update_mic_state(false)
		$VoiceChatPanel/VBoxContainer/WebMessage.text = "Could not access microphone. Click mic icon to try again."
		$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))

func _on_web_status_update():
	if !is_web_mode:
		return
	
	# Check if we're connected to the server
	if has_node("/root/Main/NetworkingNode"):
		var net_node = get_node("/root/Main/NetworkingNode")
		if net_node.clientID != null:
			print("Voice Chat: Web status update - connected to server")
			$VoiceChatPanel/VBoxContainer/WebMessage.text = "Connected to server"
			$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3, 1.0))
		else:
			print("Voice Chat: Web status update - not connected to server")
			$VoiceChatPanel/VBoxContainer/WebMessage.text = "Not connected to server"
			$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
	else:
		print("Voice Chat: Web status update - NetworkingNode not found")
		$VoiceChatPanel/VBoxContainer/WebMessage.text = "NetworkingNode not found"
		$VoiceChatPanel/VBoxContainer/WebMessage.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
