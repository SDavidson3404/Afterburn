## Singleton database manager handling real-time run telemetry, score calculations, SQLite data persistence, store unlocks, and aggregate lifetime analytics.
extends Node

## SQLite database instance reference.
var db: SQLite

# Distance scoring constants and runtime trackers
const POINTS_PER_METER: float = 1.0
var total_distance_meters: int = 0
var meters_traveled: float = 0.0
var travel_score: int = 0

# Dodge scoring constants and runtime trackers
const BASE_DODGE_POINTS: int = 100
var dodge_score: int = 0

# Crystal scoring constants and runtime trackers
const CRYSTAL_POINTS: int = 500
var crystal_score: int = 0

# Gadget scoring constants and runtime trackers
const GADGET_POINTS: int = 1000
var gadget_score: int = 0

# Store & Coin Economy constants
const POINTS_PER_COIN: int = 100
const GADGET_COST: int = 1000
const GADGET_UNLOCK_ORDER: Array[String] = [
	"pulse_wave",
	"magnet",
	"power_armor",
	"hoverboard",
	"overdriven_rocket"
]

# Stat tracking counters logged during each run
var power_crystals: int = 0
var gadgets: int = 0
var jump_obstacle: int = 0
var slide_obstacle: int = 0
var robot_crash: int = 0
var scaffolding_crash: int = 0
var drone_crash: int = 0

# Shop Related Things (persisted in SQLite)
var coins: int = 100
var last_run_coins_earned: int = 0
var unlocked_gadgets: Array[String] = []

# Starting Gadget
var chosen_starting_gadget: String = "None"

## Maps gadget IDs to their signature hex colors.
const GADGET_COLOR_HEX: Dictionary = {
	"pulse_wave": "#f233d9",
	"magnet": "#f24040",
	"power_armor": "#33f259",
	"hoverboard": "#ffffff",
	"overdriven_rocket": "#ff8c00"
}

## Initializes SQLite database connection, creates required tables, and loads saved store state.
func _ready() -> void:
	db = SQLite.new()
	db.path = "user://game_data.db"
	db.open_db()
	
	create_stats_table()
	create_leaderboard_table()
	create_store_tables()
	load_store_data()


## Executes SQL DDL query to establish the stats table schema if missing.
func create_stats_table() -> void:
	var stats_query := """
	CREATE TABLE IF NOT EXISTS stats (
		stats_id INTEGER PRIMARY KEY,
		total_distance INTEGER,
		travel_score INTEGER,
		dodge_score INTEGER,
		crystal_score INTEGER,
		gadget_score INTEGER,
		total_score INTEGER,
		power_crystals INTEGER,
		gadgets INTEGER,
		jump_obstacle INTEGER,
		slide_obstacle INTEGER,
		robot_crash INTEGER,
		scaffolding_crash INTEGER,
		drone_crash INTEGER
	);
	"""
	db.query(stats_query)

## Executes SQL DDL query to establish the top 10 leaderboard table schema if missing.
func create_leaderboard_table() -> void:
	var leaderboard_query := """
	CREATE TABLE IF NOT EXISTS leaderboard (
		entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
		player_name TEXT NOT NULL,
		score INTEGER NOT NULL,
		starting_gadget TEXT NOT NULL DEFAULT 'None'
	);
	"""
	db.query(leaderboard_query)


## Executes SQL DDL queries to establish persistent wallet and unlocked gadget tables.
func create_store_tables() -> void:
	var wallet_query := """
	CREATE TABLE IF NOT EXISTS player_wallet (
		wallet_id INTEGER PRIMARY KEY CHECK (wallet_id = 1),
		coins INTEGER NOT NULL DEFAULT 0,
		chosen_starting_gadget TEXT NOT NULL DEFAULT 'None'
	);
	"""
	db.query(wallet_query)
	db.query("INSERT OR IGNORE INTO player_wallet (wallet_id, coins, chosen_starting_gadget) VALUES (1, 0, 'None');")

	var unlocks_query := """
	CREATE TABLE IF NOT EXISTS unlocked_gadgets (
		gadget_id TEXT PRIMARY KEY
	);
	"""
	db.query(unlocks_query)


