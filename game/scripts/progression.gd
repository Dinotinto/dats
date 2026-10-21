class_name Progression
extends RefCounted
## Local progression policy. Reward amounts can change independently of combat.
const MAX_PLAYER_LEVEL := 100
const MAX_PART_LEVEL := 10
const WIN_XP := 40
const LOSS_XP := 20
const WIN_GOLD := 60
const LOSS_GOLD := 30

static func unlocked_tier(player_level: int) -> int:
	return clampi(1 + int((clampi(player_level, 1, 100) - 1) / 10.0), 1, MAX_PART_LEVEL)

static func xp_required(player_level: int) -> int:
	return 300 + (player_level - 1) * 60

static func slot_limits(tier: int) -> Vector2i:
	return Vector2i(mini(4,2+int(tier/2.0)),mini(4,2+int((tier-1)/2.0)))

static func attack_band(tier: int) -> Vector2:
	if tier <= 1: return Vector2(40, 100)
	return Vector2(150, 250) * pow(2.0, clampi(tier, 2, MAX_PART_LEVEL) - 2)

static func attack(base: float, tier: int) -> float:
	if base <= 0: return 0.0 # Grapples provide utility, never attack damage.
	var band := attack_band(tier)
	return roundf(lerpf(band.x, band.y, clampf((base - 40.0) / 60.0, 0.0, 1.0)))

static func energy(base: int, tier: int, body: bool, wheel: bool) -> int:
	if wheel: return 0
	return base + (4 if body else 1) * (clampi(tier, 1, MAX_PART_LEVEL) - 1)

const MARKET_TIERS := 5
const STARTER_IDS := ["classic","wood_small","wood_medium","short_sword","rocket","booster","armour_plate"]
static func tier_color(tier: int) -> Color:
	return [Color.WHITE,Color("A8EACA"),Color("ADD7FF"),Color("D7AEFF"),Color("FFD080")][clampi(tier,1,5)-1]
static func minimum_tier(id: String) -> int:
	if id.begins_with("rubber_"): return 2
	if id.begins_with("metal_"): return 3
	return 1
static func base_rating(id: String,tier: int) -> float:
	var data := Parts.base_for(id)
	return attack(data.get("attack",0),tier) if Parts.WEAPONS.has(id) and data.get("attack",0)>0 else float(data.get("durability",0))*pow(2,tier-1)
static func market_price(id: String,tier: int) -> int:
	var data := Parts.base_for(id)
	var value := base_rating(id,tier)*(8 if Parts.WEAPONS.has(id) else 3)
	if Parts.WEAPONS.has(id) and data.get("attack",0)==0: value=600*tier*tier
	return maxi(100,ceili(value/10)*10)
static func fusion_cost(item: Dictionary) -> int:
	return 5*int(item.level)+2*int(item.get("fusion_count",0))
static func fusion_value(target: Dictionary,spare: Dictionary) -> float:
	var key := "attack_bonus" if Parts.WEAPONS.has(target.id) and Parts.WEAPONS[target.id].attack>0 else "durability_bonus"
	var base := base_rating(target.id,int(target.level))
	return minf(base*2,float(target.get(key,0))+roundf((base+float(spare.get(key,0)))*.6))
