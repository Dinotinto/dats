extends Node
## Entry point: a garage for both cars, then battles.
## Command-line (after "--"): --autotest runs a batch of matchups and prints results; --demo starts a fight;
## --garage-shot just shows the garage (for screenshots).

var builds := [
	{"driver": "bolt", "chassis": "classic", "wheels": "rubber_medium", "front": "drill", "gadget": "booster"},
	{"driver": "tank", "chassis": "surfer", "wheels": "metal_medium", "front": "rocket", "gadget": "first_aid"},
]
var inventory := Inventory.new()
var _battle: Battle
var _garage: Control
var _launch: DatsLaunch
var _auth: DatsAuthLanding
var _hub: DatsHub
var _lobby: PrivateLobby
var social: DatsSocial
var _tests := []
var _test_index := 0
var _test_results: Array = []
var reward_message := ""
var player_mode := false
var cloud: CloudGarage
var cloud_mode := false
var offline_inventory: Inventory
var offline_builds: Array = []
var account_dialog: ConfirmationDialog
var market_dialog: DatsMarket
var settings_dialog: AcceptDialog
var cloud_status := "Offline practice"
var battle_settings: Button
var busy_cover: ColorRect
var busy_label: Label

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST: return
	if is_instance_valid(cloud) and cloud.busy: return
	if is_instance_valid(market_dialog) and market_dialog.visible:
		market_dialog.hide()
	elif is_instance_valid(settings_dialog) and settings_dialog.visible:
		DatsAudio.instance().persist()
		settings_dialog.hide()
	elif is_instance_valid(account_dialog) and account_dialog.visible:
		account_dialog.hide()
	elif is_instance_valid(_lobby):
		if is_instance_valid(_lobby.viewer): _lobby.stop_view()
		elif _lobby.in_garage: _lobby.return_from_garage()
		else: _show_hub()
	elif is_instance_valid(_battle):
		_show_garage()
	elif is_instance_valid(_garage) and player_mode:
		_show_hub()
	else:
		get_tree().quit()



func _ready() -> void:
	DatsAudio.instance().play_music()
	get_tree().root.theme = UI.game_theme()
	for b in builds:
		b.rear_wheel = b.get("wheels", "grip")
		b.front_wheel = b.get("wheels", "grip")
	var args := OS.get_cmdline_user_args()
	player_mode = (OS.has_feature("android") or "--player" in args or "--launch-preview" in args) and not "--dev-garage" in args
	cloud = CloudGarage.new()
	cloud.add_to_group("dats_cloud_input_lock")
	add_child(cloud)
	social = DatsSocial.new()
	add_child(social)
	social.setup(self)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	busy_cover = ColorRect.new()
	busy_cover.color = Color(0,0,0,.65)
	busy_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(busy_cover)
	busy_label = UI.label("Connecting to cloud…",26)
	busy_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	busy_cover.add_child(busy_label)
	busy_cover.hide()
	battle_settings = UI.button("SETTINGS",Color("4D729D"),16,Vector2(145,48))
	battle_settings.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	battle_settings.offset_left = -160
	battle_settings.offset_right = -15
	battle_settings.offset_top = -60
	battle_settings.offset_bottom = -12
	battle_settings.pressed.connect(show_settings)
	overlay.add_child(battle_settings)
	battle_settings.hide()
	inventory.persistence_enabled = not ("--qa-shot" in args or "--isolated" in args)
	if not "--autotest" in args:
		if inventory.persistence_enabled and inventory.restore(): builds=inventory.blueprints
		else: inventory.starter(not player_mode)
		if player_mode and not inventory.blueprints.size():
			builds[0]={"driver":"bolt","chassis":"classic","rear_wheel":"wood_medium","front_wheel":"wood_medium","front":"short_sword","gadget":"booster"}
			builds[1]=builds[0].duplicate(true)
		for i in builds.size(): builds[i]=inventory.synchronize(builds[i],builds[1-i].get("equipped",{}).values())
	if "--autotest" in args:
		_run_autotest()
	elif "--qa-shot" in args:
		_capture_qa()
	elif "--seat-grid" in args:
		_seat_grid()
	elif "--demo" in args:
		_start_battle()
	elif player_mode:
		_show_launch()
	else:
		_show_garage()


