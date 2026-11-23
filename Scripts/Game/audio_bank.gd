class_name AudioBank
extends Node
## Banco de audio del juego: MUSICA de fondo (con fundido) y EFECTOS de sonido.
## Lo crea GameManager (autoload), asi que en cualquier script se usa con:
##     GameManager.sfx("explosion")          # efecto
##     GameManager.play_music("calma")       # musica de fondo (bucle)
## Los archivos estan en res://Assets/Audio/sfx/ y res://Assets/Audio/music/ (formato .ogg).

const SFX_DIR: String = "res://Assets/Audio/sfx/"
const MUSIC_DIR: String = "res://Assets/Audio/music/"
const SFX_VOICES: int = 8
## Volumen (dB) de la musica de fondo y de los efectos. Bajalos o subelos a tu gusto.
const MUSIC_DB: float = -10.0
const SFX_DB: float = -4.0
const SILENT_DB: float = -60.0

var music_on: bool = true
var _cache: Dictionary = {}
var _warned: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_name: String = ""
var _tween: Tween


func _ready() -> void:
	# Debe sonar tambien cuando el juego esta en pausa (trivia, dialogos)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = SILENT_DB
	add_child(_music)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		if not _warned.has(path):
			_warned[path] = true
			push_warning("Falta el sonido: " + path + " (copia la carpeta Assets/Audio al proyecto)")
		return null
	var stream := load(path) as AudioStream
	_cache[path] = stream
	return stream


## Reproduce un efecto de sonido por nombre (sin extension). Varios pueden sonar a la vez.
func sfx(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _load(SFX_DIR + sound + ".ogg")
	if stream == null:
		return
	var voice: AudioStreamPlayer = _voices[0]
	for v in _voices:
		if not v.playing:
			voice = v
			break
	voice.stream = stream
	voice.volume_db = SFX_DB + volume_db
	voice.pitch_scale = pitch
	voice.play()


## Musica de fondo en bucle. Si ya suena la misma, no hace nada; si es otra, hace un fundido.
func play_music(track: String, fade: float = 1.2) -> void:
	if track == _music_name and _music.playing:
		return
	var stream := _load(MUSIC_DIR + track + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_name = track
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if _music.playing:
		_tween.tween_property(_music, "volume_db", SILENT_DB, fade * 0.5)
	_tween.tween_callback(_start_music.bind(stream))
	_tween.tween_property(_music, "volume_db", MUSIC_DB, fade)


func _start_music(stream: AudioStream) -> void:
	_music.stream = stream
	_music.volume_db = SILENT_DB
	_music.stream_paused = not music_on
	_music.play()


func stop_music(fade: float = 1.0) -> void:
	_music_name = ""
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_music, "volume_db", SILENT_DB, fade)
	_tween.tween_callback(_music.stop)


## Enciende o apaga la musica (tecla M). Devuelve el nuevo estado.
func toggle_music() -> bool:
	music_on = not music_on
	_music.stream_paused = not music_on
	return music_on
