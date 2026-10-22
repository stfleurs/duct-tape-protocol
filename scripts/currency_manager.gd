extends Node

signal scrap_changed(new_balance: int, delta: int)

func get_scrap() -> int:
	return SaveManager.get_scrap_balance()

func add_scrap(amount: int) -> int:
	if amount <= 0:
		return get_scrap()
	var current: int = SaveManager.get_scrap_balance()
	var updated: int = current + amount
	SaveManager.set_scrap_balance(updated)
	scrap_changed.emit(updated, amount)
	return updated

func spend_scrap(amount: int) -> bool:
	if amount <= 0:
		return true
	var current: int = SaveManager.get_scrap_balance()
	if current < amount:
		return false
	var updated: int = current - amount
	SaveManager.set_scrap_balance(updated)
	scrap_changed.emit(updated, -amount)
	return true
