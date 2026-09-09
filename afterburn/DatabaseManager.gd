extends Node

var db: SQLite # The database variable

# Distance scoring variables
const PIXELS_PER_POINT: float = 32.0 # Low pixel count keeps the score ticking up as the player moves
var pixels_traveled: float = 0.0 # Tracks the total distance the player has moved
var travel_score: int = 0 # The points the player gets from moving

# Dodge scoring variables
const POINTS_PER_DODGE: int = 10 # Jumping over, sliding under, or dashing through obstacles is worth 10 points
var dodge_score: int = 0 # The points the player gets from dodging

# Crystal scoring variables
const CRYSTAL_POINTS: int = 100 # Collecting a power crystal is worth 100 points
var crystal_score: int = 0 # The points the player gets from collecting power crystals

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	db = SQLite.new() # Initialize database
	db.path = "user://game_data.db" # The file address used
	db.open_db() # Creates the file, or opens if it exists
	
	create_scores_table() # Execute table creation on startup

# Creates Scores table
func create_scores_table() -> void:
	var scores_query:="""
	CREATE TABLE IF NOT EXISTS Scores (
		ScoresID INTEGER PRIMARY KEY,
		TravelScore INTEGER,
		DodgeScore INTEGER,
		CrystalScore INTEGER,
		TotalScore INTEGER
	);
	"""
	db.query(scores_query)

# Distance traveled scoring system
func add_distance(pixels_moved: float) -> void: # Tracks the distance traveled per frame. Called by player.gd every frame during active gameplay
	pixels_traveled += pixels_moved # Adds the distance from each frame to the total
	travel_score = int(pixels_traveled / PIXELS_PER_POINT) # Total distance divided by 32 equals 1 point added to score

# Obstacles dodged scoring system
func add_dodge() -> void: # Called by obstacle collision/detection whenever the player dodges an obstacle
	dodge_score += POINTS_PER_DODGE # Adds 10 points to score

# Crystals collected scoring system
func add_crystal() -> void: # Called by crystal.gd whenever the player collects a power crystal
	crystal_score += CRYSTAL_POINTS # Adds 100 points to score

# Displayed score
func display_score() -> int: # Called by the UI every frame during active gameplay
	return (travel_score + dodge_score + crystal_score) # Adds all scoring systems together, resulting in total score
