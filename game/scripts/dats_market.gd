class_name DatsMarket
extends AcceptDialog
var main: Node
var tier := 1
var category := "weapons"
var note := ""
var working := false
func setup(owner: Node) -> void:
	main = owner
	theme = UI.game_theme()
	title = "MARKETPLACE • BUILD YOUR COLLECTION"
	get_ok_button().text = "BACK TO GARAGE"
	refresh()
	popup_centered(Vector2i(1060,620))
func refresh() -> void:
	for child in get_children():
		if child is VBoxContainer: child.hide(); child.queue_free()
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(1010,540)
	content.add_theme_constant_override("separation",10)
	add_child(content)
	content.add_child(UI.label("GOLD %d   •   FUSION ENERGY %d   •   PLAYER LEVEL %d" % [main.inventory.gold,main.inventory.fusion_energy,main.inventory.player_level],22,Color("FFCE59")))
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	for group in ["bodies","weapons","gadgets","wheels"]:
		var button := UI.button(group.capitalize(),UI.ORANGE if category==group else UI.SKY,18,Vector2(150,52))
		button.pressed.connect(func(): category=group; refresh())
		tabs.add_child(button)
	var tiers := OptionButton.new()
	tiers.custom_minimum_size = Vector2(300,52)
	for value in range(1,6): tiers.add_item("TIER %d%s" % [value," • unlock at Lv %d" % ((value-1)*10+1) if value>main.inventory.unlocked_tier() else ""])
	tiers.select(tier-1)
	tiers.item_selected.connect(func(index): tier=index+1; refresh())
	tabs.add_child(tiers)
	var energy := UI.button("ENERGY BOX\n+10 • 300 GOLD",UI.PURPLE,17,Vector2(220,60))
	energy.disabled = working or main.inventory.gold<300
	energy.pressed.connect(purchase.bind("energy_box",{}))
	content.add_child(energy)
	var info := UI.label(note if note!="" else "Buy a distinct copy. Fusion consumes a matching spare and energy, keeping its tier. New materials unlock: rubber Tier 2, metal Tier 3.",16,Color.WHITE)
	info.custom_minimum_size.x = 980
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000,340)
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var table: Dictionary = {"bodies":Parts.CHASSIS,"weapons":Parts.WEAPONS,"gadgets":Parts.GADGETS,"wheels":Parts.WHEELS}[category]
	for id in table:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",UI.box(Color("27425F"),Progression.tier_color(tier),16,2,12))
		grid.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var icon := PartIcon.new()
		icon.item={"id":id,"level":tier}
		icon.modulate=Progression.tier_color(tier)
		icon.custom_minimum_size=Vector2(100,90)
		row.add_child(icon)
		var column := VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var base: Dictionary=table[id]
		column.add_child(UI.label(base.name,18,Progression.tier_color(tier)))
		var label := "ATK" if Parts.WEAPONS.has(id) and base.get("attack",0)>0 else "HP"
		column.add_child(UI.label("TIER %d • %s %d" % [tier,label,Progression.base_rating(id,tier)],16,Color.WHITE))
		if Parts.WEAPONS.has(id) and base.get("attack",0)==0:
			var rated := Parts.rated_data(base,{"component_stats":{"card":{"id":id,"level":tier}}},"card")
			column.get_child(1).text="TIER %d • CONTROL • %.1fs RELOAD" % [tier,rated.cooldown]
		var cost := Progression.market_price(id,tier)
		var locked: bool = tier>main.inventory.unlocked_tier() or tier<Progression.minimum_tier(id)
		var buy := UI.button(("TIER %d+ REQUIRED" % Progression.minimum_tier(id) if tier<Progression.minimum_tier(id) else "LV %d • %d GOLD" % [(tier-1)*10+1,cost]) if locked else "BUY • %d GOLD" % cost,UI.ORANGE,17,Vector2(210,48))
		buy.disabled=working or locked or main.inventory.gold<cost
		buy.tooltip_text=base.desc+"\nPrice: %d gold" % cost
		buy.pressed.connect(purchase.bind("buy",{"id":id,"tier":tier}))
		column.add_child(buy)
func purchase(operation: String,args: Dictionary) -> void:
	if working or main.cloud.busy: return
	working=true
	note="Saving purchase…"
	refresh()
	await main.economy(operation,args)
	if not is_instance_valid(self): return
	working=false
	note=main.cloud_status if main.cloud_mode else (main._garage.message if is_instance_valid(main._garage) else "Purchase complete.")
	refresh()
