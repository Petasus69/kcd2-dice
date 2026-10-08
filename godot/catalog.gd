extends RefCounted
static var data: Dictionary = normalize(JSON.parse_string(FileAccess.get_file_as_string("res://catalog.json")))
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
static func badge(id: String) -> Dictionary:
    for item in data.badges:
        if item.id == id:
            return item
    return data.badges[0]
static func passive(b: Dictionary) -> bool:
    return b.type in ["none", "formation", "emperor", "tyche", "headstart", "defence"]
