extends Node
class_name StateMachine

@export var initial_state: NodePath

var current: State = null
var owner_node: Node = null

func _ready() -> void:
	owner_node = get_parent()
	# Inject machine/owner into child states
	for child in get_children():
		if child is State:
			child.machine = self
			child.host = owner_node

	if initial_state != NodePath():
		var st: Node = get_node_or_null(initial_state)
		if st is State:
			change_state(st)

func change_state(new_state: State, msg := {}) -> void:
	if new_state == current:
		return
	if current:
		current.exit()
	current = new_state
	if current:
		current.enter(msg)

func _physics_process(delta: float) -> void:
	if current:
		current.physics_update(delta)

func _process(delta: float) -> void:
	if current:
		current.update(delta)
