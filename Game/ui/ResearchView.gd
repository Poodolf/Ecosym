extends VBoxContainer

func _ready():
	for button in get_tree().get_nodes_in_group("ResearchButtons"):
		button.connect("pressed", self, "on_unlock", [button.get_path()])
		print("wtf" + button.get_path())

func on_unlock(research):
	print("button ", get_node(research).get_parent().get_name())
	get_node(research).disabled = true
