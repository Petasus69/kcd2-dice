extends SceneTree
const Rules = preload("res://rules.gd")
const Game = preload("res://game_state.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        if failures <= 10:
            push_error(message)

func normalize_json(value: Variant) -> Variant:
    if value is float and value == floor(value):
        return int(value)
    if value is Array:
        return value.map(normalize_json)
    if value is Dictionary:
        var output: Dictionary = {}
        for key in value:
            output[key] = normalize_json(value[key])
        return output
    return value

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    if args.is_empty() or not FileAccess.file_exists(args[0]):
        push_error("Generate fixtures with export_rule_fixtures.mjs and pass their path after --")
        quit(1)
        return
    var fixtures: Dictionary = normalize_json(JSON.parse_string(FileAccess.get_file_as_string(args[0])))
    for item in fixtures.scores:
        var actual: Variant = Rules.score_dice(item.values)
        check((actual == null and item.points == null) or
            (actual != null and item.points != null and actual.points == item.points),
            "Scoring differs from JS for %s: %s expected %s" % [item.values, actual, item.points])
    var transitions := 0
    for item in fixtures.badgeScores:
        var actual: Variant = Rules.score_dice(item.values, Game.Catalog.badge(item.badge))
        check((actual == null and item.points == null) or (actual != null and actual.points == item.points), "Badge scoring differs: %s %s" % [item.badge, item.values])
    for scenario in fixtures.scenarios:
        var game = Game.new()
        game.goal = int(scenario.goal)
        if scenario.has("badges"):
            game.configure(scenario.badges)
        for step in scenario.steps:
            var okay := true
            match step.type:
                "roll":
                    okay = not game.begin_roll().is_empty() and game.finish_roll(step.values)
                "keep": okay = game.keep(step.indices)
                "bank": okay = game.bank(step.indices)
                "bust": okay = game.bust()
                "badge":
                    var action: Dictionary = game.use_badge(step.indices)
                    okay = not action.is_empty()
                    if action.has("partial"):
                        okay = okay and game.finish_roll(step.values)
                    elif action.get("roll", false):
                        okay = okay and not game.begin_roll().is_empty() and game.finish_roll(step.values)
            check(okay, "Native action rejected: %s %s" % [scenario.name, step.type])
            var expected: Dictionary = step.expected
            check(game.scores == expected.scores and game.active == expected.active and
                game.turn == expected.turn and game.phase == expected.phase and
                game.pool == expected.pool and game.held == expected.held and
                game.turn_points == expected.turn_points and game.winner == expected.winner,
                "State differs from JS after %s / %s" % [scenario.name, step.type])
            transitions += 1
            check(game.uses == expected.uses and game.disabled == expected.disabled and game.multiplier == expected.multiplier and game.last_multiplier == expected.last_multiplier and game.extra == expected.extra, "Badge state differs: %s" % scenario.name)
            var restored: Variant = Game.restore(normalize_json(JSON.parse_string(JSON.stringify(game.snapshot()))))
            check(restored != null and restored.snapshot() == game.snapshot(), "Snapshot did not round-trip exactly")
            for choice in expected.choices:
                game.risk = float(choice.risk)
                var actual: Dictionary = game.ai_choice()
                check(actual.mask == choice.mask and actual.points == choice.points and actual.bank == choice.bank, "AI differs from JS: %s risk %s" % [scenario.name, choice.risk])
            game.risk = 1.0
    var game = Game.new()
    check(game.begin_roll().size() == 6, "Initial roll")
    check(not game.finish_roll([1, 2]), "Wrong-length roll must be rejected")
    check(not game.finish_roll([1, 2, 3, 4, 5.5, 6]), "Fractional die face must be rejected")
    check(game.phase == "rolling", "Rejected roll mutated phase")
    check(game.finish_roll([1, 2, 3, 4, 4, 6]), "Valid physical roll")
    for indices in [[0, 1], [0, 0], [12], [], [0.5], ["0"]]:
        check(not game.keep(indices), "Invalid selection accepted: %s" % [indices])
        check(game.turn_points == 0 and game.phase == "select" and game.pool.size() == 6,
            "Invalid selection mutated state")
    check(game.begin_roll().is_empty(), "Reroll must require keeping scoring dice")
    print("%s: %d scores, %d JS/native transitions, invalid actions" % [
        "PASS" if failures == 0 else "FAIL", fixtures.scores.size() + fixtures.badgeScores.size(), transitions])
    quit(0 if failures == 0 else 1)
