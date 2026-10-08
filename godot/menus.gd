extends Control
## Scrollable mobile overlays, independent of the physical tabletop.
var table: Node3D
var content: VBoxContainer
var screen := ""
var error_label: Label
var setup_mode: OptionButton
var setup_contract: OptionButton
var setup_enemy: OptionButton
var setup_names: Array[LineEdit] = []
var setup_badges: Array[OptionButton] = []
var setup_training: CheckButton
var return_to_match := false
const Catalog = preload("res://catalog.gd")

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade := ColorRect.new()
    shade.color = Color(0.035, 0.019, 0.012, 0.96)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var margins := MarginContainer.new()
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "top", "right", "bottom"]:
        margins.add_theme_constant_override("margin_" + side, 24)
    add_child(margins)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    margins.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 12)
    scroll.add_child(content)
    hide()

func open(title: String, kind: String) -> void:
    table.cancel_tap()
    screen = kind
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    show()
    text(title, 28)

func text(value: String, size := 18) -> Label:
    var node: Label = table.label(value, size, Color(0.93, 0.82, 0.61))
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(node)
    return node

func button(value: String, action: Callable) -> Button:
    var node := Button.new()
    node.text = value
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    table.style_button(node)
    node.add_theme_font_size_override("font_size", 20)
    content.add_child(node)
    node.pressed.connect(action)
    return node

func option(title: String, labels: Array) -> OptionButton:
    text(title, 16)
    var node := OptionButton.new()
    node.fit_to_longest_item = false
    node.clip_text = true
    table.style_button(node)
    node.add_theme_font_size_override("font_size", 18)
    content.add_child(node)
    for value in labels:
        node.add_item(value)
    return node

func home() -> void:
    open("КОСТИ У ТРАКТА", "home")
    text("%d грошей · побед %d / партий %d" % [table.profile.data.gold, table.profile.data.wins, table.profile.data.games])
    if not table.profile.warning.is_empty():
        text(table.profile.warning)
    var saved: Variant = table.profile.data.saved
    if saved is Dictionary and saved.get("phase") != "over":
        button("Продолжить партию", table.resume_saved)
    button("Новая партия", setup)
    button("Бляхи и снаряжение", collection)
    button("Правила", rules)
    button("Настройки", settings)
    text("Нативная версия · обычные кости. Особые кости пока не перенесены.", 15)

func setup() -> void:
    open("НОВАЯ ПАРТИЯ", "setup")
    setup_mode = option("Режим", ["Против соперника", "Двое на одном телефоне"])
    setup_contract = option("Стол · цель · ставка против ИИ", Catalog.data.contracts.map(func(c: Dictionary): return "%s · %d · %d гр." % [c.name, c.goal, c.stake]))
    setup_enemy = option("Соперник (пока все с обычными костями)", Catalog.data.opponents.map(func(o: Dictionary): return "%s · %s" % [o.name, o.title]))
    setup_names.clear()
    setup_badges.clear()
    for i in range(2):
        text("Имя игрока %d" % (i + 1), 16)
        var field := LineEdit.new()
        field.text = "Вы" if i == 0 else "Игрок 2"
        field.max_length = 18
        field.custom_minimum_size.y = 68
        field.add_theme_font_size_override("font_size", 22)
        content.add_child(field)
        setup_names.append(field)
        var pick := option("Твоя бляха" if i == 0 else "Бляха игрока 2 (для игры вдвоём)", Catalog.data.badges.map(func(b: Dictionary): return b.name))
        for n in range(Catalog.data.badges.size()):
            pick.set_item_metadata(n, Catalog.data.badges[n].id)
            if Catalog.data.badges[n].id == table.profile.data.badges[i]:
                pick.select(n)
        setup_badges.append(pick)
    setup_training = CheckButton.new()
    setup_training.text = "Тренировка: без ставки, любой ранг блях"
    setup_training.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    setup_training.custom_minimum_size.y = 68
    setup_training.add_theme_font_size_override("font_size", 18)
    content.add_child(setup_training)
    setup_training.toggled.connect(func(_value: bool): refresh_setup())
    setup_contract.item_selected.connect(func(_index: int): refresh_setup())
    setup_mode.item_selected.connect(func(_index: int): refresh_setup())
    refresh_setup()
    error_label = text("В игре за гроши ранг бляхи должен совпадать со столом. В локальной игре ставки нет.", 16)
    button("Сесть за стол", func():
        var chosen := []
        for pick in setup_badges:
            chosen.append(pick.get_item_metadata(pick.selected))
        var message: String = table.start_match(setup_mode.selected, setup_contract.selected, setup_enemy.selected, setup_names.map(func(f: LineEdit): return f.text.strip_edges()), chosen, setup_training.button_pressed)
        if not message.is_empty():
            error_label.text = message
    )
    button("Назад", home)

func refresh_setup() -> void:
    var c: Dictionary = Catalog.data.contracts[setup_contract.selected]
    setup_enemy.disabled = setup_mode.selected == 1
    for i in range(2):
        setup_badges[i].disabled = i == 1 and setup_mode.selected == 0
        for j in range(Catalog.data.badges.size()):
            var b: Dictionary = Catalog.data.badges[j]
            var unavailable: bool = not setup_training.button_pressed and (b.tier != c.tier or int(table.profile.data.owned.get(b.id, 0)) < 1)
            setup_badges[i].set_item_disabled(j, unavailable)
        if setup_badges[i].is_item_disabled(setup_badges[i].selected):
            for j in range(setup_badges[i].item_count):
                if not setup_badges[i].is_item_disabled(j):
                    setup_badges[i].select(j)
                    break

