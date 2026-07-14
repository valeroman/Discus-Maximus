extends Node

var health: int
var max_health: int
var currency: int
var combo_count: int
var active_upgrades: Array = []

func get_stat(stat_name: String) -> float:
	pass

func reset_run() -> void:
	pass

func add_currency(amount: int) -> void:
	pass

func apply_upgrade(upgrade_data) -> void:
	pass