## Dev view: every driver in every chassis, for checking seat placement.
func _seat_grid() -> void:
	var world := Node2D.new()
	add_child(world)
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.62, 0.7)
	bg.position = Vector2(-300, -300)
	bg.size = Vector2(2400, 1300)
	world.add_child(bg)
	var row := 0
	for chassis in Parts.CHASSIS:
		var col := 0
		for driver in Parts.DRIVERS:
			var car := Car.new()
			world.add_child(car)
			car.setup({"driver": driver, "chassis": chassis, "wheels": "grip", "front": "", "top": "", "gadget": ""},
					0, Vector2(col * 340, row * 250), Color.WHITE, null)
			car.freeze_all()
			col += 1
		row += 1
	var cam := Camera2D.new()
	cam.position = Vector2(850, 280)
	cam.zoom = Vector2(0.62, 0.62)
	world.add_child(cam)


# --- Garage -------------------------------------------------------------------------

func _show_launch() -> void:
	_launch = DatsLaunch.new()
	add_child(_launch)
	_launch.finished.connect(_resume_mobile_session)

func _resume_mobile_session() -> void:
	cloud.busy = true
	cloud.activity = "Welcome back…"
	var response: Dictionary = await cloud.restore_session()
	cloud.busy = false
	if response.ok:
		if is_instance_valid(_launch): _launch.queue_free(); _launch = null
		enter_cloud(response.data)
	else:
		_show_auth()
		if response.has("error"): _auth.set_status(response.error)

func _show_auth() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_lobby): _lobby.queue_free(); _lobby = null
	if is_instance_valid(_launch): _launch.queue_free(); _launch = null
	if is_instance_valid(_hub): _hub.queue_free(); _hub = null
	if is_instance_valid(_garage): _garage.queue_free(); _garage = null
	if is_instance_valid(_battle): _battle.queue_free(); _battle = null
	if is_instance_valid(_auth): _auth.queue_free()
	_auth = DatsAuthLanding.new()
	add_child(_auth)
	_auth.credentials_submitted.connect(_submit_landing_credentials)
	_auth.verification_submitted.connect(_verify_landing_email)
	_auth.confirmation_requested.connect(_resend_landing_email)
	_auth.google_requested.connect(_google_login)
	_auth.google_cancelled.connect(func(): cloud.cancel_google = true; _auth.set_status("Cancelling Google sign-in…"))
	_auth.offline_requested.connect(_show_hub)
	_auth.settings_requested.connect(show_settings)
	if not cloud.configured(): _auth.set_status("Cloud setup is unavailable. You can continue in practice mode.")

func _google_login() -> void:
	if cloud.busy or _auth.google_waiting: return
	_auth.set_waiting(true)
	_auth.google_waiting = true
	_auth.google.disabled = false
	_auth.google.text = "CANCEL GOOGLE SIGN-IN"
	var response: Dictionary = await cloud.google_signin(func(message):
		if is_instance_valid(_auth): _auth.set_status(message))
	if not is_instance_valid(_auth): return
	_auth.google_waiting = false
	_auth.google.text = "CONTINUE WITH GOOGLE"
	_auth.set_waiting(false)
	if response.ok: enter_cloud(response.data)
	else: _auth.set_status(response.error)

func _submit_landing_credentials(address: String, password: String, create: bool) -> void:
	if cloud.busy: return
	cloud.busy = true
	_auth.set_waiting(true)
	var response: Dictionary = await cloud.authenticate(address,password,create)
	cloud.busy = false
	if not is_instance_valid(_auth): return
	_auth.clear_password()
	_auth.set_waiting(false)
	if not response.ok:
		_auth.set_status(response.error)
		if response.get("confirmation_required",false): _auth.show_verification()
		return
	enter_cloud(response.data)