## Loads persisted coin balance, chosen starting gadget, and permanently unlocked gadgets from SQLite.
func load_store_data() -> void:
	db.query("SELECT coins, chosen_starting_gadget FROM player_wallet WHERE wallet_id = 1;")
	if db.query_result and db.query_result.size() > 0:
		coins = int(db.query_result[0].get("coins", 0))
		chosen_starting_gadget = str(db.query_result[0].get("chosen_starting_gadget", "None"))

	unlocked_gadgets.clear()
	db.query("SELECT gadget_id FROM unlocked_gadgets;")
	if db.query_result:
		for row in db.query_result:
			var gid: String = str(row.get("gadget_id", ""))
			if not gid.is_empty() and not unlocked_gadgets.has(gid):
				unlocked_gadgets.append(gid)

	# Ensure the saved starting gadget is actually unlocked
	if chosen_starting_gadget != "None" and not unlocked_gadgets.has(chosen_starting_gadget):
		chosen_starting_gadget = "None"
		save_wallet()


## Saves current coin balance and chosen starting gadget to SQLite.
func save_wallet() -> void:
	var safe_gadget: String = chosen_starting_gadget.replace("'", "''")
	db.query("UPDATE player_wallet SET coins = %d, chosen_starting_gadget = '%s' WHERE wallet_id = 1;" % [coins, safe_gadget])


## Returns true if the given gadget ID has been permanently unlocked.
func is_gadget_unlocked(gadget_id: String) -> bool:
	return unlocked_gadgets.has(gadget_id)


## Returns the next gadget ID in the sequential unlock order, or "" if all are unlocked.
func get_next_purchasable_gadget() -> String:
	for gid in GADGET_UNLOCK_ORDER:
		if not unlocked_gadgets.has(gid):
			return gid
	return ""


## Attempts to purchase and permanently unlock a gadget in sequential order.
## Returns one of: "UNLOCKED", "NOT_ENOUGH", "LOCKED", or "ALREADY_UNLOCKED".
func purchase_gadget(gadget_id: String) -> String:
	if is_gadget_unlocked(gadget_id):
		return "ALREADY_UNLOCKED"

	if gadget_id != get_next_purchasable_gadget():
		return "LOCKED"

	if coins < GADGET_COST:
		return "NOT_ENOUGH"

	coins -= GADGET_COST
	unlocked_gadgets.append(gadget_id)
	var safe_id: String = gadget_id.replace("'", "''")
	db.query("INSERT OR IGNORE INTO unlocked_gadgets (gadget_id) VALUES ('%s');" % safe_id)
	save_wallet()
	return "UNLOCKED"


## Returns true if the given score qualifies for the Top 10 leaderboard.
func is_top_10_score(score: int) -> bool:
	if score <= 0:
		return false
	var current_top: Array = get_top_leaderboard(10)
	if current_top.size() < 10:
		return true
	var lowest_top_score: int = int(current_top.back().get("score", 0))
	return score > lowest_top_score


## Inserts a new high score entry and trims the leaderboard table to the Top 10 scores.
func add_leaderboard_entry(player_name: String, score: int, gadget_used: String = chosen_starting_gadget) -> void:
	var clean_name: String = player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "PLAYER"

	var clean_gadget: String = gadget_used.strip_edges()
	if clean_gadget.is_empty():
		clean_gadget = "None"

	db.insert_row("leaderboard", {
		"player_name": clean_name,
		"score": score,
		"starting_gadget": clean_gadget
	})

	# Keep only the top 10 rows ordered by highest score, breaking ties by earliest entry
	var prune_query := """
	DELETE FROM leaderboard
	WHERE entry_id NOT IN (
		SELECT entry_id FROM leaderboard
		ORDER BY score DESC, entry_id ASC
		LIMIT 10
	);
	"""
	db.query(prune_query)


## Queries and returns the top leaderboard entries sorted from highest to lowest score.
func get_top_leaderboard(limit: int = 10) -> Array:
	var query := """
	SELECT entry_id, player_name, score, starting_gadget
	FROM leaderboard
	ORDER BY score DESC, entry_id ASC
	LIMIT %d;
	""" % limit
	db.query(query)
	return db.query_result.duplicate() if db.query_result else []


## Returns a BBCode colored dash prefix for the given gadget, or an empty string if no gadget was used.
func get_gadget_dash_bbcode(gadget_key: String) -> String:
	if gadget_key.is_empty() or gadget_key == "None" or gadget_key == "None (Standard Run)":
		return ""
	var hex_color: String = GADGET_COLOR_HEX.get(gadget_key, "")
	if hex_color.is_empty():
		return ""
	return "[b][color=%s]-[/color][/b] " % hex_color


