extends RefCounted
## Core local match, ordinary dice only. Values come from physical orientations.
const Rules = preload("res://rules.gd")
var goal := 2000
var scores := [0, 0]
var names := ["Игрок 1", "Игрок 2"]
var active := 0
var turn := 1
var phase := "ready"
var pool: Array[Dictionary] = []
var held: Array[int] = []
var turn_points := 0
var winner := -1
var error := ""
var history: Array[String] = []

func begin_roll() -> Array[int]:
    if phase != "ready":
        error = "Сначала выбери очковые кости."
        return []
    if pool.is_empty():
        held.clear()
        for i in range(6):
            pool.append({"die": i, "value": 0})
    phase = "rolling"
    var indices: Array[int] = []
    for item in pool:
        indices.append(item.die)
    return indices

func finish_roll(values: Array) -> bool:
    if phase != "rolling" or values.size() != pool.size():
        return false
    for value in values:
        if (not value is int and not value is float) or value != int(value) or value < 1 or value > 6:
            return false
    for i in range(pool.size()):
        pool[i].value = int(values[i])
    phase = "bust" if Rules.scoring_options(values).is_empty() else "select"
    return true

func selection(indices: Array) -> Variant:
    if phase != "select" or indices.is_empty():
        return null
    var seen: Array = []
    var values: Array = []
    for index in indices:
        if (not index is int and not index is float) or index != int(index):
            return null
        index = int(index)
        if seen.has(index):
            return null
        seen.append(index)
        var found := false
        for item in pool:
            if item.die == index:
                values.append(item.value)
                found = true
        if not found:
            return null
    return Rules.score_dice(values)

func keep(indices: Array) -> bool:
    var score: Variant = selection(indices)
    if score == null:
        error = "Выбранные кости не дают очков."
        return false
    indices = indices.map(func(index: Variant) -> int: return int(index))
    turn_points += int(score.points)
    var remaining: Array[Dictionary] = []
    for item in pool:
        if indices.has(item.die):
            held.append(item.die)
        else:
            remaining.append(item)
    pool = remaining
    phase = "ready"
    error = ""
    return true

func bank(indices: Array = []) -> bool:
    if not indices.is_empty() and not keep(indices):
        return false
    if phase != "ready" or turn_points <= 0:
        error = "Зачти очковые кости перед завершением хода."
        return false
    scores[active] += turn_points
    history.push_front("%s: +%d" % [names[active], turn_points])
    if scores[active] >= goal:
        winner = active
        phase = "over"
    else:
        next_turn()
    return true

func bust() -> bool:
    if phase != "bust":
        return false
    history.push_front("%s: сгорело %d" % [names[active], turn_points])
    next_turn()
    return true

func next_turn() -> void:
    active = 1 - active
    turn += 1
    pool.clear()
    held.clear()
    turn_points = 0
    phase = "ready"
    error = ""
    history = history.slice(0, 30)