func _verify_landing_email(address: String, code: String) -> void:
	if cloud.busy: return
	cloud.busy = true
	_auth.set_waiting(true)
	var response: Dictionary = await cloud.verify_email(address,code)
	cloud.busy = false
	if not is_instance_valid(_auth): return
	_auth.set_waiting(false)
	_auth.code.text = ""
	if not response.ok:
		cloud.clear_session()
		_auth.set_status(response.error)
		return
	enter_cloud(response.data)

func _resend_landing_email(address: String) -> void:
	if cloud.busy: return
	cloud.busy = true
	_auth.set_waiting(true)
	var response: Dictionary = await cloud.resend_confirmation(address)
	cloud.busy = false
	if not is_instance_valid(_auth): return
	_auth.set_waiting(false)
	_auth.set_status("Check your email for a new code. Wait at least 60 seconds before requesting another." if response.ok else response.error)

func _show_hub() -> void:
	DatsAudio.instance().play_music()
	if is_instance_valid(_lobby) and _lobby.in_garage:
		_lobby.return_from_garage()
		return
	Engine.time_scale = 1.0
	if is_instance_valid(_lobby): _lobby.queue_free(); _lobby = null
	if is_instance_valid(_auth): _auth.queue_free(); _auth = null
	if is_instance_valid(_garage): _garage.queue_free(); _garage = null
	if is_instance_valid(_battle): _battle.queue_free(); _battle = null
	if is_instance_valid(_hub): _hub.queue_free()
	_hub = DatsHub.new()
	add_child(_hub)
	_hub.setup(cloud.email if cloud_mode else "PRACTICE DRIVER",inventory.player_level,cloud_mode,builds[0].get("driver","bolt"))
	_hub.friends_requested.connect(social.show_friends)
	_hub.driver_requested.connect(func(): _show_garage(); _garage.show_driver_picker())
	_hub.garage_requested.connect(_show_garage)
	_hub.practice_requested.connect(_start_battle)
	_hub.account_requested.connect(show_settings)
	_hub.private_requested.connect(_show_private_lobby)

func _show_private_lobby() -> void:
	if not cloud_mode or cloud.busy: return
	if is_instance_valid(_hub): _hub.queue_free(); _hub = null
	if is_instance_valid(_lobby):
		_lobby.show()
		return
	_lobby = PrivateLobby.new()
	add_child(_lobby)
	_lobby.closed.connect(_show_hub)
	_lobby.setup(self)

func _show_garage() -> void:
	DatsAudio.instance().play_music()
	Engine.time_scale = 1.0
	if is_instance_valid(_auth): _auth.queue_free(); _auth = null
	if is_instance_valid(_hub): _hub.queue_free(); _hub = null
	if _battle:
		_battle.queue_free()
		_battle=null
	if _garage: _garage.queue_free()
	var garage := GarageUI.new()
	_garage=garage
	add_child(garage)
	garage.setup(self)
	if player_mode:
		garage.message = cloud_status + " · " + ("Account / Save stores your fitted car." if cloud_mode else "Sign in for your cloud garage.")
		garage.rebuild()
	if reward_message != "":
		garage.message = reward_message
		garage.rebuild()


# Cloud account and garage -------------------------------------------------------------
func show_market() -> void:
	if cloud.busy: return
	if is_instance_valid(market_dialog): market_dialog.hide(); market_dialog.queue_free()
	market_dialog=DatsMarket.new()
	add_child(market_dialog)
	market_dialog.setup(self)

