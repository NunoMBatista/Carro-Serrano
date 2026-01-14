extends Control

@onready var fade_rect: ColorRect = $FadeRect
@onready var credits_label: Label = $CreditsLabel
@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

const NEUTRAL_SONG = "res://assets/audio/base_tracks/neutral_song.mp3"
const FADE_TO_BLACK_DURATION = 5.0
const BLACK_SCREEN_DURATION = 5.0
const CREDITS_SCROLL_DURATION = 30.0
const CREDITS_START_DELAY = 1.0

var _hard_cut_mode: bool = false

var _credits_text = """




ER339: Road to The End of Things




— Created By —




Visuals & Art
Francisco Lapa Silva


Programming & Systems
Nuno Batista


World Building & Design
Miguel Castela


Sound Effects & 3D Modelling
Miguel Martins


Original Soundtrack
Susana Canelo


Young Woman Dialogue Writing
Francisco Lapa Silva


Drunk Man Dialogue Writing
Nuno Batista


Pretentious Man Dialogue Writing
Miguel Castela


Old Man Dialogue Writing
Miguel Martins


Playtesters
Catarina Silva
Mário Bento
Miguel Cabral Pinto
João Nave
Miguel Gonçalves
João Albano



Special Thanks To Our Professors
Licínio Roque and Luís Pereira




Thank you for playing.




"""

func _ready() -> void:
	print("Credits scene _ready() called")
	print("Hard cut mode: ", _hard_cut_mode)

	# Hide crosshair and show/capture mouse
	_hide_crosshair()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Setup fade rect to cover entire screen
	if not fade_rect:
		print("ERROR: FadeRect not found!")
		return

	if _hard_cut_mode:
		fade_rect.color = Color(0, 0, 0, 1)  # Start black for hard cut
		print("Starting with black screen (hard cut)")
	else:
		fade_rect.color = Color(0, 0, 0, 0)  # Start transparent for fade
		print("Starting with transparent screen (smooth fade)")
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Setup credits label - don't use full rect preset, position manually
	if not credits_label:
		print("ERROR: CreditsLabel not found!")
		return

	print("Setting up credits label")
	credits_label.text = _credits_text
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	credits_label.modulate.a = 0.0
	# Set size to match viewport but don't anchor it
	credits_label.size = get_viewport_rect().size
	credits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	print("Credits label text length: ", _credits_text.length())

	# Setup audio player
	if not audio_player:
		print("ERROR: AudioPlayer not created!")
		return

	add_child(audio_player)
	var stream = load(NEUTRAL_SONG)
	if stream:
		audio_player.stream = stream
		print("Neutral song loaded successfully")
	else:
		print("WARNING: Failed to load neutral song")

	# Start the credits sequence
	print("Starting credits sequence...")
	_start_credits_sequence()


func set_hard_cut_mode(hard_cut: bool) -> void:
	"""Set whether to use hard cut (instant) or smooth fade for transitions"""
	_hard_cut_mode = hard_cut


func _start_credits_sequence() -> void:
	print("_start_credits_sequence called, hard_cut_mode: ", _hard_cut_mode)

	if _hard_cut_mode:
		# Hard cut mode: screen is already black, music already stopped
		# Just wait a moment then show credits
		print("Waiting ", BLACK_SCREEN_DURATION, " seconds on black screen...")
		await get_tree().create_timer(BLACK_SCREEN_DURATION).timeout
		print("Starting credits roll (hard cut)")
		_start_credits_roll()
	else:
		# Smooth fade mode: fade to black while fading out music
		var tween = create_tween()
		tween.set_parallel(true)

		# Fade screen to black
		tween.tween_property(fade_rect, "color:a", 1.0, FADE_TO_BLACK_DURATION)

		# Fade out RadioManager music
		if RadioManager.has_method("fade_out"):
			RadioManager.fade_out(FADE_TO_BLACK_DURATION)
		else:
			# Manual fade if method doesn't exist
			tween.tween_method(_fade_radio_volume, 1.0, 0.0, FADE_TO_BLACK_DURATION)

		# Step 2: Wait on black screen
		tween.set_parallel(false)
		tween.tween_callback(func(): pass).set_delay(BLACK_SCREEN_DURATION)

		# Step 3: Start neutral song and fade in credits
		tween.tween_callback(_start_credits_roll)


func _start_credits_roll() -> void:
	print("_start_credits_roll called")

	# Start playing neutral song
	if audio_player and audio_player.stream:
		audio_player.volume_db = -10.0
		audio_player.play()
		print("Playing neutral song")
	else:
		print("WARNING: Cannot play audio - player or stream missing")

	# Wait a moment before starting credits roll
	print("Waiting ", CREDITS_START_DELAY, " seconds before scroll...")
	await get_tree().create_timer(CREDITS_START_DELAY).timeout

	# Position credits below screen
	var viewport_height = get_viewport_rect().size.y
	credits_label.position.y = viewport_height
	print("Positioned credits at y=", viewport_height)

	# Update label size to ensure text wraps properly
	credits_label.size.x = get_viewport_rect().size.x
	credits_label.size.y = 2000  # Give it enough height for all text
	print("Credits label size: ", credits_label.size)

	# Fade in credits
	print("Creating tween for credits animation...")
	var tween = create_tween()
	tween.tween_property(credits_label, "modulate:a", 1.0, 2.0)

	# Scroll credits up from bottom to beyond top
	tween.set_parallel(false)
	var target_y = -credits_label.size.y - 200  # Scroll past all the text
	print("Scrolling from ", viewport_height, " to ", target_y, " over ", CREDITS_SCROLL_DURATION, " seconds")
	tween.tween_property(credits_label, "position:y", target_y, CREDITS_SCROLL_DURATION)

	# After credits finish, fade out and quit
	tween.tween_callback(_credits_finished)
	print("Credits scroll started")


func _credits_finished() -> void:
	print("Credits finished, fading out and quitting...")
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 2.0)
	tween.tween_callback(func():
		print("Quitting game...")
		get_tree().quit()
	)


func _fade_radio_volume(volume: float) -> void:
	# Helper to fade RadioManager volume
	if RadioManager.has_method("set_volume"):
		RadioManager.set_volume(volume)


func _hide_crosshair() -> void:
	# Find and hide the player crosshair
	var root = get_tree().get_current_scene()
	if not root:
		return

	var player_controller = _find_node(root, "PlayerController")
	if player_controller and player_controller.has_node("Control/CrossHair"):
		var crosshair = player_controller.get_node("Control/CrossHair")
		crosshair.visible = false

	var player = _find_node(root, "Player")
	if player and player.has_node("Control/CrossHair"):
		var crosshair = player.get_node("Control/CrossHair")
		crosshair.visible = false


func _find_node(root: Node, node_name: String) -> Node:
	if not root:
		return null
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		if child and child is Node:
			var res = _find_node(child, node_name)
			if res:
				return res
	return null
