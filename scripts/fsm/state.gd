extends Node
class_name State

## Lightweight state base class.
## Add as children of a StateMachine node and override:
## - enter(msg)
## - exit()
## - physics_update(delta)
## - update(delta)

var machine: StateMachine
# NOTE: Don't name this "owner" (Node already has an "owner" property).
var host: Node

func enter(_msg := {}) -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func update(_delta: float) -> void:
	pass
