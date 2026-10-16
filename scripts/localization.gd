extends Node

signal language_changed(language_code: String)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["en", "uk", "ru"]

var current_language := DEFAULT_LANGUAGE

var _messages := {
	"ru": {
		"GAME_TITLE": "FLECKY",
		"GAME_SUBTITLE": "ADVENTURES IN ICY WATERS",
		"MENU_TAGLINE": "Маленькое приключение в большой ледяной бухте",
		"MENU_START": "НАЧАТЬ ПРИКЛЮЧЕНИЕ",
		"MENU_CONTROLS": "УПРАВЛЕНИЕ",
		"MENU_SETTINGS": "НАСТРОЙКИ",
		"MENU_ACHIEVEMENTS": "ДОСТИЖЕНИЯ",
		"MENU_CREDITS": "АВТОРЫ",
		"MENU_EXIT": "ВЫЙТИ",
		"MENU_MUSIC": "Музыка: Ice Bay Drift",
		"CONTROLS_TITLE": "КАК ИГРАТЬ",
		"CONTROLS_BODY": (
			"WASD — плыть и поворачивать\n"
			+ "МЫШЬ — управлять камерой\n"
			+ "SPACE — всплывать; с разгона — выпрыгнуть\n"
			+ "CTRL — нырять\n"
			+ "SHIFT — ускорение\n"
			+ "E — поймать рыбу\n"
			+ "F — выбраться на льдину\n"
			+ "V — голос Флэки\n"
			+ "ESC — пауза"
		),
		"BUTTON_BACK": "НАЗАД",
		"ACHIEVEMENTS_TITLE": "ДОСТИЖЕНИЯ",
		"ACHIEVEMENTS_PROGRESS": "Открыто: %d/%d",
		"ACHIEVEMENT_HIDDEN_NAME": "СКРЫТОЕ ДОСТИЖЕНИЕ",
		"ACHIEVEMENT_HIDDEN_DESC": "Условие откроется вместе с наградой.",
		"ACHIEVEMENT_UNLOCKED_TOAST": "ДОСТИЖЕНИЕ ОТКРЫТО",
		"ACH_TREASURE_NAME": "Сокровище глубин",
		"ACH_TREASURE_DESC": "Найти тайник осьминога в ледяной пещере.",
		"ACH_CRAB_DANCE_NAME": "Танцуй, клешня!",
		"ACH_CRAB_DANCE_DESC": "Голосом Флэки заставить краба пуститься в пляс.",
		"ACH_FLYING_SEAL_NAME": "Летучий тюлень",
		"ACH_FLYING_SEAL_DESC": "Впервые выпрыгнуть из воды с разгона.",
		"ACH_UNTOUCHABLE_NAME": "Не по зубам",
		"ACH_UNTOUCHABLE_DESC": "Завершить демо без единого укуса акулы.",
		"ACH_FISH_DAY_NAME": "Рыбный день",
		"ACH_FISH_DAY_DESC": "Поймать все 10 рыб и выполнить главную цель.",
		"ACH_VOCALIST_NAME": "Вокалист",
		"ACH_VOCALIST_DESC": "Подать голос Флэки 5 раз за один заплыв.",
		"ACH_SEAL_REST_NAME": "Морской котик отдыхает",
		"ACH_SEAL_REST_DESC": "Непрерывно пролежать на льдине 30 секунд.",
		"ACH_FREE_SWIMMER_NAME": "Вольный плавец",
		"ACH_FREE_SWIMMER_DESC": "После победы продолжить плавание в свободном режиме.",
		"CREDITS_TITLE": "АВТОРЫ",
		"CREDITS_PRIMARY": (
			"ИДЕЯ СОЗДАНИЯ\n"
			+ "Катарина\n\n"
			+ "РАЗРАБОТКА И КОД\n"
			+ "Мириэль и OpenAI Codex (GPT-5)\n\n"
			+ "ИЛЛЮСТРАЦИИ ДОСТИЖЕНИЙ\n"
			+ "Мириэль и OpenAI ImageGen\n\n"
			+ "МУЗЫКА И ГОЛОС ФЛЭКИ\n"
			+ "Созданы Катариной в Suno"
		),
		"CREDITS_ASSETS": (
			"3D-МОДЕЛИ\n"
			+ "Рыбы и акула — Quaternius (CC0)\n"
			+ "Сундук с золотом — Quaternius (CC0)\n"
			+ "Краб — новая модель; анимации Quaternius (CC0)\n"
			+ "Осьминог — оригинальная процедурная модель\n"
			+ "Келп — Poly by Google (CC BY)\n"
			+ "Rock Boulder Dry — D. Savva, R. Cilliers (CC0)\n\n"
			+ "ТЕКСТУРЫ И ЗВУКИ\n"
			+ "Low Tide Rocks — Dimitrios Savva / Poly Haven (CC0)\n"
			+ "Snow 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Water SFX — rubberduck / OpenGameArt (CC0)"
		),
		"CREDITS_BODY": (
			"ИДЕЯ СОЗДАНИЯ\n"
			+ "Катарина\n\n"
			+ "РАЗРАБОТКА И КОД\n"
			+ "Мириэль и OpenAI Codex (GPT-5)\n\n"
			+ "ИЛЛЮСТРАЦИИ ДОСТИЖЕНИЙ\n"
			+ "Мириэль и OpenAI ImageGen\n\n"
			+ "3D-МОДЕЛИ\n"
			+ "Рыбы и акула — Quaternius (CC0)\n"
			+ "Сундук с золотом — Quaternius (CC0)\n"
			+ "Краб — новая модель; анимации Quaternius (CC0)\n"
			+ "Осьминог — оригинальная процедурная модель\n"
			+ "Келп — Poly by Google (CC BY)\n"
			+ "Rock Boulder Dry — D. Savva, R. Cilliers (CC0)\n\n"
			+ "ТЕКСТУРЫ\n"
			+ "Low Tide Rocks — Dimitrios Savva / Poly Haven (CC0)\n"
			+ "Snow 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Water SFX — rubberduck / OpenGameArt (CC0)\n\n"
			+ "МУЗЫКА И ГОЛОС ФЛЭКИ\n"
			+ "Созданы Катариной в Suno"
		),
		"PAUSE_TITLE": "ПАУЗА",
		"PAUSE_SUBTITLE": "Бухта подождёт. Флэки тоже.",
		"PAUSE_CONTINUE": "ПРОДОЛЖИТЬ",
		"PAUSE_RESTART": "НАЧАТЬ ЗАНОВО",
		"SETTINGS_TITLE": "НАСТРОЙКИ",
		"SETTINGS_DISPLAY_MODE": "РЕЖИМ ЭКРАНА",
		"SETTINGS_DISPLAY_HELP": "Настройки применяются сразу и сохраняются между запусками.",
		"SETTINGS_WINDOWED": "ОКОННЫЙ",
		"SETTINGS_FULLSCREEN": "ПОЛНЫЙ ЭКРАН",
		"SETTINGS_RESOLUTION": "РАЗРЕШЕНИЕ ОКНА",
		"SETTINGS_RESOLUTION_HELP": "Выбранное разрешение используется в оконном режиме.",
		"SETTINGS_LANGUAGE": "ЯЗЫК",
		"SETTINGS_LANGUAGE_HELP": "Язык изменяется сразу и сохраняется автоматически.",
		"SETTINGS_LANGUAGE_RU": "РУССКИЙ",
		"SETTINGS_LANGUAGE_UK": "УКРАЇНСЬКА",
		"SETTINGS_LANGUAGE_EN": "ENGLISH",
		"VICTORY_TITLE": "ДЕМО ЗАВЕРШЕНО",
		"VICTORY_SUBTITLE": "Флэки сыт и отдыхает на льдине.",
		"VICTORY_COUNT": "Поймано рыб: 10/10",
		"VICTORY_FREE_ROAM": "СВОБОДНОЕ ПЛАВАНИЕ",
		"VICTORY_REPLAY": "СЫГРАТЬ СНОВА",
		"VICTORY_MAIN_MENU": "В ГЛАВНОЕ МЕНЮ",
		"HUD_TITLE": "FLECKY  •  ЛЕДЯНАЯ БУХТА",
		"HUD_CONTROLS": (
			"WASD  — плыть\n"
			+ "МЫШЬ  — камера\n"
			+ "SPACE  — вверх / прыжок\n"
			+ "CTRL  — нырнуть\n"
			+ "SHIFT  — ускорение\n"
			+ "E  — поймать рыбу\n"
			+ "F  — выбраться на лёд\n"
			+ "V  — голос Флэки\n"
			+ "ESC  — пауза"
		),
		"HUD_CONTROLS_FREE": (
			"WASD  — плыть\n"
			+ "МЫШЬ  — камера\n"
			+ "SPACE  — вверх / прыжок\n"
			+ "CTRL  — нырнуть\n"
			+ "SHIFT  — ускорение\n"
			+ "F  — льдина / вода\n"
			+ "V  — голос Флэки\n"
			+ "ESC  — пауза"
		),
		"HUD_OBJECTIVE": "ЦЕЛЬ: ПОЙМАЙТЕ 10 РЫБ",
		"HUD_OBJECTIVE_COMPLETE": "ЦЕЛЬ ВЫПОЛНЕНА — ФЛЭКИ СЫТ!",
		"HUD_FREE_ROAM": "СВОБОДНЫЙ РЕЖИМ • ИССЛЕДУЙТЕ БУХТУ",
		"HUD_FISH_COUNT": "РЫБА  %d/%d",
		"HUD_DEPTH": "ГЛУБИНА  %.1f м",
		"STATE_SURFACE": "НА ПОВЕРХНОСТИ",
		"STATE_SAVED": "СПАСЁН НА ЛЬДИНЕ",
		"STATE_RETURNING_WITH_CATCH": "ВОЗВРАЩАЕТСЯ С УЛОВОМ",
		"STATE_VICTORY": "ФЛЭКИ СЫТ И СЧАСТЛИВ",
		"STATE_CLIMBING": "ВЫБИРАЕТСЯ НА ЛЬДИНУ",
		"STATE_ENTERING_WATER": "СПУСКАЕТСЯ В ВОДУ",
		"STATE_RESTING": "ОТДЫХАЕТ НА ЛЬДИНЕ",
		"STATE_BOOST": "УСКОРЕНИЕ",
		"STATE_DIVE": "ПОГРУЖЕНИЕ",
		"STATE_DRIFT": "ДРЕЙФ",
		"STATE_BREACH": "ПРЫЖОК НАД ВОДОЙ",
		"STATE_SPLASH": "ПЛЮХ!",
		"PROMPT_CATCH_FISH": "E  —  ПОЙМАТЬ РЫБУ",
		"PROMPT_FISH_CAUGHT": "НЯМ!  РЫБА ПОЙМАНА",
		"PROMPT_RETURN_WATER": "F  —  ВЕРНУТЬСЯ В ВОДУ",
		"PROMPT_CLIMB_ICE": "F  —  ВЫБРАТЬСЯ НА ЛЬДИНУ",
		"PROMPT_ALL_FISH": "10/10  •  ВСЯ РЫБА ПОЙМАНА",
		"PROMPT_BITTEN": "ФЛЭКИ УКУШЕН — СКОРЕЕ НА ЛЬДИНУ!",
		"PROMPT_RESPAWNED": "ФЛЭКИ СПАСЁН НА БЛИЖАЙШЕЙ ЛЬДИНЕ",
		"SHARK_SHADOW": "ТЕНЬ ПОД ВОДОЙ…",
		"SHARK_HIDE": "УКРОЙТЕСЬ НА ЛЬДИНЕ ИЛИ В ПЕЩЕРЕ!",
		"PROMPT_CAVE_SAFE": "В ПЕЩЕРЕ БЕЗОПАСНО — АКУЛА СЮДА НЕ ПРОЙДЁТ",
		"SHARK_CAVE_WAIT": "АКУЛА ЖДЁТ СНАРУЖИ…",
		"SHARK_CIRCLING": "АКУЛА КРУЖИТ У ЛЬДИНЫ…",
		"SHARK_LEAVING": "АКУЛА УПЛЫВАЕТ…",
	},
	"uk": {
		"GAME_TITLE": "FLECKY",
		"GAME_SUBTITLE": "ADVENTURES IN ICY WATERS",
		"MENU_TAGLINE": "Маленька пригода у великій крижаній бухті",
		"MENU_START": "ПОЧАТИ ПРИГОДУ",
		"MENU_CONTROLS": "КЕРУВАННЯ",
		"MENU_SETTINGS": "НАЛАШТУВАННЯ",
		"MENU_ACHIEVEMENTS": "ДОСЯГНЕННЯ",
		"MENU_CREDITS": "АВТОРИ",
		"MENU_EXIT": "ВИЙТИ",
		"MENU_MUSIC": "Музика: Ice Bay Drift",
		"CONTROLS_TITLE": "ЯК ГРАТИ",
		"CONTROLS_BODY": (
			"WASD — плисти й повертати\n"
			+ "МИША — керувати камерою\n"
			+ "SPACE — спливати; з розгону — вистрибнути\n"
			+ "CTRL — пірнати\n"
			+ "SHIFT — прискорення\n"
			+ "E — зловити рибу\n"
			+ "F — вибратися на крижину\n"
			+ "V — голос Флекі\n"
			+ "ESC — пауза"
		),
		"BUTTON_BACK": "НАЗАД",
		"ACHIEVEMENTS_TITLE": "ДОСЯГНЕННЯ",
		"ACHIEVEMENTS_PROGRESS": "Відкрито: %d/%d",
		"ACHIEVEMENT_HIDDEN_NAME": "ПРИХОВАНЕ ДОСЯГНЕННЯ",
		"ACHIEVEMENT_HIDDEN_DESC": "Умова відкриється разом із нагородою.",
		"ACHIEVEMENT_UNLOCKED_TOAST": "ДОСЯГНЕННЯ ВІДКРИТО",
		"ACH_TREASURE_NAME": "Скарб глибин",
		"ACH_TREASURE_DESC": "Знайти схованку восьминога в крижаній печері.",
		"ACH_CRAB_DANCE_NAME": "Танцюй, клешне!",
		"ACH_CRAB_DANCE_DESC": "Голосом Флекі змусити краба пуститися в танок.",
		"ACH_FLYING_SEAL_NAME": "Летючий тюлень",
		"ACH_FLYING_SEAL_DESC": "Уперше вистрибнути з води з розгону.",
		"ACH_UNTOUCHABLE_NAME": "Не по зубах",
		"ACH_UNTOUCHABLE_DESC": "Завершити демо без жодного укусу акули.",
		"ACH_FISH_DAY_NAME": "Рибний день",
		"ACH_FISH_DAY_DESC": "Спіймати всі 10 риб і виконати головну мету.",
		"ACH_VOCALIST_NAME": "Вокаліст",
		"ACH_VOCALIST_DESC": "Подати голос Флекі 5 разів за один заплив.",
		"ACH_SEAL_REST_NAME": "Морський котик відпочиває",
		"ACH_SEAL_REST_DESC": "Безперервно пролежати на крижині 30 секунд.",
		"ACH_FREE_SWIMMER_NAME": "Вільний плавець",
		"ACH_FREE_SWIMMER_DESC": "Після перемоги продовжити плавання у вільному режимі.",
		"CREDITS_TITLE": "АВТОРИ",
		"CREDITS_PRIMARY": (
			"ІДЕЯ СТВОРЕННЯ\n"
			+ "Катарина\n\n"
			+ "РОЗРОБКА ТА КОД\n"
			+ "Міріель та OpenAI Codex (GPT-5)\n\n"
			+ "ІЛЮСТРАЦІЇ ДОСЯГНЕНЬ\n"
			+ "Міріель та OpenAI ImageGen\n\n"
			+ "МУЗИКА ТА ГОЛОС ФЛЕКІ\n"
			+ "Створені Катариною в Suno"
		),
		"CREDITS_ASSETS": (
			"3D-МОДЕЛІ\n"
			+ "Риби й акула — Quaternius (CC0)\n"
			+ "Скриня із золотом — Quaternius (CC0)\n"
			+ "Краб — нова модель; анімації Quaternius (CC0)\n"
			+ "Восьминіг — оригінальна процедурна модель\n"
			+ "Келп — Poly by Google (CC BY)\n"
			+ "Rock Boulder Dry — D. Savva, R. Cilliers (CC0)\n\n"
			+ "ТЕКСТУРИ ТА ЗВУКИ\n"
			+ "Low Tide Rocks — Dimitrios Savva / Poly Haven (CC0)\n"
			+ "Snow 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Water SFX — rubberduck / OpenGameArt (CC0)"
		),
		"CREDITS_BODY": (
			"ІДЕЯ СТВОРЕННЯ\n"
			+ "Катарина\n\n"
			+ "РОЗРОБКА ТА КОД\n"
			+ "Міріель та OpenAI Codex (GPT-5)\n\n"
			+ "ІЛЮСТРАЦІЇ ДОСЯГНЕНЬ\n"
			+ "Міріель та OpenAI ImageGen\n\n"
			+ "3D-МОДЕЛІ\n"
			+ "Риби й акула — Quaternius (CC0)\n"
			+ "Скриня із золотом — Quaternius (CC0)\n"
			+ "Краб — нова модель; анімації Quaternius (CC0)\n"
			+ "Восьминіг — оригінальна процедурна модель\n"
			+ "Келп — Poly by Google (CC BY)\n"
			+ "Rock Boulder Dry — D. Savva, R. Cilliers (CC0)\n\n"
			+ "ТЕКСТУРИ\n"
			+ "Low Tide Rocks — Dimitrios Savva / Poly Haven (CC0)\n"
			+ "Snow 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Water SFX — rubberduck / OpenGameArt (CC0)\n\n"
			+ "МУЗИКА ТА ГОЛОС ФЛЕКІ\n"
			+ "Створені Катариною в Suno"
		),
		"PAUSE_TITLE": "ПАУЗА",
		"PAUSE_SUBTITLE": "Бухта зачекає. Флекі теж.",
		"PAUSE_CONTINUE": "ПРОДОВЖИТИ",
		"PAUSE_RESTART": "ПОЧАТИ ЗНОВУ",
		"SETTINGS_TITLE": "НАЛАШТУВАННЯ",
		"SETTINGS_DISPLAY_MODE": "РЕЖИМ ЕКРАНА",
		"SETTINGS_DISPLAY_HELP": "Налаштування застосовуються одразу й зберігаються між запусками.",
		"SETTINGS_WINDOWED": "У ВІКНІ",
		"SETTINGS_FULLSCREEN": "НА ВЕСЬ ЕКРАН",
		"SETTINGS_RESOLUTION": "РОЗДІЛЬНА ЗДАТНІСТЬ ВІКНА",
		"SETTINGS_RESOLUTION_HELP": "Вибрана роздільна здатність використовується у віконному режимі.",
		"SETTINGS_LANGUAGE": "МОВА",
		"SETTINGS_LANGUAGE_HELP": "Мова змінюється одразу й зберігається автоматично.",
		"SETTINGS_LANGUAGE_RU": "РУССКИЙ",
		"SETTINGS_LANGUAGE_UK": "УКРАЇНСЬКА",
		"SETTINGS_LANGUAGE_EN": "ENGLISH",
		"VICTORY_TITLE": "ДЕМО ЗАВЕРШЕНО",
		"VICTORY_SUBTITLE": "Флекі ситий і відпочиває на крижині.",
		"VICTORY_COUNT": "Спіймано риб: 10/10",
		"VICTORY_FREE_ROAM": "ВІЛЬНЕ ПЛАВАННЯ",
		"VICTORY_REPLAY": "ЗІГРАТИ ЩЕ РАЗ",
		"VICTORY_MAIN_MENU": "ДО ГОЛОВНОГО МЕНЮ",
		"HUD_TITLE": "FLECKY  •  КРИЖАНА БУХТА",
		"HUD_CONTROLS": (
			"WASD  — плисти\n"
			+ "МИША  — камера\n"
			+ "SPACE  — вгору / стрибок\n"
			+ "CTRL  — пірнути\n"
			+ "SHIFT  — прискорення\n"
			+ "E  — зловити рибу\n"
			+ "F  — вибратися на крижину\n"
			+ "V  — голос Флекі\n"
			+ "ESC  — пауза"
		),
		"HUD_CONTROLS_FREE": (
			"WASD  — плисти\n"
			+ "МИША  — камера\n"
			+ "SPACE  — вгору / стрибок\n"
			+ "CTRL  — пірнути\n"
			+ "SHIFT  — прискорення\n"
			+ "F  — крижина / вода\n"
			+ "V  — голос Флекі\n"
			+ "ESC  — пауза"
		),
		"HUD_OBJECTIVE": "МЕТА: СПІЙМАЙТЕ 10 РИБ",
		"HUD_OBJECTIVE_COMPLETE": "МЕТУ ВИКОНАНО — ФЛЕКІ СИТИЙ!",
		"HUD_FREE_ROAM": "ВІЛЬНИЙ РЕЖИМ • ДОСЛІДЖУЙТЕ БУХТУ",
		"HUD_FISH_COUNT": "РИБА  %d/%d",
		"HUD_DEPTH": "ГЛИБИНА  %.1f м",
		"STATE_SURFACE": "НА ПОВЕРХНІ",
		"STATE_SAVED": "ВРЯТОВАНИЙ НА КРИЖИНІ",
		"STATE_RETURNING_WITH_CATCH": "ПОВЕРТАЄТЬСЯ З УЛОВОМ",
		"STATE_VICTORY": "ФЛЕКІ СИТИЙ І ЩАСЛИВИЙ",
		"STATE_CLIMBING": "ВИБИРАЄТЬСЯ НА КРИЖИНУ",
		"STATE_ENTERING_WATER": "СПУСКАЄТЬСЯ У ВОДУ",
		"STATE_RESTING": "ВІДПОЧИВАЄ НА КРИЖИНІ",
		"STATE_BOOST": "ПРИСКОРЕННЯ",
		"STATE_DIVE": "ЗАНУРЕННЯ",
		"STATE_DRIFT": "ДРЕЙФ",
		"STATE_BREACH": "СТРИБОК НАД ВОДОЮ",
		"STATE_SPLASH": "ПЛЮХ!",
		"PROMPT_CATCH_FISH": "E  —  ЗЛОВИТИ РИБУ",
		"PROMPT_FISH_CAUGHT": "НЯМ!  РИБУ СПІЙМАНО",
		"PROMPT_RETURN_WATER": "F  —  ПОВЕРНУТИСЯ У ВОДУ",
		"PROMPT_CLIMB_ICE": "F  —  ВИБРАТИСЯ НА КРИЖИНУ",
		"PROMPT_ALL_FISH": "10/10  •  УСЮ РИБУ СПІЙМАНО",
		"PROMPT_BITTEN": "ФЛЕКІ ВКУСИЛИ — МЕРЩІЙ НА КРИЖИНУ!",
		"PROMPT_RESPAWNED": "ФЛЕКІ ВРЯТОВАНИЙ НА НАЙБЛИЖЧІЙ КРИЖИНІ",
		"SHARK_SHADOW": "ТІНЬ ПІД ВОДОЮ…",
		"SHARK_HIDE": "СХОВАЙТЕСЯ НА КРИЖИНІ АБО В ПЕЧЕРІ!",
		"PROMPT_CAVE_SAFE": "У ПЕЧЕРІ БЕЗПЕЧНО — АКУЛА СЮДИ НЕ ПРОЙДЕ",
		"SHARK_CAVE_WAIT": "АКУЛА ЧЕКАЄ ЗОВНІ…",
		"SHARK_CIRCLING": "АКУЛА КРУЖЛЯЄ БІЛЯ КРИЖИНИ…",
		"SHARK_LEAVING": "АКУЛА ВІДПЛИВАЄ…",
	},
	"en": {
		"GAME_TITLE": "FLECKY",
		"GAME_SUBTITLE": "ADVENTURES IN ICY WATERS",
		"MENU_TAGLINE": "A little adventure in a great icy bay",
		"MENU_START": "START ADVENTURE",
		"MENU_CONTROLS": "CONTROLS",
		"MENU_SETTINGS": "SETTINGS",
		"MENU_ACHIEVEMENTS": "ACHIEVEMENTS",
		"MENU_CREDITS": "CREDITS",
		"MENU_EXIT": "EXIT",
		"MENU_MUSIC": "Music: Ice Bay Drift",
		"CONTROLS_TITLE": "HOW TO PLAY",
		"CONTROLS_BODY": (
			"WASD — swim and turn\n"
			+ "MOUSE — control the camera\n"
			+ "SPACE — ascend; hold at speed to breach\n"
			+ "CTRL — dive\n"
			+ "SHIFT — boost\n"
			+ "E — catch a fish\n"
			+ "F — climb onto the ice\n"
			+ "V — Flecky's voice\n"
			+ "ESC — pause"
		),
		"BUTTON_BACK": "BACK",
		"ACHIEVEMENTS_TITLE": "ACHIEVEMENTS",
		"ACHIEVEMENTS_PROGRESS": "Unlocked: %d/%d",
		"ACHIEVEMENT_HIDDEN_NAME": "HIDDEN ACHIEVEMENT",
		"ACHIEVEMENT_HIDDEN_DESC": "Its condition will be revealed when unlocked.",
		"ACHIEVEMENT_UNLOCKED_TOAST": "ACHIEVEMENT UNLOCKED",
		"ACH_TREASURE_NAME": "Treasure of the Depths",
		"ACH_TREASURE_DESC": "Discover the octopus's hoard inside the ice cave.",
		"ACH_CRAB_DANCE_NAME": "Dance, Claw, Dance!",
		"ACH_CRAB_DANCE_DESC": "Use Flecky's voice to make a nearby crab dance.",
		"ACH_FLYING_SEAL_NAME": "Flying Seal",
		"ACH_FLYING_SEAL_DESC": "Breach out of the water at speed for the first time.",
		"ACH_UNTOUCHABLE_NAME": "Not a Bite",
		"ACH_UNTOUCHABLE_DESC": "Complete the demo without a single shark bite.",
		"ACH_FISH_DAY_NAME": "Fish Day",
		"ACH_FISH_DAY_DESC": "Catch all 10 fish and complete the main objective.",
		"ACH_VOCALIST_NAME": "Vocalist",
		"ACH_VOCALIST_DESC": "Use Flecky's voice 5 times during a single swim.",
		"ACH_SEAL_REST_NAME": "Resting Seal",
		"ACH_SEAL_REST_DESC": "Remain resting on an ice floe for 30 uninterrupted seconds.",
		"ACH_FREE_SWIMMER_NAME": "Free Swimmer",
		"ACH_FREE_SWIMMER_DESC": "After victory, continue swimming in free-roam mode.",
		"CREDITS_TITLE": "CREDITS",
		"CREDITS_PRIMARY": (
			"ORIGINAL IDEA\n"
			+ "Katarina\n\n"
			+ "DEVELOPMENT AND CODE\n"
			+ "Miriel and OpenAI Codex (GPT-5)\n\n"
			+ "ACHIEVEMENT ILLUSTRATIONS\n"
			+ "Miriel and OpenAI ImageGen\n\n"
			+ "MUSIC AND FLECKY'S VOICE\n"
			+ "Created by Katarina with Suno"
		),
		"CREDITS_ASSETS": (
			"3D MODELS\n"
			+ "Fish and shark — Quaternius (CC0)\n"
			+ "Chest with Gold — Quaternius (CC0)\n"
			+ "Crab — original mesh; Quaternius animations (CC0)\n"
			+ "Octopus — original procedural model\n"
			+ "Coast Sand 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Rock Boulder Dry — D. Savva, R. Cilliers (CC0)\n\n"
			+ "TEXTURES AND SOUNDS\n"
			+ "Low Tide Rocks — Dimitrios Savva / Poly Haven (CC0)\n"
			+ "Snow 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Water SFX — rubberduck / OpenGameArt (CC0)"
		),
		"CREDITS_BODY": (
			"ORIGINAL IDEA\n"
			+ "Katarina\n\n"
			+ "DEVELOPMENT AND CODE\n"
			+ "Miriel and OpenAI Codex (GPT-5)\n\n"
			+ "ACHIEVEMENT ILLUSTRATIONS\n"
			+ "Miriel and OpenAI ImageGen\n\n"
			+ "3D MODELS\n"
			+ "Fish and shark — Quaternius (CC0)\n"
			+ "Chest with Gold — Quaternius (CC0)\n"
			+ "Crab — original mesh; Quaternius animations (CC0)\n"
			+ "Octopus — original procedural model\n"
			+ "Coast Sand 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Rock Boulder Dry — D. Savva, R. Cilliers (CC0)\n\n"
			+ "TEXTURES\n"
			+ "Low Tide Rocks — Dimitrios Savva / Poly Haven (CC0)\n"
			+ "Snow 02 — Rob Tuytel / Poly Haven (CC0)\n"
			+ "Water SFX — rubberduck / OpenGameArt (CC0)\n\n"
			+ "MUSIC AND FLECKY'S VOICE\n"
			+ "Created by Katarina with Suno"
		),
		"PAUSE_TITLE": "PAUSED",
		"PAUSE_SUBTITLE": "The bay can wait. So can Flecky.",
		"PAUSE_CONTINUE": "CONTINUE",
		"PAUSE_RESTART": "RESTART",
		"SETTINGS_TITLE": "SETTINGS",
		"SETTINGS_DISPLAY_MODE": "DISPLAY MODE",
		"SETTINGS_DISPLAY_HELP": "Settings apply immediately and are saved between sessions.",
		"SETTINGS_WINDOWED": "WINDOWED",
		"SETTINGS_FULLSCREEN": "FULLSCREEN",
		"SETTINGS_RESOLUTION": "WINDOW RESOLUTION",
		"SETTINGS_RESOLUTION_HELP": "The selected resolution is used in windowed mode.",
		"SETTINGS_LANGUAGE": "LANGUAGE",
		"SETTINGS_LANGUAGE_HELP": "Language changes immediately and is saved automatically.",
		"SETTINGS_LANGUAGE_RU": "РУССКИЙ",
		"SETTINGS_LANGUAGE_UK": "УКРАЇНСЬКА",
		"SETTINGS_LANGUAGE_EN": "ENGLISH",
		"VICTORY_TITLE": "DEMO COMPLETE",
		"VICTORY_SUBTITLE": "Flecky is full and resting on the ice.",
		"VICTORY_COUNT": "Fish caught: 10/10",
		"VICTORY_FREE_ROAM": "FREE SWIM",
		"VICTORY_REPLAY": "PLAY AGAIN",
		"VICTORY_MAIN_MENU": "MAIN MENU",
		"HUD_TITLE": "FLECKY  •  ICY BAY",
		"HUD_CONTROLS": (
			"WASD  — swim\n"
			+ "MOUSE  — camera\n"
			+ "SPACE  — up / breach\n"
			+ "CTRL  — dive\n"
			+ "SHIFT  — boost\n"
			+ "E  — catch a fish\n"
			+ "F  — climb onto the ice\n"
			+ "V  — Flecky's voice\n"
			+ "ESC  — pause"
		),
		"HUD_CONTROLS_FREE": (
			"WASD  — swim\n"
			+ "MOUSE  — camera\n"
			+ "SPACE  — up / breach\n"
			+ "CTRL  — dive\n"
			+ "SHIFT  — boost\n"
			+ "F  — ice / water\n"
			+ "V  — Flecky's voice\n"
			+ "ESC  — pause"
		),
		"HUD_OBJECTIVE": "OBJECTIVE: CATCH 10 FISH",
		"HUD_OBJECTIVE_COMPLETE": "OBJECTIVE COMPLETE — FLECKY IS FULL!",
		"HUD_FREE_ROAM": "FREE ROAM • EXPLORE THE BAY",
		"HUD_FISH_COUNT": "FISH  %d/%d",
		"HUD_DEPTH": "DEPTH  %.1f m",
		"STATE_SURFACE": "AT THE SURFACE",
		"STATE_SAVED": "SAFE ON THE ICE",
		"STATE_RETURNING_WITH_CATCH": "RETURNING WITH THE CATCH",
		"STATE_VICTORY": "FLECKY IS FULL AND HAPPY",
		"STATE_CLIMBING": "CLIMBING ONTO THE ICE",
		"STATE_ENTERING_WATER": "ENTERING THE WATER",
		"STATE_RESTING": "RESTING ON THE ICE",
		"STATE_BOOST": "BOOST",
		"STATE_DIVE": "DIVING",
		"STATE_DRIFT": "DRIFTING",
		"STATE_BREACH": "BREACHING",
		"STATE_SPLASH": "SPLASH!",
		"PROMPT_CATCH_FISH": "E  —  CATCH FISH",
		"PROMPT_FISH_CAUGHT": "YUM!  FISH CAUGHT",
		"PROMPT_RETURN_WATER": "F  —  RETURN TO WATER",
		"PROMPT_CLIMB_ICE": "F  —  CLIMB ONTO THE ICE",
		"PROMPT_ALL_FISH": "10/10  •  ALL FISH CAUGHT",
		"PROMPT_BITTEN": "FLECKY WAS BITTEN — GET TO THE ICE!",
		"PROMPT_RESPAWNED": "FLECKY IS SAFE ON THE NEAREST ICE FLOE",
		"SHARK_SHADOW": "A SHADOW UNDER THE WATER…",
		"SHARK_HIDE": "HIDE ON THE ICE OR INSIDE THE CAVE!",
		"PROMPT_CAVE_SAFE": "SAFE INSIDE THE CAVE — THE SHARK CANNOT REACH YOU",
		"SHARK_CAVE_WAIT": "THE SHARK IS WAITING OUTSIDE…",
		"SHARK_CIRCLING": "THE SHARK IS CIRCLING THE ICE…",
		"SHARK_LEAVING": "THE SHARK IS LEAVING…",
	},
}


