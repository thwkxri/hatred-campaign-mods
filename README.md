# Hatred Campaign Mods

Сохранение позиции и бесконечные возрождения в одиночной кампании Hatred.

**[Скачать для Windows](https://github.com/thwkxri/hatred-campaign-mods/releases/latest)** · [English](#english)

| Мод | Как работает |
| --- | --- |
| **Сохранить и выйти** | Нажмите **«Главное меню»** в паузе или **Ctrl+F6** во время игры. После нового запуска **«Продолжить»** вернёт вас на сохранённое место с тем же здоровьем, оружием, патронами и прогрессом целей. |
| **Бесконечные возрождения** | В кампании доступно одно очко возрождения, которое восполняется после использования на всех сложностях, кроме «Безумной». |

Враги и разрушения загружаются по штатному контрольному пункту, поэтому обстановка после загрузки может отличаться.

## Установка

1. Закройте игру и распакуйте `Hatred-Campaign-Mods-v0.1.0.zip` из [Releases](https://github.com/thwkxri/hatred-campaign-mods/releases).
2. Откройте `Install.cmd` и укажите папку Hatred. В Steam её можно найти через **Управление → Просмотреть локальные файлы**.
3. Запустите игру привычным способом.

Установщик поддерживает **Hatred 1232203 для Windows x64** и распознаёт оригинальный файл Steam и проверенный вариант этого билда. Оба мода проверены в игре с обычной камерой и с Hatred 1.333. Файл Steam сверён по манифесту депо. Запуск через Steam ещё предстоит проверить.

Если игра открывается, а моды не загружаются, установите актуальную библиотеку Microsoft Visual C++ x64 и запустите игру снова. [Скачать Visual C++ x64](https://aka.ms/vc14/vc_redist.x64.exe)

## Как отключить мод

Закройте игру и откройте `Hatred\Binaries\Win64\ue4ss\Mods\mods.txt` в папке игры. Поменяйте `1` на `0` у `CampaignResume` для сохранения позиции или у `CampaignRespawn` для возрождений.

## Исходники

- [`save-and-exit.lua`](save-and-exit.lua) сохраняет позицию, состояние героя и прогресс целей кампании.
- [`unlimited-respawn.lua`](unlimited-respawn.lua) восполняет очки возрождения.

Архив релиза включает установщик, исходники загрузчика и адаптированный UE4SS v4.0.0 с лицензией MIT. [UE4SS v4.0.0](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v4.0.0)

## English

**[Download for Windows](https://github.com/thwkxri/hatred-campaign-mods/releases/latest)**

- **Save and quit to menu.** Use **Main Menu** in the pause menu or press **Ctrl+F6**. After relaunching, **Continue** restores your position, health, inventory, ammo and objective progress. Enemies and destruction load from the standard checkpoint.
- **Unlimited respawns.** One campaign respawn point replenishes after each use on every difficulty except Insane.

Close the game, extract the ZIP from [Releases](https://github.com/thwkxri/hatred-campaign-mods/releases), run `Install.cmd`, and select your Hatred installation folder. In Steam use **Manage → Browse local files**. Launch the game as usual.

The installer recognizes **Hatred Windows x64 build 1232203** from Steam and a tested variant. Both mods were tested with the default camera and with Hatred 1.333. The Steam file was verified against its depot manifest. An in-game Steam test is pending. If the mods do not load, install the current Visual C++ x64 runtime. [Microsoft Visual C++ x64](https://aka.ms/vc14/vc_redist.x64.exe)

To disable either mod, change its value to `0` in `Hatred\Binaries\Win64\ue4ss\Mods\mods.txt` and relaunch.