func show_settings() -> void:
	if cloud.busy: return
	if is_instance_valid(settings_dialog): settings_dialog.queue_free()
	settings_dialog = AcceptDialog.new()
	settings_dialog.theme = UI.game_theme()
	settings_dialog.title = "DATS SETTINGS"
	settings_dialog.get_ok_button().text = "DONE"
	settings_dialog.confirmed.connect(DatsAudio.instance().persist)
	settings_dialog.canceled.connect(DatsAudio.instance().persist)
	add_child(settings_dialog)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 550
	content.add_theme_constant_override("separation",12)
	settings_dialog.add_child(content)
	for option in [["music_enabled","Background music","music_volume"],["effects_enabled","Weapon & game effects","effects_volume"]]:
		var enabled := CheckButton.new()
		enabled.text = option[1]
		enabled.custom_minimum_size.y = 46
		enabled.button_pressed = DatsAudio.instance().get(option[0])
		enabled.toggled.connect(func(value): DatsAudio.instance().set(option[0],value); DatsAudio.instance().persist())
		content.add_child(enabled)
		var volume := HSlider.new()
		volume.custom_minimum_size = Vector2(500,40)
		volume.min_value = 0
		volume.max_value = 1
		volume.step = .01
		volume.value = DatsAudio.instance().get(option[2])
		volume.value_changed.connect(func(value): DatsAudio.instance().set(option[2],value); DatsAudio.instance().apply_levels())
		volume.drag_ended.connect(func(_changed): DatsAudio.instance().persist())
		content.add_child(volume)
	var shake := CheckButton.new()
	shake.text = "Screen shake during battles"
	shake.custom_minimum_size.y = 46
	shake.button_pressed = DatsAudio.instance().screen_shake
	shake.toggled.connect(func(enabled): DatsAudio.instance().screen_shake = enabled; DatsAudio.instance().persist())
	content.add_child(shake)
	if cloud_mode:
		var emails := CheckButton.new()
		emails.text = "Email me invitations when I am away"
		emails.button_pressed = social.email_enabled
		emails.custom_minimum_size.y = 46
		emails.toggled.connect(func(enabled):
			emails.disabled = true
			var response: Dictionary = await cloud.call_rpc("dats_email_preferences",{"p_enabled":enabled})
			if is_instance_valid(emails):
				emails.disabled = false
				if response.ok: social.email_enabled = enabled
				else: emails.set_pressed_no_signal(social.email_enabled))
		content.add_child(emails)
	var account := UI.button("ACCOUNT, CLOUD SAVE & SIGN OUT" if cloud_mode else "SIGN IN / CREATE ACCOUNT",Color("5478A0"),19,Vector2(500,60))
	account.disabled = is_instance_valid(_battle) or (is_instance_valid(_lobby) and is_instance_valid(_lobby.viewer))
	account.pressed.connect(func(): DatsAudio.instance().persist(); settings_dialog.hide(); show_account())
	content.add_child(account)
	settings_dialog.popup_centered(Vector2i(610,500))

func _process(_delta: float) -> void:
	if is_instance_valid(battle_settings): battle_settings.visible = is_instance_valid(_battle) or (is_instance_valid(_lobby) and is_instance_valid(_lobby.viewer))
	if is_instance_valid(busy_cover): busy_cover.visible = cloud.busy
	if cloud.busy and is_instance_valid(busy_label): busy_label.text = cloud.activity