func pause() -> void:
    open("ПАРТИЯ ПРИОСТАНОВЛЕНА", "pause")
    text("Ход: %s · очки хода %d" % [table.game.names[table.game.active], table.game.total()])
    button("Продолжить", hide)
    button("Журнал партии", journal)
    button("Правила", rules)
    button("Настройки", settings)
    button("Сохранить и выйти в меню", func(): table.checkpoint(); home())
    button("Сдаться", surrender)

func surrender() -> void:
    open("ЗАВЕРШИТЬ ПАРТИЮ?", "surrender")
    text("В игре за гроши ставка и поставленная бляха будут проиграны.")
    button("Сдаться", func():
        table.game.winner = 1 if table.game.mode == "ai" else 1 - table.game.active
        table.game.phase = "over"
        table.update_results()
    )
    button("Продолжить игру", hide)

func handoff() -> void:
    open("ХОД ПЕРЕХОДИТ", "handoff")
    if not table.game.history.is_empty():
        text(table.game.history[0], 22)
    text("Передайте телефон: %s" % table.game.names[table.game.active], 24)
    button("Я готов — мой ход", hide)

func result(message: String) -> void:
    open("ПОБЕДИЛ %s" % table.game.names[table.game.winner].to_upper(), "result")
    text("%s: %d\n%s: %d" % [table.game.names[0], table.game.scores[0], table.game.names[1], table.game.scores[1]], 24)
    text(message)
    text("В кошельке: %d грошей" % table.profile.data.gold)
    button("Новая партия", setup)
    button("В главное меню", home)

func back() -> void:
    if screen == "home":
        return
    if screen == "handoff":
        return # Do not bypass the player handoff via Android Back.
    if screen in ["pause", "surrender", "badge"]:
        hide()
    elif screen in ["setup", "result"]:
        home()
    else:
        return_screen()

func return_screen() -> void:
    if return_to_match and table.game.phase != "over":
        pause()
    else:
        home()

func collection() -> void:
    return_to_match = screen == "pause"
    open("СНАРЯЖЕНИЕ", "collection")
    text("Шесть обычных костей. Особые кости и бляха Шута появятся после проработки вероятностей и анимации.")
    for b in Catalog.data.badges:
        text("%s · в коллекции %d\n%s" % [b.name, table.profile.data.owned.get(b.id, 0), b.desc])
    button("Назад", return_screen)

func rules() -> void:
    return_to_match = screen == "pause"
    open("ПРАВИЛА", "rules")
    text("Единица — 100, пятёрка — 50. Три одинаковых: единицы — 1000, остальные — значение × 100. Каждая следующая одинаковая кость удваивает комбинацию.\n\nРяд 1–5 — 500; 2–6 — 750; 1–6 — 1500.\n\nКаждая выбранная кость должна входить в очковую комбинацию этого броска. Кости разных бросков не складываются в тройки.\n\nЗачти очковые кости и брось оставшиеся или забери очки. Пустой бросок сжигает только очки текущего хода. Зачёл все кости — бросай полный набор снова. Победа засчитывается при завершении хода.")
    text("Бляхи расходуются за партию, не за ход. Защита отключает бляху соперника того же ранга. Воскрешение спасает пустой бросок. Перед применением активной бляхи можно выбирать даже неочковые кости.")
    button("Назад", return_screen)

func journal() -> void:
    open("ЖУРНАЛ ПАРТИИ", "journal")
    text("\n".join(table.game.history) if not table.game.history.is_empty() else "Партия только начинается.")
    button("Назад", pause)

func badge_details() -> void:
    var b: Dictionary = table.game.badge()
    open(b.name.to_upper(), "badge")
    text(b.desc, 22)
    text("Выбрано костей: %d" % table.selected.size())
    var apply := button("Применить бляху", func(): hide(); table.badge_action())
    apply.disabled = not table.game.can_badge() or table.game.phase not in ["select", "bust"] or (b.type == "resurrection" and table.game.phase != "bust")
    if table.game.disabled[table.game.active]:
        text("Отключена защитой соперника на эту партию.")
    elif Catalog.passive(b):
        text("Действует автоматически.")
    else:
        text("Осталось применений: %d" % maxi(0, int(b.uses) - int(table.game.uses[table.game.active])))
    button("К столу", hide)

func settings() -> void:
    if screen != "settings":
        return_to_match = screen == "pause"
    open("НАСТРОЙКИ", "settings")
    for entry in [["sound", "Звук"], ["haptic", "Вибрация выбора"], ["fast", "Быстрые решения ИИ"]]:
        var check := CheckButton.new()
        check.text = entry[1]
        check.button_pressed = table.profile.data[entry[0]]
        check.custom_minimum_size.y = 68
        check.add_theme_font_size_override("font_size", 22)
        content.add_child(check)
        var key: String = entry[0]
        check.toggled.connect(func(value: bool):
            table.profile.data[key] = value
            table.sound_enabled = table.profile.data.sound
            table.save_profile()
        )
    button("Пополнить кошелёк до 500 гр. (прототип)", func():
        table.profile.data.gold = maxi(500, table.profile.data.gold)
        table.save_profile()
        settings()
    )
    button("Назад", return_screen)
