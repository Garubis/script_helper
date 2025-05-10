extends Control


## Fixes common problems with scripts quickly.
##
## Searches each line of a script for certain missing features.
## (missing void, missing types, TODO more?)


# UI buttons.
@onready var select_file_button: Button = %SelectFileButton
@onready var check_button: Button = %CheckButton
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton
@onready var rename_button: Button = %RenameButton
@onready var user_save_confirmation_button: Button = %UserSaveConfirmationButton
@onready var backup_notification: Button = %BackupNotification

# File stuff.
@onready var file_dialog: FileDialog = %FileDialog
@onready var selected_file_label: Label = %SelectedFileLabel
@onready var output_text: TextEdit = %OutputText


# Save stuff.
@onready var confirmation_panel: PanelContainer = %ConfirmationPanel
## New file/rename line on save menu.
@onready var rename_line_edit: LineEdit = %RenameLineEdit

# Option check boxes.
@onready var check_void: CheckBox = %CheckVoid
@onready var check_static_type: CheckBox = %CheckStaticType
@onready var check_show_full_file: CheckBox = %CheckShowFullFile

## Menu for quick type fixes.
@onready var type_panel: PanelContainer = %TypePanel
@onready var type_container: GridContainer = %TypeContainer

## When the user clicks a type in the type menu.
signal type_selected_signal(type: String)
## Stores the user's selected type so the script can auto add to it's selected line.
var selected_type: String

## The selected file used to copy/edit.
var loaded_file: FileAccess


## Holds all possible types to create buttons on the menu. Edit this and add your own here.
var type_array: Array[String] = [
	"float",
	"int",
	"String",
	"Vector2",
	"Vector2i",
	"Vector3",
	"Vector3i",
	"PackedScene",
	"yourCustomType"
]

## For testing this script. Purposely missing a type.
var _test_top_var = 5.0


func _ready() -> void:
	#To get the debugger to stop complaining for this test variable.
	_test_top_var = 5.1
	# Setup buttons.
	select_file_button.button_up.connect(toggle_dialog)
	file_dialog.file_selected.connect(selected_file)
	check_button.button_up.connect(check_button_pressed)
	save_button.button_up.connect(save_button_pressed)
	backup_notification.button_up.connect(click_backup_notification)
	cancel_button.button_up.connect(save_cancelled_pressed)
	rename_button.button_up.connect(save_rename_pressed)
	
	add_types()
	
	# Connect the full file option so the full path can be displayed/toggled.
	check_show_full_file.toggled.connect(toggle_full_file_path)
	
	# Hide stuff until it's needed.
	type_panel.set_visible(false)
	backup_notification.set_visible(false)
	confirmation_panel.set_visible(false)


## To test this script. Missing void return and static type for variables.
func test_func():
	print("print test")
	var _test_var = 5
	var _test_string_var = "string test"
	var _test_int_var = get_size()
	var _test_int2_var = 1


## Opens/hides the file dialog for selecting a script.
func toggle_dialog() -> void:
	file_dialog.set_visible(!file_dialog.is_visible())


## Updates the label when a file has been selected.
func selected_file(path: String) -> void:
	selected_file_label.set_meta("file",path)
	update_selected_file_label()


func toggle_full_file_path(_toggled_on: bool) -> void:
	update_selected_file_label()


func update_selected_file_label() -> void:
	if selected_file_label.has_meta("file"):
		pass
	else:
		return
	if check_show_full_file.is_pressed():
		selected_file_label.set_text(selected_file_label.get_meta("file"))
	else:
		var new_label_text: String = selected_file_label.get_meta("file").rsplit("/", true, 1)[1]
		selected_file_label.set_text(new_label_text)


## Used to start running all checks on the selected file.
func check_button_pressed() -> void:
	print("Checking file..")
	if loaded_file == null:
		load_file()
	if loaded_file == null: return
	output_text.set_text(loaded_file.get_as_text())
	# Read each line and check each line for the selected problems.
	for i in output_text.get_line_count():
		# Store the line to test/edit.
		var line_text = output_text.get_line(i)
		# Check for missing voids on function lines.
		if check_void.is_pressed():
			if line_text.begins_with("func") and line_text.contains("):"):
				prints("Adding VOID to:",line_text)
				# Use replace to add the void return type to the line.
				output_text.set_line(i, line_text.replace("):", ") -> void:"))
				# Reload the stored line since the text in the output has been changed.
				line_text = output_text.get_line(i)
		# Check for missing static types.
		if check_static_type.is_pressed():
			# TODO for loops.
			# Find lines with var, but without a : for a type.
			if (line_text.begins_with("	var") or line_text.begins_with("var")) and line_text.contains("=") and !line_text.contains(":"):
				prints("Adding TYPE to:",line_text)
				%CurrentLine.set_text(line_text)
				# Move the cursor to the line it found.
				output_text.set_caret_line(i, true, true, 0, 0)
				# Select the line to quickly show the user.
				output_text.select(i, 0, i, line_text.length(), 0)
				# Tell/show the user to select a type to set for this line.
				type_panel.set_visible(true)
				# Pause to ask before going to the next line.
				await type_selected_signal
				output_text.set_line(i, line_text.replace(" = ", ": " +selected_type+ " = "))
				line_text = output_text.get_line(i)
				prints("New typed line:",line_text)
	loaded_file.close()


