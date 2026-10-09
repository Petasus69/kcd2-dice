# Разработка Godot-версии

## Инструменты

- Godot **4.6.3 Standard**, рендерер Compatibility.
- Node.js **22+** — генерация эталонных данных и проверки архивного JS-движка.
- Для Android: **JDK 17**, Android SDK Platform **36**, Build Tools **36.1.0**,
  Platform Tools и официальные export templates Godot **4.6.3**.
- Для графических тестов в Linux без дисплея: Xvfb, xauth, Mesa OpenGL.

Все команды ниже выполняются из корня репозитория. Для самой игры npm-пакеты
не требуются. Весь Godot-проект находится в `godot/`; не импортируйте корень
репозитория или `legacy/` как Godot-проект.

```bash
godot --editor --path godot
godot --path godot
```

На компьютере Space выполняет действие броска, Escape открывает меню партии.

## Архитектура

| Файл | Ответственность |
| --- | --- |
| `godot/table.tscn`, `table.gd` | Стол, камера, физический бросок, выбор костей и управление матчем |
| `godot/die.gd` | RigidBody3D, геометрия и материалы кости, определение верхней грани |
| `godot/rules.gd` | Разбиение выбранных костей на очковые комбинации и эффекты блях |
| `godot/game_state.gd` | Ходы, очки, бляхи, решения ИИ и состояние сохраняемой партии |
| `godot/menus.gd` | Настройка партии, пауза, правила, коллекция, журнал и результат |
| `godot/profile.gd` | Кошелёк, статистика, инвентарь, настройки и атомарное сохранение |
| `godot/catalog.gd`, `catalog.json` | Метаданные блях, столов и соперников |
| `godot/assets/`, `*.gdshader` | Шрифт, исходная текстура дерева и материалы |

Результаты обычных бросков поступают из физической ориентации остановившихся
тел. Бляха превращения отдельно анимирует изменение на заданную грань.
Кости, не участвующие в перебросе бляхой, остаются неподвижны. Наклонённая
или не остановившаяся кость не передаёт неоднозначную грань в правила:
предлагается повторный бросок с сохранением уже зачтённых очков.

Профиль — `user://profile-v03.json`. Загрузка сохраняет очки хода, грани
отложенных костей и расход блях; незавершённый бросок повторяет анимацию.
Начисление выигрыша выполняется один раз. Изменение формата профиля требует
планируемой миграции, а не удаления пользовательского сохранения.

## Проверки

```bash
# Архивный эталонный движок и его тесты.
npm ci --prefix legacy
npm test --prefix legacy

# Импорт проекта и сверка правил/ИИ с эталоном.
godot --headless --path godot --editor --import
node godot/tests/export_rule_fixtures.mjs /tmp/kcd2-rules-fixtures.json
godot --headless --path godot --script tests/rules_parity.gd -- /tmp/kcd2-rules-fixtures.json

# Реальная физика и интеграция сцены.
godot --headless --path godot --fixed-fps 90 --script tests/physics_smoke.gd
godot --headless --path godot --fixed-fps 90 --script tests/game_scene_smoke.gd
godot --headless --path godot --fixed-fps 90 --script tests/mechanics_smoke.gd

# Графическая проверка интерфейса требует работающего дисплея.
godot --path godot --audio-driver Dummy --script tests/mobile_ui_smoke.gd
# Альтернатива для Linux CI:
xvfb-run -a godot --path godot --audio-driver Dummy --script tests/mobile_ui_smoke.gd
```

Проверяйте вывод импорта: Godot может завершить импорт с кодом 0 даже при
`SCRIPT ERROR`. Тестовые скрипты должны завершиться с `PASS` и кодом 0.
Графические тесты включают четыре размера экрана, смену ориентации, выбор
и снятие выбора, отмену протягивания, мультитач, дублирующее событие мыши,
блокировку ввода меню и минимальный размер видимых кнопок.

Эталон генерируется из неизменённого `legacy/web/engine.js`.
Не исправляйте эталонные ожидания ради прохождения ошибочных нативных правил.
`catalog.json` сейчас генерируется из архивных метаданных:

```bash
node godot/tests/export_catalog.mjs
git diff -- godot/catalog.json
```

Особые кости и бляха Шута исключены из этого каталога намеренно.
Добавление нативных правил в будущем потребует явной версии эталона
или независимых подтверждённых сценариев.

Для визуальной записи доступен `godot/tests/visual_capture.gd`:

```bash
mkdir -p /tmp/kcd2-capture
KCD2_CAPTURE_DIR=/tmp/kcd2-capture godot --path godot \
  --write-movie /tmp/kcd2-capture/gameplay.avi --fixed-fps 30 \
  --script tests/visual_capture.gd
```

## Сборка Android

Основная сборка — [GitHub Actions: Godot Android](https://github.com/Petasus69/kcd2-dice/actions/workflows/android.yml).
Она запускается для push в `main`, pull request в `main` и вручную.
Последовательно проверяются архивный эталон, нативные правила, физика,
механики и мобильный интерфейс, затем экспортируется и проверяется подписанный APK.

Результат: артефакт **`Kosti-u-trakta-apk`**, файл **`build/Kosti-u-trakta.apk`**.
Android-пакет **`cz.petasus.dice.godotprototype`** сохранён ради совместимости
с уже установленной Godot-версией. Слово `prototype` в идентификаторе не влияет
на отображаемое имя игры. Не меняйте этот идентификатор при обычном обновлении:
смена пакета создаёт отдельное приложение и отдельные сохранения.

Для локальной сборки установите export templates через Godot и задайте
Android SDK, JDK и debug keystore в **Editor Settings → Export → Android**:

```bash
mkdir -p build
godot --headless --path godot --editor --import
godot --headless --path godot --export-debug Android ../build/Kosti-u-trakta.apk
"$ANDROID_HOME/build-tools/36.1.0/apksigner" verify build/Kosti-u-trakta.apk
```

Это development APK, не production-релиз для магазина.
Версия и числовой код обновления задаются в `godot/export_presets.cfg`.

## Подпись APK

По умолчанию CI создаёт временный debug-ключ для каждого запуска.
Такие APK нельзя ставить друг на друга как обновления: Android требует
одинаковую подпись, а удаление приложения удаляет профиль.

Для постоянной подписи добавьте в **Settings → Secrets and variables → Actions**
репозитория три секрета:

| Секрет | Содержимое |
| --- | --- |
| `DICE_KEYSTORE_BASE64` | Содержимое приватного JKS/keystore, закодированное в base64 |
| `DICE_KEY_ALIAS` | Alias ключа в этом keystore |
| `DICE_STORE_PASSWORD` | Пароль keystore и самого ключа; для этого debug-экспорта они должны совпадать |

При наличии keystore CI требует alias и пароль, а не переключается на новую
подпись при неполной настройке. Без keystore продолжает работать временная
development-подпись; это явно отмечается в сводке сборки.
Сохраняйте приватный ключ отдельно и делайте резервную копию. Никогда
не коммитьте ключи, пароли или `export_credentials.cfg`.
Новый постоянный ключ не восстановит совместимость со старыми APK,
которые были подписаны другим временным ключом.

## Архив веб-версии

`legacy/` содержит веб-приложение, старую Android-оболочку, исходные тесты
и прежние документы. Исторический README находится в `legacy/README.md`.
Его сборочный скрипт можно запустить вручную из архива; CI больше не выпускает
веб-APK. Новые игровые функции реализуются в Godot.
