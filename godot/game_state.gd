extends RefCounted
## Native match rules. Random values come from physical ordinary-die orientations.
const Rules = preload("res://rules.gd")
const Catalog = preload("res://catalog.gd")
var badges := ["none", "none"]
var uses := [0, 0]
var disabled := [false, false]
var multiplier := 1.0
var last_multiplier := 1
var extra := 0
var partial_roll: Array[int] = []
var mode := "local"
var risk := 1.0
var stake := 0
var training := false
var settled := false
var contract := "wagoner"
var opponent := 0

func configure(badge_ids: Array) -> void:
    badges = badge_ids.duplicate()
    for i in range(2):
        var b := Catalog.badge(badges[i])
        var enemy := Catalog.badge(badges[1 - i])
        disabled[i] = enemy.type == "defence" and enemy.tier == b.tier
        if b.type == "headstart" and not disabled[i]:
            scores[i] = [0, 100, 200, 400][int(b.tier)]

func badge() -> Dictionary:
    return Catalog.badge("none" if disabled[active] else badges[active])

func total(additional := 0) -> int:
    return int(floor((turn_points + additional * last_multiplier) * multiplier))

func can_badge() -> bool:
    var b := badge()
    return not disabled[active] and not Catalog.passive(b) and uses[active] < int(b.uses)

func evaluate() -> void:
    phase = "bust" if Rules.scoring_options(pool.map(func(d: Dictionary): return d.value), badge()).is_empty() else "select"

func use_badge(indices: Array) -> Dictionary:
    error = ""
    var b := badge()
    if not can_badge():
        error = "Бляха недоступна или действует автоматически."
        return {}
    if b.type == "resurrection":
        if phase != "bust":
            error = "Воскрешение доступно после пустого броска."
            return {}
        uses[active] += 1
        phase = "ready"
        return {"roll": true}
    if phase not in ["select", "bust"]:
        error = "Применяй бляху после броска."
        return {}
    var chosen: Array[Dictionary] = []
    for index in indices:
        if not index is int or chosen.any(func(d: Dictionary): return d.die == index):
            error = "Некорректные кости."
            return {}
        var found := false
        for item in pool:
            if item.die == index:
                chosen.append(item)
                found = true
        if not found:
            error = "Некорректные кости."
            return {}
    var action := {"effect": b.type}
    match b.type:
        "fortune", "swap":
            var limit := int(b.tier) if b.type == "fortune" else (1 if b.tier == 2 else 2)
            if chosen.is_empty() or chosen.size() > limit:
                error = "Выбери от 1 до %d костей." % limit
                return {}
            if b.type == "swap" and b.tier == 3 and (chosen.size() != 2 or chosen[0].value != chosen[1].value):
                error = "Нужны две кости одного значения."
                return {}
            partial_roll.assign(indices)
            phase = "rolling"
            action.partial = indices.duplicate()
        "might":
            extra += 1
            pool.append({"die": 5 + extra, "value": 0})
            partial_roll.assign([5 + extra])
            phase = "rolling"
            action.partial = partial_roll.duplicate()
        "transmutation":
            if chosen.size() != 1:
                error = "Выбери одну кость."
                return {}
            chosen[0].value = [0, 3, 5, 1][int(b.tier)]
            action.die = chosen[0].die
            action.value = chosen[0].value
        "double":
            if last_multiplier != 1 or selection(indices) == null:
                error = "Выбери очковую комбинацию; бросок можно удвоить только один раз."
                return {}
            last_multiplier = 2
        "warlord":
            if multiplier != 1.0:
                error = "Ход уже усилен."
                return {}
            multiplier = [1.0, 1.25, 1.5, 2.0][int(b.tier)]
    uses[active] += 1
    history.push_front("%s: бляха «%s»" % [names[active], b.name])
    history = history.slice(0, 30)
    if phase != "rolling":
        evaluate()
    return action

func ai_choice() -> Dictionary:
    var best := {}
    for option in Rules.scoring_options(pool.map(func(d: Dictionary): return d.value), badge()):
        var left: int = pool.size() - int(option.count)
        var utility: float = option.points + (left if left > 0 else 6) * 45 * risk
        if best.is_empty() or utility > best.utility:
            best = option.duplicate()
            best.utility = utility
    if best.is_empty():
        return best
    var left: int = pool.size() - int(best.count)
    var threshold: float = (1400 if left == 0 else (850 if left >= 4 else (500 if left == 3 else (300 if left == 2 else 150)))) * risk
    if scores[1 - active] - scores[active] > 800:
        threshold += 250
    best.bank = scores[active] + total(best.points) >= goal or total(best.points) >= threshold
    best.indices = []
    for i in range(pool.size()):
        if best.mask & (1 << i):
            best.indices.append(pool[i].die)
    return best
var goal := 2000
var scores := [0, 0]
var names := ["Игрок 1", "Игрок 2"]
var active := 0
var turn := 1
var phase := "ready"
var pool: Array[Dictionary] = []
var held: Array[int] = []
var held_faces := {}
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
        held_faces.clear()
        for i in range(6 + extra):
            pool.append({"die": i, "value": 0})
    phase = "rolling"
    last_multiplier = 1
    partial_roll.clear()
    var indices: Array[int] = []
    for item in pool:
        indices.append(item.die)
    return indices

