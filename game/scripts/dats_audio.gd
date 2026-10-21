class_name DatsAudio
extends Node
static func instance() -> DatsAudio:
	return Engine.get_main_loop().root.get_node("Sound") as DatsAudio
## Original score/effects. Separate preferences; no use of the physics RNG.
var music_enabled := true
var effects_enabled := true
var music_volume := .45
var effects_volume := .70
var screen_shake := true
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var streams := {}
var last_play := {}
var track := ""
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	var cfg := ConfigFile.new()
	if cfg.load("user://sound.cfg")==OK:
		music_enabled = cfg.get_value("audio","music_enabled",true)
		effects_enabled = cfg.get_value("audio","effects_enabled",true)
		music_volume = clampf(float(cfg.get_value("audio","music_volume",.45)),0,1)
		effects_volume = clampf(float(cfg.get_value("audio","effects_volume",.7)),0,1)
		screen_shake = cfg.get_value("audio","screen_shake",true)
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 12:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
func persist() -> void:
	var cfg := ConfigFile.new()
	for key in ["music_enabled","effects_enabled","music_volume","effects_volume","screen_shake"]: cfg.set_value("audio",key,get(key))
	cfg.save("user://sound.cfg")
	apply_levels()
func apply_levels() -> void:
	music.volume_db = linear_to_db(maxf(.0001,music_volume*.32))
	music.stream_paused = not music_enabled
	for voice in voices:
		voice.volume_db = linear_to_db(maxf(.0001,effects_volume*.60))
		if not effects_enabled: voice.stop()
func stream(key: String) -> AudioStream:
	if not streams.has(key): streams[key] = load("res://audio/"+key+".wav")
	return streams[key]
func play_music(key := "music_workshop") -> void:
	if DisplayServer.get_name()=="headless": return
	if track==key: apply_levels(); return
	track = key
	var audio: AudioStreamWAV = stream(key)
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_begin = 0
	audio.loop_end = roundi(audio.get_length()*audio.mix_rate)
	music.stream = audio
	music.play()
	apply_levels()
func effect(key: String) -> void:
	if key not in ["ui_click","equip","laser_charge","laser","rocket","explosion","minigun","cannon","blaster","impact","blade","chainsaw","drill","boost","balloon_launch","balloon_inflate","balloon_pop","harpoon","cable","forklift","net","repulse","countdown","heal","victory","defeat"]: return
	if not effects_enabled or effects_volume<=0 or DisplayServer.get_name()=="headless": return
	var now := Time.get_ticks_msec()
	var gap := 55 if key=="minigun" else (180 if key in ["impact","chainsaw","drill","blade"] else 60)
	if now-int(last_play.get(key,-10000))<gap: return
	last_play[key] = now
	for voice in voices:
		if not voice.playing:
			voice.stream = stream(key)
			voice.pitch_scale = rng.randf_range(.97,1.03)
			voice.volume_db = linear_to_db(maxf(.0001,effects_volume*.60))
			voice.play()
			return
func _notification(what: int) -> void:
	if not is_instance_valid(music): return
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		music.stream_paused = true
		for voice in voices: voice.stop()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: apply_levels()

func _exit_tree() -> void:
	stop_all()

func stop_all() -> void:
	if is_instance_valid(music): music.stop(); music.stream = null
	for voice in voices:
		if is_instance_valid(voice): voice.stop(); voice.stream = null
	streams.clear()