func show_account() -> void:
	if cloud.busy: return
	if is_instance_valid(account_dialog): account_dialog.queue_free()
	account_dialog = ConfirmationDialog.new()
	account_dialog.theme = UI.game_theme()
	account_dialog.title = "DATS account" if not cloud_mode else "Cloud garage"
	account_dialog.dialog_hide_on_ok = false
	account_dialog.get_ok_button().hide()
	account_dialog.get_cancel_button().text = "Close"
	add_child(account_dialog)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(490, 280)
	panel.add_theme_constant_override("separation", 12)
	account_dialog.add_child(panel)
	var info := UI.label(cloud_status, 18)
	info.custom_minimum_size.x = 480
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info)
	if not cloud.configured():
		info.text = "Cloud accounts need a Supabase project. This build works in offline practice. Follow MOBILE-SETUP.md to connect your project."
	elif cloud_mode and cloud.connected():
		info.text = cloud.email + "\nGarage revision %d · local practice gives no cloud rewards." % cloud.revision
		var save := UI.button("Save my car to cloud", Color(.25,.5,.35), 18, Vector2(440,48))
		save.pressed.connect(func(): account_dialog.hide(); save_cloud())
		panel.add_child(save)
		var reload_button := UI.button("Reload saved garage (discard local edits)", Color(.4,.35,.2), 16, Vector2(440,48))
		reload_button.pressed.connect(func(): account_dialog.hide(); reload_cloud())
		panel.add_child(reload_button)
		var logout := UI.button("Sign out", Color(.5,.25,.2), 18, Vector2(440,48))
		logout.pressed.connect(func(): sign_out(); account_dialog.hide())
		panel.add_child(logout)
	else:
		var address := LineEdit.new()
		address.placeholder_text = "Email"
		address.custom_minimum_size.y = 48
		panel.add_child(address)
		var password := LineEdit.new()
		password.placeholder_text = "Password (at least 8 characters for a new account)"
		password.secret = true
		password.custom_minimum_size.y = 48
		panel.add_child(password)
		for signup in [false,true]:
			var button := UI.button("Create account" if signup else "Sign in", Color(.25,.45,.55), 18, Vector2(440,48))
			button.pressed.connect(func():
				if cloud.busy: return
				if address.text.strip_edges().is_empty() or password.text.is_empty():
					info.text = "Enter your email and password."
					return
				if signup and password.text.length() < 8:
					info.text = "Use at least 8 characters for your new password."
					return
				cloud.busy = true
				info.text = "Connecting…"
				var response: Dictionary = await cloud.authenticate(address.text.strip_edges(),password.text,signup)
				password.text = ""
				cloud.busy = false
				if not response.ok:
					cloud.clear_session()
					info.text = response.error
					if response.get("confirmation_required",false):
						var pending_address := address.text.strip_edges()
						account_dialog.hide()
						_show_auth()
						_auth.address.text = pending_address
						_auth.show_verification()
						_auth.set_status(response.error)
					return
				enter_cloud(response.data)
				account_dialog.hide())
			panel.add_child(button)
	account_dialog.popup_centered(Vector2i(540,410))
	account_dialog.reset_size()

func enter_cloud(snapshot: Dictionary) -> void:
	if not cloud_mode:
		offline_inventory = inventory
		offline_builds = builds.duplicate(true)
		inventory = Inventory.new()
		inventory.persistence_enabled = false
	cloud_mode = true
	player_mode = true
	apply_cloud_snapshot(snapshot,true)
	social.refresh(true)

func apply_cloud_snapshot(snapshot: Dictionary, open_hub := false) -> void:
	var profile: Dictionary = snapshot.profile
	inventory.items = snapshot.items
	inventory.gold = int(profile.gold)
	inventory.fusion_energy = int(profile.get("fusion_energy",10))
	inventory.player_level = int(profile.level)
	inventory.player_xp = int(profile.xp)
	inventory.wins = int(profile.wins)
	inventory.fights = int(profile.fights)
	inventory.supply_boxes = int(profile.supply_boxes)
	inventory.toolboxes = profile.toolboxes
	for kind in inventory.toolboxes: inventory.toolboxes[kind] = int(inventory.toolboxes[kind])
	cloud.revision = int(snapshot.revision)
	builds[0] = inventory.synchronize(snapshot.build)
	cloud_status = "Cloud revision %d · save after fitting" % cloud.revision
	reward_message = ""
	if open_hub: _show_hub()
	elif not is_instance_valid(_lobby): _show_garage()

func cloud_payload() -> Dictionary:
	return {"driver":builds[0].get("driver","bolt"),"equipped":builds[0].get("equipped",{}).duplicate(true)}

func save_cloud() -> bool:
	if cloud.busy or not cloud_mode: return false
	var return_to_hub := is_instance_valid(_hub)
	cloud.busy = true
	var response: Dictionary = await cloud.call_rpc("dats_save", {"p_build":cloud_payload(),"p_revision":cloud.revision})
	cloud.busy = false
	if response.ok:
		apply_cloud_snapshot(response.data,return_to_hub)
		cloud_status = "Saved to cloud · revision %d" % cloud.revision
	else:
		cloud_status = response.error
	if is_instance_valid(_garage): _garage.message = cloud_status; _garage.rebuild()
	return response.ok

func reload_cloud() -> void:
	if cloud.busy: return
	var return_to_hub := is_instance_valid(_hub)
	cloud.busy = true
	var response: Dictionary = await cloud.call_rpc("dats_garage", {})
	cloud.busy = false
	if response.ok: apply_cloud_snapshot(response.data,return_to_hub)
	else:
		cloud_status = response.error
		if is_instance_valid(_garage): _garage.message = cloud_status; _garage.rebuild()