func finish_roll(values: Array) -> bool:
    var targets: Array = pool.filter(func(d: Dictionary): return partial_roll.is_empty() or partial_roll.has(d.die))
    if phase != "rolling" or values.size() != targets.size():
        return false
    for value in values:
        if (not value is int and not value is float) or value != int(value) or value < 1 or value > 6:
            return false
    for i in range(targets.size()):
        targets[i].value = int(values[i])
    partial_roll.clear()
    evaluate()
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
    return Rules.score_dice(values, badge())

func keep(indices: Array) -> bool:
    var score: Variant = selection(indices)
    if score == null:
        error = "Выбранные кости не дают очков."
        return false
    indices = indices.map(func(index: Variant) -> int: return int(index))
    turn_points += int(score.points) * last_multiplier
    last_multiplier = 1
    var remaining: Array[Dictionary] = []
    for item in pool:
        if indices.has(item.die):
            held.append(item.die)
            held_faces[str(item.die)] = item.value
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
    scores[active] += total()
    history.push_front("%s: +%d" % [names[active], total()])
    history = history.slice(0, 30)
    if scores[active] >= goal:
        winner = active
        phase = "over"
    else:
        next_turn()
    return true

func bust() -> bool:
    if phase != "bust":
        return false
    history.push_front("%s: сгорело %d" % [names[active], total()])
    next_turn()
    return true

func next_turn() -> void:
    active = 1 - active
    turn += 1
    pool.clear()
    held.clear()
    held_faces.clear()
    turn_points = 0
    multiplier = 1.0
    last_multiplier = 1
    extra = 0
    partial_roll.clear()
    phase = "ready"
    error = ""
    history = history.slice(0, 30)

func snapshot() -> Dictionary:
    var result := {}
    for key in ["goal", "scores", "names", "active", "turn", "phase", "pool", "held", "held_faces", "turn_points", "winner", "history", "badges", "uses", "disabled", "multiplier", "last_multiplier", "extra", "partial_roll", "mode", "risk", "stake", "training", "settled", "contract", "opponent"]:
        result[key] = get(key)
    return result.duplicate(true)

static func restore(s: Dictionary) -> Variant:
    # Never restore an in-flight frame as a settled die result.
    s = s.duplicate(true)
    if s.get("phase") not in ["ready", "rolling", "select", "bust", "over"] or s.get("active", -1) not in [0, 1]:
        return null
    for key in ["scores", "names", "badges", "uses", "disabled"]:
        if not s.get(key) is Array or s[key].size() != 2:
            return null
    for i in range(2):
        if not s.scores[i] is int or s.scores[i] < 0 or not s.uses[i] is int or s.uses[i] < 0 or not s.disabled[i] is bool or not s.names[i] is String or not s.badges[i] is String:
            return null
        if Catalog.badge(s.badges[i]).id != s.badges[i] or s.names[i].length() > 64:
            return null
    for key in ["goal", "active", "turn", "turn_points", "winner", "extra", "last_multiplier", "stake", "opponent"]:
        if not s.get(key) is int:
            return null
    if s.get("mode") not in ["ai", "local"] or not s.get("training") is bool or not s.get("settled") is bool or not s.get("history") is Array or not s.get("partial_roll") is Array:
        return null
    if s.get("multiplier") not in [1, 1.25, 1.5, 2] or s.last_multiplier not in [1, 2] or s.get("risk") not in [0.7, 1, 1.1, 1.25] or s.stake < 0 or s.opponent < 0 or s.opponent >= Catalog.data.opponents.size():
        return null
    if s.history.size() > 30 or s.history.any(func(entry: Variant): return not entry is String):
        return null
    if not s.get("pool") is Array or not s.get("held") is Array or s.pool.size() + s.held.size() > 9:
        return null
    if not s.get("held_faces") is Dictionary:
        return null
    var ids := []
    for item in s.pool:
        if not item is Dictionary or not item.get("die") is int or item.die < 0 or item.die > 8 or ids.has(item.die):
            return null
        if not item.get("value") is int or item.value < 0 or item.value > 6:
            return null
        if s.phase in ["select", "bust"] and item.get("value", 0) not in [1, 2, 3, 4, 5, 6]:
            return null
        ids.append(item.die)
    for id in s.held:
        if not id is int or id < 0 or id > 8 or ids.has(id):
            return null
        if s.held_faces.get(str(id)) not in [1, 2, 3, 4, 5, 6]:
            return null
        ids.append(id)
    var rolling_ids := []
    for id in s.partial_roll:
        if not id is int or rolling_ids.has(id) or not s.pool.any(func(d: Dictionary): return d.die == id):
            return null
        rolling_ids.append(id)
    if s.get("goal", 0) < 1 or s.get("turn", 0) < 1 or s.get("turn_points", -1) < 0 or s.get("extra", -1) not in [0, 1, 2, 3]:
        return null
    if s.phase == "over" and s.get("winner", -1) not in [0, 1]:
        return null
    var g = load("res://game_state.gd").new()
    for key in g.snapshot():
        if s.has(key):
            if key in ["pool", "held", "partial_roll", "history"]:
                g.get(key).assign(s[key])
            else:
                g.set(key, s[key])
    return g
