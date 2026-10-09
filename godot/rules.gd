extends RefCounted
## Port of legacy/web/engine.js scoreDice, including ordinary-die badge modifiers.
## Every selected die must be part of a scoring group from THIS throw.

static func score_dice(values: Array, badge: Dictionary = {}) -> Variant:
    if values.is_empty() or values.size() > 9:
        return null
    var normalized: Array = []
    for value in values:
        if (not value is int and not value is float) or value != int(value) or value < 0 or value > 6:
            return null
        normalized.append(int(value))
    values = normalized
    var full := (1 << values.size()) - 1
    var groups: Array[Dictionary] = []
    for mask in range(1, full + 1):
        var subset: Array = []
        var real: Array = []
        for i in range(values.size()):
            if mask & (1 << i):
                subset.append(values[i])
                if values[i] != 0:
                    real.append(values[i])
        var count := subset.size()
        if count == 1 and (subset[0] == 1 or subset[0] == 5):
            groups.append({"mask": mask, "points": 100 if subset[0] == 1 else 50,
                "label": "Единица" if subset[0] == 1 else "Пятёрка"})
        if count >= 3:
            for face in range(1, 7):
                var same := true
                for value in real:
                    if value != face:
                        same = false
                if same:
                    var multiplier := 3 if badge.get("type") == "emperor" and face == 1 else (2 if badge.get("type") == "tyche" and face == 6 else 1)
                    groups.append({"mask": mask, "points": (1000 if face == 1 else face * 100) * (1 << (count - 3)) * multiplier,
                        "label": "%d × %d" % [count, face]})
        var patterns := [
            {"values": [1, 2, 3, 4, 5], "points": 500, "label": "Ряд 1–5"},
            {"values": [2, 3, 4, 5, 6], "points": 750, "label": "Ряд 2–6"},
            {"values": [1, 2, 3, 4, 5, 6], "points": 1500, "label": "Ряд 1–6"},
        ]
        if badge.has("formation"):
            patterns.append({"values": badge.formation, "points": badge.points, "label": badge.name})
        for pattern in patterns:
            if count != pattern.values.size():
                continue
            var unique: Array = []
            var matches := true
            for value in real:
                if unique.has(value) or not pattern.values.has(value):
                    matches = false
                unique.append(value)
            if matches:
                groups.append({"mask": mask, "points": pattern.points, "label": pattern.label})
    var memo: Dictionary = {0: {"points": 0, "parts": []}}
    return solve(full, groups, memo)

static func solve(mask: int, groups: Array[Dictionary], memo: Dictionary) -> Variant:
    if memo.has(mask):
        return memo[mask]
    var best: Variant = null
    var first := mask & -mask
    for group in groups:
        if (group.mask & first) and (group.mask & mask) == group.mask:
            var tail: Variant = solve(mask ^ group.mask, groups, memo)
            if tail != null and (best == null or tail.points + group.points > best.points):
                best = {"points": tail.points + group.points, "parts": [group.label] + tail.parts}
    memo[mask] = best
    return best

static func scoring_options(values: Array, badge: Dictionary = {}) -> Array[Dictionary]:
    var options: Array[Dictionary] = []
    for mask in range(1, 1 << values.size()):
        var subset: Array = []
        for i in range(values.size()):
            if mask & (1 << i):
                subset.append(values[i])
        var score: Variant = score_dice(subset, badge)
        if score != null:
            options.append({"mask": mask, "points": score.points, "count": subset.size()})
    options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a.points > b.points or (a.points == b.points and a.count < b.count))
    return options