func load_file() -> FileAccess:
	# Check if a file is selected.
	if FileAccess.file_exists(selected_file_label.get_meta("file")):
		pass
	else:
		print(">>ERROR<< No file selected.")
		return
	# Load the file.
	loaded_file = FileAccess.open(selected_file_label.get_meta("file"),FileAccess.READ)
	return loaded_file


## Saves the new edited text to overwrite the original file. TODO make another button/check box option to make a backup?
func save_button_pressed():
	if %ConfirmationPanel.is_visible():
		return
	if %BackupCheckBox.is_pressed():
		# The full path to the original/selected file.
		var input_path: String = selected_file_label.get_meta("file")
		# Splits the full file path to get the directory.
		var input_dir: String = input_path.rsplit("/",true,0)[0]
		# Splits the full file path to get 
		var input_split = input_path.split(".")
		# Used to make the backup unique and record when it was made.
		var backup_date: String = Time.get_datetime_string_from_system().replace(":","")
		# Splits the directory to add the backups folder before the file name.
		var input_dir_split = input_split[0].rsplit("/")
		# Create the whole path to save the new backup.
		var output_path: String = input_dir_split[0] + "backups/" + input_dir_split[1] + "_backup_" + backup_date + "." + input_split[1]
		
		# Open the directory to create a copy/backup of the original file.
		var mydir: DirAccess = DirAccess.open("res://")
		mydir.copy(input_path, output_path, -1)
		
		# Check if the file was successfully created to show the correct notification.
		if FileAccess.file_exists(output_path):
			backup_notification.set_text("BACKUP CREATED!")
			backup_notification.set_visible(true)
		else:
			backup_notification.set_text(">>>BACKUP FAILED!<<<")
			backup_notification.set_visible(true)
	else:
		prints("Save pressed, backup disabled.")
	user_save_confirmation_button.button_up.connect(save_confirmed_pressed,ConnectFlags.CONNECT_ONE_SHOT)
	# Ask the user if the new document changes are ok.
	%ConfirmationPanel.set_visible(true)


## When YES has been selected by the user in the confirmation menu/panel.
func save_confirmed_pressed() -> void:
	var file_path: String = selected_file_label.get_meta("file")
	prints("User pressed YES to save and overwrite file:",file_path)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(output_text.get_text())
	file.close()
	
	%ConfirmationPanel.set_visible(false)


## When CANCEL has been selected by the user in the confirmation menu/panel.
func save_cancelled_pressed() -> void:
	print("Save cancelled.")
	user_save_confirmation_button.button_up.disconnect(save_confirmed_pressed)
	%ConfirmationPanel.set_visible(false)


## When RENAME has been selected by the user in the confirmation menu/panel.
func save_rename_pressed() -> void:
	if %RenameLineEdit.get_text().is_empty():
		print("Save rename pressed, but no name is given, ignoring..")
		return
	var new_file_path: String = selected_file_label.get_meta("file").rsplit("/",true,1)[0] + "/" + %RenameLineEdit.get_text()
	prints("Save rename pressed to make new file:", new_file_path)
	
	var file = FileAccess.open(new_file_path, FileAccess.WRITE)
	file.store_string(output_text.get_text())
	file.close()
	
	user_save_confirmation_button.button_up.disconnect(save_confirmed_pressed)
	%ConfirmationPanel.set_visible(false)


## Triggered when the user selects a type from the dropdown menu. This adds the type to the line in question.
func type_selected(type: String):
	selected_type = type
	prints("user selected:",type)
	type_panel.set_visible(false)
	type_selected_signal.emit()


## Adds buttons to the type menu/panel to quickly add types to lines missing them.
func add_types() -> void:
	for i in type_array:
		print(i)
		if i.is_empty():
			return
		else:
			var new_button: Button = Button.new()
			new_button.set_text(i)
			new_button.button_up.connect(type_selected.bind(i))
			%TypeContainer.add_child(new_button)


## When the backup notification is clicked on.
func click_backup_notification() -> void:
	# Remove the notification.
	backup_notification.set_visible(false)