func sign_out() -> void:
	if is_instance_valid(social.dialog): social.dialog.queue_free()
	social.username = ""
	social.inbox.clear()
	social.noticed = ""
	social.announced = ""
	social.toast_time = 0
	# Revoke remotely when possible; always remove local tokens and restore offline sandbox.
	if cloud.connected(): cloud.request("/auth/v1/logout",{},true)
	cloud.clear_session()
	if cloud_mode:
		inventory = offline_inventory
		builds = offline_builds.duplicate(true)
	cloud_mode = false
	cloud_status = "Offline practice"
	reward_message = ""
	if player_mode: _show_auth()
	else: _show_garage()

func economy(operation: String, args: Dictionary = {}) -> void:
	if cloud.busy: return
	if cloud_mode:
		# Purchases work even while wheels or weapons are temporarily removed.
		var keep_draft: bool=operation in ["buy","box","energy_box"]
		var draft: Dictionary=builds[0].duplicate(true)
		# Fusion saves first so the server protects all fitted spare parts.
		if not keep_draft and not await save_cloud(): return
		cloud.busy = true
		var response: Dictionary = await cloud.call_rpc("dats_economy", {"p_operation":operation,"p_args":args,"p_revision":cloud.revision})
		cloud.busy = false
		if response.ok:
			apply_cloud_snapshot(response.data)
			if keep_draft: builds[0]=inventory.synchronize(draft)
			cloud_status = "Cloud purchase / upgrade saved."
		else: cloud_status = response.error
		if is_instance_valid(_garage): _garage.message = cloud_status; _garage.rebuild()
		return
	var message := ""
	match operation:
		"buy": message = inventory.buy_part(args.id,int(args.tier))
		"box": message = inventory.open_box()
		"energy_box": message = inventory.energy_box()
		"fuse": message = inventory.fuse(args.uid,args.spare,_garage.protected_ids())
		"toolbox": message = inventory.toolbox(args.uid,args.kind)
	if is_instance_valid(_garage): _garage.message = message; _garage.refresh_stats()

# --- Battle -------------------------------------------------------------------------

func _start_battle() -> void:
	if cloud.busy: return
	for i in (1 if player_mode else 2):
		if not inventory.build_valid(builds[i]): return
	inventory.save(builds)
	Engine.time_scale = 1.0
	if _garage:
		_garage.queue_free()
		_garage = null
	if is_instance_valid(_hub): _hub.queue_free(); _hub = null
	if _battle:
		_battle.queue_free()
	_battle = Battle.new()
	if cloud_mode and not social.username.is_empty(): _battle.player_names = ["@"+social.username, ""]
	add_child(_battle)
	_battle.rematch_requested.connect(_start_battle)
	_battle.garage_requested.connect(_show_garage)
	_battle.finished.connect(func(result):
		DatsAudio.instance().effect("victory" if int(result.winner)==0 else "defeat")
		if player_mode:
			reward_message = "Practice finished. Gold, XP and fusion energy come from hosted Friend Fights. Practice does not award cloud currency."
			return
		reward_message = inventory.award_battle(result.winner == 0)
		for i in builds.size(): builds[i] = inventory.synchronize(builds[i])
		inventory.save(builds))
	_battle.start(builds.duplicate(true))


# --- Automated balance runs ---------------------------------------------------------

