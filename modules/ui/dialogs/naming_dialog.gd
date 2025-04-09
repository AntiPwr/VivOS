extends Panel

# Reference to the animal being named
var animal = null

# Node references
var name_input: LineEdit
var title_label: Label
var random_button: Button
var confirm_button: Button
var cancel_button: Button

# Signals
signal name_confirmed(name)
signal canceled()

func _ready():
	# Set up UI elements
	setup_ui()
	
	# Set initial focus to text field
	name_input.call_deferred("grab_focus")
	
	# Generate random name if possible
	if animal and animal.has_method("generate_name_suggestion"):
		name_input.text = animal.generate_name_suggestion()
		# Set cursor to end of text
		name_input.caret_column = name_input.text.length()

# Create UI elements
func setup_ui():
	# Set panel size
	size = Vector2(400, 200)
	
	# Create title
	title_label = Label.new()
	title_label.text = "Name Your Animal"
	title_label.position = Vector2(20, 20)
	title_label.size = Vector2(360, 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)
	
	# Create name input
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter a name..."
	name_input.position = Vector2(50, 70)
	name_input.size = Vector2(300, 40)
	add_child(name_input)
	
	# Add random name button
	random_button = Button.new()
	random_button.text = "Random"
	random_button.position = Vector2(50, 120)
	random_button.size = Vector2(90, 30)
	random_button.pressed.connect(_on_random_pressed)
	add_child(random_button)
	
	# Create buttons
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.position = Vector2(200, 120)
	confirm_button.size = Vector2(100, 30)
	confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(confirm_button)
	
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.position = Vector2(310, 120)
	cancel_button.size = Vector2(90, 30)
	cancel_button.pressed.connect(_on_cancel_pressed)
	add_child(cancel_button)

# Set the animal to be named
func set_animal(new_animal):
	animal = new_animal
	if animal:
		title_label.text = "Name Your " + animal.species_type
		
		if animal.has_method("generate_name_suggestion"):
			name_input.text = animal.generate_name_suggestion()
			# Set cursor to end of text
			name_input.caret_column = name_input.text.length()

# Button handlers
func _on_confirm_pressed():
	if name_input.text.strip_edges().is_empty():
		# Alert about empty name not allowed
		var alert = AcceptDialog.new()
		alert.title = "Naming Error"
		alert.dialog_text = "Please provide a name"
		add_child(alert)
		alert.popup_centered()
	else:
		# Emit signal with the chosen name
		emit_signal("name_confirmed", name_input.text)
		# Close the dialog
		queue_free()

func _on_cancel_pressed():
	emit_signal("canceled")
	queue_free()

func _on_random_pressed():
	if animal and animal.has_method("generate_name_suggestion"):
		name_input.text = animal.generate_name_suggestion()
		# Set cursor to end of text
		name_input.caret_column = name_input.text.length()