## Tracks distance moved during an active run and calculates corresponding travel score points.
func add_distance(meters_moved: float) -> void:
	meters_traveled += meters_moved
	total_distance_meters = int(meters_traveled)
	travel_score = int(total_distance_meters * POINTS_PER_METER)


## Logs successful obstacle dodges by maneuver type and increments dodge score by awarded points.
func add_dodge(dodge_type: String = "", points: int = 100) -> void:
	dodge_score += points
	if dodge_type == "jump":
		jump_obstacle += 1
	elif dodge_type == "slide":
		slide_obstacle += 1


## Logs collected power crystals and updates crystal score total.
func add_crystal() -> void:
	crystal_score += CRYSTAL_POINTS
	power_crystals += 1


## Increments total gadget pickup count and updates gadget score total.
func add_gadget() -> void:
	gadget_score += GADGET_POINTS
	gadgets += 1


## Returns total combined score across movement distance, dodges, crystals, and gadgets.
func display_score() -> int:
	return (travel_score + dodge_score + crystal_score + gadget_score)


## Logs obstacle collisions categorized by obstacle type.
func player_crash(crash_type: String = "") -> void:
	if crash_type == "robot":
		robot_crash += 1
	elif crash_type == "scaffolding":
		scaffolding_crash += 1
	elif crash_type == "drone":
		drone_crash += 1


## Inserts current run statistics into SQLite database and returns summary dictionary.
func save_run() -> Dictionary:
	var run_data: Dictionary = {
		"total_distance": total_distance_meters,
		"travel_score": travel_score,
		"dodge_score": dodge_score,
		"crystal_score": crystal_score,
		"gadget_score": gadget_score,
		"total_score": display_score(),
		"power_crystals": power_crystals,
		"gadgets": gadgets,
		"jump_obstacle": jump_obstacle,
		"slide_obstacle": slide_obstacle,
		"robot_crash": robot_crash,
		"scaffolding_crash": scaffolding_crash,
		"drone_crash": drone_crash
	}
	db.insert_row("stats", run_data)
	return run_data


## Formats an integer value with commas as thousand separators.
func format_number(value: int) -> String:
	var s: String = str(value)
	var negative: bool = s.begins_with("-")
	if negative:
		s = s.substr(1)
	var result: String = ""
	var digit_count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if digit_count > 0 and digit_count % 3 == 0:
			result = "," + result
		result = s[i] + result
		digit_count += 1
	return ("-" if negative else "") + result


## Zeroes active run statistics counters in preparation for a new run.
func reset_run_stats() -> void:
	total_distance_meters = 0
	meters_traveled = 0.0
	travel_score = 0
	dodge_score = 0
	crystal_score = 0
	gadget_score = 0
	power_crystals = 0
	gadgets = 0
	jump_obstacle = 0
	slide_obstacle = 0
	robot_crash = 0
	scaffolding_crash = 0
	drone_crash = 0
	last_run_coins_earned = 0


## Queries database for high scores and aggregated lifetime player analytics.
func lifetime_stats() -> Dictionary:
	var lifetime_query: String = """
	SELECT
		COUNT(*) AS total_runs,
		COALESCE(MAX(total_score), 0) AS high_score,
		COALESCE(SUM(total_score), 0) AS total_lifetime_score,
		COALESCE(MAX(total_distance), 0) AS max_distance,
		COALESCE(MAX(power_crystals), 0) AS max_crystals,
		COALESCE(MAX(jump_obstacle + slide_obstacle), 0) AS max_dodges,
		COALESCE(SUM(total_distance), 0) AS total_distance,
		COALESCE(SUM(power_crystals), 0) AS total_crystals,
		COALESCE(SUM(gadgets), 0) AS total_gadgets,
		COALESCE(SUM(jump_obstacle + slide_obstacle), 0) AS total_dodges,
		COALESCE(SUM(robot_crash), 0) AS robot_crashes,
		COALESCE(SUM(scaffolding_crash), 0) AS scaffolding_crashes,
		COALESCE(SUM(drone_crash), 0) AS drone_crashes
	FROM stats;
	"""
	# COALESCE(..., 0) prevents NULL returns when database table contains no records yet
	db.query(lifetime_query)
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

## Awards 1 coin per 100 points scored in the completed run and persists the new balance.
func add_coins() -> int:
	@warning_ignore("integer_division")
	var earned: int = display_score() / POINTS_PER_COIN
	last_run_coins_earned = earned
	if earned > 0:
		coins += earned
		save_wallet()
	return earned
	