func _ready() -> void:
	_install_translations()
	_load_language()


func set_language(language_code: String, save: bool = true) -> void:
	if language_code not in SUPPORTED_LANGUAGES:
		language_code = DEFAULT_LANGUAGE
	current_language = language_code
	TranslationServer.set_locale(language_code)
	if save:
		_save_language()
	language_changed.emit(language_code)


func cycle_language() -> void:
	var current_index := SUPPORTED_LANGUAGES.find(current_language)
	var next_index := posmod(current_index + 1, SUPPORTED_LANGUAGES.size())
	set_language(SUPPORTED_LANGUAGES[next_index])


func get_language_button_key() -> String:
	return "SETTINGS_LANGUAGE_%s" % current_language.to_upper()


func has_complete_catalogs() -> bool:
	if _messages.size() != SUPPORTED_LANGUAGES.size():
		return false
	var reference_keys: Array = _messages[DEFAULT_LANGUAGE].keys()
	for language_code in SUPPORTED_LANGUAGES:
		if _messages[language_code].size() != reference_keys.size():
			return false
		for key in reference_keys:
			if not _messages[language_code].has(key):
				return false
	return true


func _install_translations() -> void:
	for language_code in SUPPORTED_LANGUAGES:
		var translation := Translation.new()
		translation.locale = language_code
		for key in _messages[language_code]:
			translation.add_message(key, _messages[language_code][key])
		TranslationServer.add_translation(translation)


func _load_language() -> void:
	var config := ConfigFile.new()
	var language_code := DEFAULT_LANGUAGE
	if config.load(SETTINGS_PATH) == OK:
		language_code = str(config.get_value("localization", "language", DEFAULT_LANGUAGE))
	set_language(language_code, false)


func _save_language() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("localization", "language", current_language)
	var save_result := config.save(SETTINGS_PATH)
	if save_result != OK:
		push_warning("Could not save language settings: %s" % error_string(save_result))
