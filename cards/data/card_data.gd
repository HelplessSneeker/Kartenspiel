extends Resource
class_name CardData

enum Category { AKTION, REAKTION }

@export var card_name: String = ""
@export var cost: int = 0
@export var category: Category = Category.AKTION
@export var damage: int = 0
@export var block: int = 0
@export_multiline var description: String = ""
