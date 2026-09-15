extends Node

var db: SQLite # The database variable

# Conversion variables
const PIXELS_PER_POINT: float = 32.0 # 32 pixels = 1 point. Low pixel count keeps the score ticking up as the player moves
const PIXELS_PER_METER: float = 100.0 # 100 pixels = 1 meter

# Distance and distance scoring variables
var total_distance_meters: int = 0 # Tracks the total distance in meters the player has moved
var pixels_traveled: float = 0.0 # Tracks the total distance in pixels the player has moved
var travel_score: int = 0 # The points the player gets from moving

# Dodge scoring variables
const POINTS_PER_DODGE: int = 10 # Jumping over, sliding under, or dashing through obstacles is worth 10 points
var dodge_score: int = 0 # The points the player gets from dodging

# Crystal scoring variables
const CRYSTAL_POINTS: int = 100 # Collecting a power crystal is worth 100 points
var crystal_score: int = 0 # The points the player gets from collecting power crystals

# Other variables to log stats
var power_crystals: int = 0 # The number of crystals collected
var gadgets: int = 0 # The number of gadgets collected
var jump_obstacle: int = 0 # The number of obstacles jumped over
var slide_obstacle: int = 0 # The number of obstacles slid under
var dash_obstacle: int = 0 # The number of obstacles dashed through
var robot_crash: int = 0 # The number of times crashed into robots
var scaffolding_crash: int = 0 # The number of times crashed into scaffolding
var drone_crash: int = 0 # The number of times crashed into drones

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	db = SQLite.new() # Initialize database
	db.path = "user://game_data.db" # The file address used
	db.open_db() # Creates the file, or opens if it exists
	
	# Removes unused tables. Will delete later, after each teammate executes this
	db.query("DROP TABLE IF EXISTS scores;")
	db.query("DROP TABLE IF EXISTS Scores;")
	
	# Execute table creation on startup
	create_stats_table()

# Create stats table
func create_stats_table() -> void:
	var stats_query:="""
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

# Distance traveling tracker
func add_distance(pixels_moved: float) -> void: # Tracks the distance traveled per frame. Called by player.gd every frame during active gameplay
	pixels_traveled += pixels_moved # Adds the distance from each frame to the total
	total_distance_meters = int(pixels_traveled / PIXELS_PER_METER) # Total distance divided by 100 equals 1 meter added to stats
	travel_score = int(pixels_traveled / PIXELS_PER_POINT) # Total distance divided by 32 equals 1 point added to score

# Obstacle dodging tracker
func add_dodge(dodge_type: String = "") -> void: # Called by obstacle collision/detection whenever the player dodges an obstacle
	dodge_score += POINTS_PER_DODGE # Adds 10 points to score
	# Depending on the dodge, adds 1 of that type to current run data
	if dodge_type == "jump":
		jump_obstacle += 1
	elif dodge_type == "slide":
		slide_obstacle += 1
	elif dodge_type == "dash":
		dash_obstacle += 1

# Crystal collecting tracker
func add_crystal() -> void: # Called by crystal.gd whenever the player collects a power crystal
	crystal_score += CRYSTAL_POINTS # Adds 100 points to score
	power_crystals += 1

# Gadget collecting tracker
func add_gadget() -> void: # Called when the player picks up a gadget
	gadgets += 1

# Display total score
func display_score() -> int: # Called by the UI every frame during active gameplay
	return (travel_score + dodge_score + crystal_score) # Adds all scoring systems together, resulting in total score

# Crash tracker
func player_crash(crash_type: String = "") -> void: # Called when the player crashes
	# Depending on the cause of crash, adds 1 of that to the current run data
	if crash_type == "robot":
		robot_crash += 1
	elif crash_type == "scaffolding":
		scaffolding_crash += 1
	elif crash_type == "drone":
		drone_crash += 1

# Saves the run into the database
func save_run() -> Dictionary: # Called by the game over UI
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
	db.insert_row("stats", run_data) # Saves the current run data into stats table
	return run_data # Displays only the data from the current run onto the game over UI

# Resets the stats from the current run back to 0 for a new run
func reset_run_stats() -> void: # Called after game over UI finishes executing
	total_distance_meters = 0
	pixels_traveled = 0.0
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
