extends Node

var hp: int
var max_hp: int
var currency_run: int
var combo: int
var active_upgrades: Array = []

func get_stat(stat_name: String) -> float:
	return 0.0

func reset_run() -> void:
	pass

func add_currency(amount: int) -> void:
	pass

func apply_upgrade(upgrade_data) -> void:
	pass
