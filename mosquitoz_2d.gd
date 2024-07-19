extends Node2D

var score = 0
var active_mosquito = -1
var mosquitoes = []
var score_label: Label
var game_over_label: Label
var restart_button: Button
var start_button: Button
var game_timer: Timer
var game_over_background: ColorRect
var mosquito_textures = []
var background_texture: Texture2D
var blood_texture: Texture2D
var color_change_duration = 2.0
var color_change_time = 0.0
var cell_size: Vector2
var game_active = false
var top_scores = []
var screen_size: Vector2
var title_label: Label
var shake_time = 0.0
var shake_duration = 0.1
var shake_intensity = 4.0
var min_mosquito_lifetime = 0.3
var vibration_duration = 50
var last_active_mosquito = -1
var mosquito_scale_factor = 1.2

func _ready():
	randomize()
	load_textures()
	setup_screen_size()
	create_start_screen()

func load_textures():
	for i in range(1, 4):
		var texture = load("res://assets/mosquito" + str(i) + ".png")
		if texture == null:
			print("Failed to load mosquito" + str(i) + " texture!")
			var image = Image.new()
			image.create(64, 64, false, Image.FORMAT_RGBA8)
			image.fill(Color.RED)
			texture = ImageTexture.create_from_image(image)
		mosquito_textures.append(texture)
	
	if mosquito_textures.is_empty():
		print("No mosquito textures loaded!")
		var image = Image.new()
		image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.RED)
		mosquito_textures.append(ImageTexture.create_from_image(image))
	
	background_texture = load("res://assets/sky.png")
	if background_texture == null:
		print("Failed to load background texture!")
		var image = Image.new()
		image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.SKY_BLUE)
		background_texture = ImageTexture.create_from_image(image)
	
	blood_texture = load("res://assets/blood.png")
	if blood_texture == null:
		print("Failed to load blood texture!")
		var image = Image.new()
		image.create(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(Color.DARK_RED)
		blood_texture = ImageTexture.create_from_image(image)

func setup_screen_size():
	screen_size = get_viewport().size
	cell_size = Vector2(screen_size.x / 3.0, screen_size.y / 6.0)

func create_background():
	var background = TextureRect.new()
	background.texture = background_texture
	background.expand = true
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size = screen_size
	add_child(background)

func create_start_screen():
	clear_screen()
	
	create_background()
	
	title_label = Label.new()
	title_label.text = "Mosquitoz"
	title_label.add_theme_color_override("font_color", Color.RED)
	title_label.add_theme_font_size_override("font_size", int(screen_size.y * 0.08))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size = Vector2(screen_size.x, screen_size.y * 0.2)
	title_label.position = Vector2(0, screen_size.y * 0.2)
	add_child(title_label)
	
	start_button = Button.new()
	start_button.text = "START"
	start_button.set_size(Vector2(screen_size.x * 0.6, screen_size.y * 0.1))
	start_button.position = Vector2(screen_size.x * 0.2, screen_size.y * 0.6)
	start_button.add_theme_font_size_override("font_size", int(screen_size.y * 0.04))
	start_button.pressed.connect(start_game)
	add_child(start_button)

func start_game():
	setup_game()

func setup_game():
	clear_screen()
	
	create_background()
	
	score = 0
	active_mosquito = -1
	color_change_time = 0.0
	game_active = true
	color_change_duration = 2.0
	
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", int(screen_size.y * 0.05))
	score_label.add_theme_color_override("font_color", Color.BLACK)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.size = Vector2(screen_size.x, screen_size.y * 0.1)
	score_label.position = Vector2(0, screen_size.y * 0.05)
	add_child(score_label)
	
	for i in range(15):
		var mosquito_area = Area2D.new()
		var mosquito_sprite = Sprite2D.new()
		mosquito_sprite.name = "MosquitoSprite"
		var collision_shape = CollisionShape2D.new()
		
		mosquito_sprite.texture = mosquito_textures[0]
		mosquito_sprite.modulate = Color(1, 1, 1, 0)  # Убедимся, что комар изначально невидим
		
		var shape = RectangleShape2D.new()
		shape.extents = cell_size / 2 * mosquito_scale_factor
		collision_shape.shape = shape
		
		mosquito_area.position = Vector2((i % 3) * cell_size.x + cell_size.x / 2, 
										 (i / 3) * cell_size.y + cell_size.y / 2 + screen_size.y * 0.15)
		mosquito_area.add_child(mosquito_sprite)
		mosquito_area.add_child(collision_shape)
		mosquito_area.set_meta("index", i)
		mosquito_area.input_event.connect(_on_mosquito_input.bind(i))
		
		add_child(mosquito_area)
		mosquitoes.append(mosquito_area)
	
	game_timer = Timer.new()
	game_timer.timeout.connect(_on_timer_timeout)
	add_child(game_timer)
	game_timer.start(color_change_duration)
	
	activate_random_mosquito()

func clear_screen():
	for child in get_children():
		child.queue_free()
	mosquitoes.clear()

func _on_mosquito_input(_viewport, event, _shape_idx, mosquito_index):
	if game_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mosquito_index == active_mosquito:
			score += 1
			score_label.text = "Score: " + str(score)
			
			var blood_sprite = Sprite2D.new()
			blood_sprite.texture = blood_texture
			blood_sprite.position = mosquitoes[active_mosquito].position
			
			var mosquito_sprite = mosquitoes[active_mosquito].get_node("MosquitoSprite")
			if mosquito_sprite and mosquito_sprite.texture:
				var scale_factor = min(
					cell_size.x / mosquito_sprite.texture.get_width(),
					cell_size.y / mosquito_sprite.texture.get_height()
				) * mosquito_scale_factor
				blood_sprite.scale = Vector2(scale_factor, scale_factor)
			else:
				blood_sprite.scale = Vector2(mosquito_scale_factor, mosquito_scale_factor)
			
			add_child(blood_sprite)
			
			var tween = create_tween()
			tween.tween_property(blood_sprite, "modulate", Color(1, 1, 1, 0), 0.3)
			tween.tween_callback(func(): blood_sprite.queue_free())
			
			Input.vibrate_handheld(vibration_duration)
			
			if score % 5 == 0 and color_change_duration > min_mosquito_lifetime:
				color_change_duration = max(color_change_duration - 0.1, min_mosquito_lifetime)
			
			game_timer.stop()
			game_timer.start(color_change_duration)
			activate_random_mosquito()

func _on_timer_timeout():
	game_over()

func activate_random_mosquito():
	if active_mosquito != -1:
		var sprite = mosquitoes[active_mosquito].get_node("MosquitoSprite")
		if sprite:
			sprite.modulate = Color(1, 1, 1, 0)
	
	var new_active = randi() % 15
	var attempts = 0
	while new_active == last_active_mosquito and attempts < 15:
		new_active = randi() % 15
		attempts += 1
	
	active_mosquito = new_active
	last_active_mosquito = active_mosquito
	
	var new_active_sprite = mosquitoes[active_mosquito].get_node("MosquitoSprite")
	if new_active_sprite:
		var texture = mosquito_textures[randi() % mosquito_textures.size()]
		if texture:
			new_active_sprite.texture = texture
			var scale_factor = min(
				cell_size.x / texture.get_width(),
				cell_size.y / texture.get_height()
			) * mosquito_scale_factor
			new_active_sprite.scale = Vector2(scale_factor, scale_factor)
		else:
			new_active_sprite.scale = Vector2(mosquito_scale_factor, mosquito_scale_factor)
		new_active_sprite.modulate = Color(1, 1, 1, 1)
	else:
		print("Failed to get MosquitoSprite for active_mosquito: ", active_mosquito)
	
	color_change_time = 0.0
	
	# Дополнительная проверка и исправление
	if not new_active_sprite or new_active_sprite.modulate.a == 0:
		print("Mosquito is invisible or null, fixing...")
		if new_active_sprite:
			new_active_sprite.modulate = Color(1, 1, 1, 1)
		else:
			print("Creating new sprite for mosquito: ", active_mosquito)
			new_active_sprite = Sprite2D.new()
			new_active_sprite.name = "MosquitoSprite"
			new_active_sprite.texture = mosquito_textures[randi() % mosquito_textures.size()]
			var scale_factor = min(
				cell_size.x / new_active_sprite.texture.get_width(),
				cell_size.y / new_active_sprite.texture.get_height()
			) * mosquito_scale_factor
			new_active_sprite.scale = Vector2(scale_factor, scale_factor)
			new_active_sprite.modulate = Color(1, 1, 1, 1)
			mosquitoes[active_mosquito].add_child(new_active_sprite)

	print("Activated mosquito: ", active_mosquito, " with sprite: ", new_active_sprite)

func game_over():
	game_active = false
	if game_timer:
		game_timer.stop()
	
	top_scores.append(score)
	top_scores.sort()
	top_scores.reverse()
	if top_scores.size() > 5:
		top_scores = top_scores.slice(0, 5)
	
	clear_screen()
	
	create_background()
	
	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.add_theme_font_size_override("font_size", int(screen_size.y * 0.08))
	game_over_label.add_theme_color_override("font_color", Color.BLACK)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.size = Vector2(screen_size.x, screen_size.y * 0.2)
	game_over_label.position = Vector2(0, screen_size.y * 0.2)
	add_child(game_over_label)
	
	var top_scores_label = Label.new()
	top_scores_label.text = "Top 5 Scores:\n" + "\n".join(top_scores.map(func(s): return str(s)))
	top_scores_label.add_theme_font_size_override("font_size", int(screen_size.y * 0.04))
	top_scores_label.add_theme_color_override("font_color", Color.BLACK)
	top_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_scores_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_scores_label.size = Vector2(screen_size.x, screen_size.y * 0.3)
	top_scores_label.position = Vector2(0,  screen_size.y * 0.4)
	add_child(top_scores_label)
	
	restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.set_size(Vector2(screen_size.x * 0.6, screen_size.y * 0.1))
	restart_button.position = Vector2(screen_size.x * 0.2, screen_size.y * 0.7)
	restart_button.add_theme_font_size_override("font_size", int(screen_size.y * 0.04))
	restart_button.pressed.connect(start_game)
	add_child(restart_button)

func _process(delta):
	if game_active and active_mosquito != -1:
		color_change_time += delta
		var t = color_change_time / color_change_duration
		t = min(t, 1.0)
		var sprite = mosquitoes[active_mosquito].get_node("MosquitoSprite")
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1).lerp(Color(1, 0, 0, 1), t)
	elif not game_active and is_instance_valid(title_label):
		shake_title(delta)

func shake_title(delta):
	shake_time += delta
	if shake_time > shake_duration:
		shake_time = 0
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
