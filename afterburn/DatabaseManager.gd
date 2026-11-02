## Singleton database manager handling real-time run telemetry, score calculations, SQLite data persistence, and aggregate lifetime analytics.
extends Node

## SQLite database instance reference.
var db: SQLite

# Distance scoring constants and runtime trackers
const POINTS_PER_METER: float = 1.0
var total_distance_meters: int = 0
var meters_traveled: float = 0.0
var travel_score: int = 0

# Dodge scoring constants and runtime trackers
const POINTS_PER_DODGE: int = 10
var dodge_score: int = 0

# Crystal scoring constants and runtime trackers
const CRYSTAL_POINTS: int = 100
var crystal_score: int = 0

# Stat tracking counters logged during each run
var power_crystals: int = 0
var gadgets: int = 0
var jump_obstacle: int = 0
var slide_obstacle: int = 0
var dash_obstacle: int = 0
var robot_crash: int = 0
var scaffolding_crash: int = 0
var drone_crash: int = 0


## Initializes SQLite database connection and creates required tables upon engine launch.
func _ready() -> void:
	db = SQLite.new()
	db.path = "user://game_data.db"
	db.open_db()
	
	create_stats_table()


## Executes SQL DDL query to establish the stats table schema if missing.
func create_stats_table() -> void:
	var stats_query := """
	CREATE TABLE IF NOT EXISTS stats (
		stats_id INTEGER PRIMARY KEY,
		total_distance INTEGER,
		travel_score INTEGER,
		dodge_score INTEGER,
		crystal_score INTEGER,
		total_score INTEGER,
		power_crystals INTEGER,
		gadgets INTEGER,
		jump_obstacle INTEGER,
		slide_obstacle INTEGER,
		dash_obstacle INTEGER,
		robot_crash INTEGER,
		scaffolding_crash INTEGER,
		drone_crash INTEGER
	);
	"""
	db.query(stats_query)


## Tracks distance moved during an active run and calculates corresponding travel score points.
func add_distance(meters_moved: float) -> void:
	meters_traveled += meters_moved
	total_distance_meters = int(meters_traveled)
	travel_score = int(total_distance_meters * POINTS_PER_METER)


## Logs successful obstacle dodges by maneuver type and increments dodge score.
func add_dodge(dodge_type: String = "") -> void:
	dodge_score += POINTS_PER_DODGE
	if dodge_type == "jump":
		jump_obstacle += 1
	elif dodge_type == "slide":
		slide_obstacle += 1
	elif dodge_type == "dash":
		dash_obstacle += 1


## Logs collected power crystals and updates crystal score total.
func add_crystal() -> void:
	crystal_score += CRYSTAL_POINTS
	power_crystals += 1


## Increments total gadget pickup count.
func add_gadget() -> void:
	gadgets += 1


## Returns total combined score across movement distance, dodges, and crystals.
func display_score() -> int:
	return (travel_score + dodge_score + crystal_score)


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
		"total_score": display_score(),
		"power_crystals": power_crystals,
		"gadgets": gadgets,
		"jump_obstacle": jump_obstacle,
		"slide_obstacle": slide_obstacle,
		"dash_obstacle": dash_obstacle,
		"robot_crash": robot_crash,
		"scaffolding_crash": scaffolding_crash,
		"drone_crash": drone_crash
	}
	db.insert_row("stats", run_data)
	return run_data


## Zeroes active run statistics counters in preparation for a new run.
func reset_run_stats() -> void:
	total_distance_meters = 0
	meters_traveled = 0.0
	travel_score = 0
	dodge_score = 0
	crystal_score = 0
	power_crystals = 0
	gadgets = 0
	jump_obstacle = 0
	slide_obstacle = 0
	dash_obstacle = 0
	robot_crash = 0
	scaffolding_crash = 0
	drone_crash = 0


## Queries database for high scores and aggregated lifetime player analytics.
func lifetime_stats() -> Dictionary:
	var lifetime_query: String = """
	SELECT
		COUNT(*) AS total_runs,
		COALESCE(MAX(total_score), 0) AS high_score,
		COALESCE(MAX(total_distance), 0) AS max_distance,
		COALESCE(MAX(power_crystals), 0) AS max_crystals,
		COALESCE(MAX(jump_obstacle + slide_obstacle + dash_obstacle), 0) AS max_dodges,
		COALESCE(SUM(total_distance), 0) AS total_distance,
		COALESCE(SUM(power_crystals), 0) AS total_crystals,
		COALESCE(SUM(gadgets), 0) AS total_gadgets,
		COALESCE(SUM(jump_obstacle + slide_obstacle + dash_obstacle), 0) AS total_dodges,
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
