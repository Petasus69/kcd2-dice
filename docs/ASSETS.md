# Ресурсы Godot

## Дерево: ChairDamaskPurplegold

Три изображения в `godot/assets/wood/` взяты из
[Khronos glTF Sample Assets / ChairDamaskPurplegold](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/ChairDamaskPurplegold/glTF).
Автор моделей и текстур: **Eric Chadwick**. **© 2021 Wayfair**.
Лицензия: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
Исходное уведомление сохранено в [SOURCE.md](../godot/assets/wood/SOURCE.md),
полный текст лицензии — в [LICENSE.txt](../godot/assets/wood/LICENSE.txt).
Текст лицензии получен из [SPDX License List Data](https://github.com/spdx/license-list-data/blob/main/text/CC-BY-4.0.txt).

Сами JPEG сохранены без изменений. Шейдеры меняют оттенок, масштаб,
направление волокон и добавляют износ, стыки досок и декоративную окантовку.
Стол и игровая доска используют отдельные материалы; изображения общие.
Текстуры имеют размер 512 × 512, суммарно около 534 КиБ.
Упоминание автора, лицензии и источника доступно в приложении: «Об игре и авторы».
Только эти текстуры перенесены из набора; модель кресла, ткань и маркировка не используются.

Получены 2026-10-09. SHA-256 исходных файлов:

| Файл | SHA-256 |
| --- | --- |
| `chair_wood_albedo.jpg` | `6f985ac8ec698cab1ae7aeeb87d139b604d6169a516ca46593481ea25d0dcc10` |
| `chair_wood_normal.jpg` | `78c7f4fa334223d0aa6dacb8d5044d9f63d84eb3d2e95881e578d53d4c3413ed` |
| `chair_wood_roughness0.jpg` | `048ac9e59d05b196bee1bdadfdf6a77589ee327fb3070bb4d773a760a60d3d49` |

В glTF шероховатость хранится в зелёном канале последнего изображения.
Нормали и шероховатость читаются как линейные данные; цвет — как sRGB.
Карты имеют mipmaps, чтобы уменьшить мерцание при наклонной камере.

## Остальные ресурсы

- DejaVu Serif: [лицензия](../godot/assets/FONT-LICENSE.txt).
- `tavern.jpg`: создан ImageGen, сохранён из предыдущего визуального прохода;
  текущая сцена больше не использует его как материал стола.
- Геометрия костей, свечи, стакана, материалы граней, рельеф точек,
  декоративные детали и звук ударов создаются кодом проекта, распространяемым по MIT.

Сторонние ресурсы имеют собственные лицензии; MIT для кода не заменяет их.
Ресурсы архивной веб-версии описаны в `legacy/`.