func _run_autotest() -> void:
	seed(42)
	var b := func(c, w, f, t, g): return {"chassis": c, "wheels": w, "front": f, "top": t, "gadget": g}
	_tests = [
		[b.call("wedge", "grip", "lance", "", "booster"), b.call("bruiser", "grip", "saw", "hammer", "")],
		[b.call("wedge", "sprint", "lance", "", ""), b.call("wedge", "sprint", "lance", "", "")],
		[b.call("scrapper", "grip", "saw", "", "booster"), b.call("bruiser", "grip", "lance", "", "")],
		[b.call("ram", "grip", "lance", "saw", ""), b.call("wedge", "grip", "", "hammer", "booster")],
		[b.call("bruiser", "grip", "", "hammer", ""), b.call("ram", "sprint", "hammer", "", "")],
		[b.call("scrapper", "sprint", "lance", "hammer", ""), b.call("ram", "grip", "saw", "lance", "booster")],
		[b.call("wedge", "rubber_medium", "cannon", "short_sword", ""), b.call("bruiser", "metal_medium", "blaster", "long_sword", "")],
		[b.call("bruiser", "wood_large", "hook", "long_sword", ""), b.call("scrapper", "rubber_small", "short_sword", "", "booster")],
		[b.call("wedge", "rubber_medium", "", "short_sword", ""), b.call("wedge", "rubber_medium", "", "long_sword", "")],
		[{"chassis": "wedge", "wheels": "grip", "front": "short_sword", "top": "", "defence": "armour_plate", "gadget": "booster"}, {"chassis": "bruiser", "wheels": "grip", "front": "cannon", "top": "hammer", "defence": "shield", "gadget": ""}],
		[{"chassis": "ram", "wheels": "rubber_medium", "front": "long_sword", "top": "", "defence": "shield", "gadget": ""}, {"chassis": "scrapper", "wheels": "metal_small", "front": "cannon", "top": "", "defence": "armour_plate", "gadget": ""}],
		[{"chassis": "bruiser", "wheels": "metal_large", "front": "", "top": "long_sword", "defence": "armour_plate", "gadget": ""}, {"chassis": "scrapper", "wheels": "rubber_small", "front": "short_sword", "top": "", "defence": "shield", "gadget": ""}],
	]
	_next_test()


func _next_test() -> void:
	if _test_index >= _tests.size():
		var report := FileAccess.open("res://../screenshots/balance_results.json", FileAccess.WRITE)
		report.store_string(JSON.stringify(_test_results, "\t"))
		print("AUTOTEST DONE")
		get_tree().quit()
		return
	builds = _tests[_test_index].map(func(bd): return Parts.normalize_build(bd))
	if _battle:
		_battle.queue_free()
	_battle = Battle.new()
	_battle.show_end_panel = false
	_battle.trace = "--trace" in OS.get_cmdline_user_args()
	add_child(_battle)
	_battle.finished.connect(_on_test_finished)
	_battle.start(builds.duplicate(true))


func _on_test_finished(result: Dictionary) -> void:
	_test_results.append(result)
	var fmt := func(bd): return "%s/%s/F:%s/T:%s/G:%s" % [bd.chassis, bd.wheels, bd.front, bd.top, bd.gadget]
	print("MATCH %d  Blue[%s] vs Red[%s]" % [_test_index, fmt.call(builds[0]), fmt.call(builds[1])])
	var who: String = "Nobody (draw)" if result.winner < 0 else Battle.SIDE_NAMES[result.winner]
	print("  -> %s wins by %s at %.1fs" % [who, result.reason, result.time])
	for i in 2:
		var c: Dictionary = result.cars[i]
		print("  %s hp %d/%d dealt %d flipped %.1fs weapons %s lost %s" % [Battle.SIDE_NAMES[i], c.hp, c.max_hp,
				c.dealt, c.flipped, c.weapons, c.lost])
	for w in result.why:
		print("  why: " + w)
	_test_index += 1
	_next_test.call_deferred()


func _capture_qa() -> void:
	builds[0] = {"driver": "nova", "chassis": "wedge", "wheels": "grip", "rear_wheel": "rubber_large", "front_wheel": "wood_small", "front": "long_sword", "top": "cannon", "defence": "armour_plate", "gadget": "booster"}
	builds[1] = {"driver": "spark", "chassis": "ram", "wheels": "grip", "rear_wheel": "metal_medium", "front_wheel": "rubber_small", "front": "short_sword", "top": "", "defence": "shield", "gadget": ""}
	_show_garage()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../screenshots/garage_ratings.png")
	_start_battle()
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../screenshots/battle_ratings.png")
	print("RENDER QA fps=%.0f physics_hz=%d time_scale=%.1f" % [Performance.get_monitor(Performance.TIME_FPS), Engine.physics_ticks_per_second, Engine.time_scale])
	get_tree().quit()
