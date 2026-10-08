extends RefCounted
const Catalog = preload("res://catalog.gd")
var path := "user://profile-v03.json"
var data: Dictionary
var warning := ""

func _init() -> void:
    data = {"gold": 500, "wins": 0, "games": 0, "sound": true, "haptic": true, "fast": false, "badges": ["none", "none"], "owned": {}, "saved": null}
    for b in Catalog.data.badges:
        data.owned[b.id] = 1

static func normalize(value: Variant) -> Variant:
    if value is float and value == floor(value):
        return int(value)
    if value is Array:
        return value.map(normalize)
    if value is Dictionary:
        var result := {}
        for key in value:
            result[key] = normalize(value[key])
        return result
    return value

func read_save() -> void:
    if not FileAccess.file_exists(path):
        return
    var parsed: Variant = normalize(JSON.parse_string(FileAccess.get_file_as_string(path)))
    if not parsed is Dictionary:
        warning = "Не удалось прочитать профиль. Исходный файл не перезаписан."
        return
    for key in ["gold", "wins", "games"]:
        if not parsed.get(key) is int or parsed[key] < 0:
            warning = "Повреждён профиль. Исходный файл не перезаписан."
            return
    for key in ["sound", "haptic", "fast"]:
        if not parsed.get(key) is bool:
            warning = "Повреждён профиль. Исходный файл не перезаписан."
            return
    if not parsed.get("owned") is Dictionary or not parsed.get("badges") is Array or parsed.badges.size() != 2:
        warning = "Повреждён профиль. Исходный файл не перезаписан."
        return
    for value in parsed.owned.values():
        if not value is int or value < 0:
            warning = "Повреждён инвентарь. Исходный файл не перезаписан."
            return
    for key in data:
        if parsed.has(key):
            data[key] = parsed[key]

func save() -> bool:
    if not warning.is_empty():
        return false
    var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data))
    file.flush()
    file.close()
    return DirAccess.rename_absolute(path + ".tmp", path) == OK

func settle(game: RefCounted) -> String:
    if game.phase != "over" or game.settled:
        return ""
    game.settled = true
    data.games += 1
    if game.winner == 0:
        data.wins += 1
    if game.mode != "ai" or game.training or game.stake == 0:
        return "Партия без ставки."
    if game.winner == 0:
        data.gold += game.stake * 2
        var trophy: String = game.badges[1]
        if trophy != "none":
            data.owned[trophy] = int(data.owned.get(trophy, 0)) + 1
        return "Выигрыш: %d грошей. Бляха соперника добавлена в коллекцию." % (game.stake * 2)
    var lost: String = game.badges[0]
    if lost != "none":
        data.owned[lost] = maxi(0, int(data.owned.get(lost, 0)) - 1)
    return "Ставка проиграна. Поставленная бляха потеряна."
