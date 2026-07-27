extends Node2D

enum Dir { RIGHT, LEFT, UP, DOWN }
@export var starting_direction: Dir = Dir.RIGHT

const MAX_DIST = 2000.0
const LASER_WIDTH = 10.0 

func _process(_delta):
	queue_redraw()

func _draw():
	var current_pos = global_position
	var current_dir = get_starting_dir_vector()
	
	var current_color = Color.GREEN 
	var current_color_name = "green"
	
	var exceptions = [self, get_parent()]
	
	for i in range(25):
		var end_pos = current_pos + (current_dir * MAX_DIST)
		var space_state = get_world_2d().direct_space_state
		
		var query = PhysicsRayQueryParameters2D.create(current_pos, end_pos)
		query.exclude = exceptions
		query.collide_with_areas = false 
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		
		if result:
			var collider = result.collider
			var hit_pos = result.position
			
			draw_laser_segment(current_pos, hit_pos, current_color)
			
			# --- REFLECTION CHECK ---
			# We check for the method first to be safe
			if collider.has_method("get_reflection"):
				# print("Hit Mirror!") # Uncomment this to debug in the console
				current_dir = collider.get_reflection(current_dir)
				# Increased nudge to 2.0 to ensure it clears the collision shape
				current_pos = hit_pos + (result.normal * 2.0)
				exceptions.append(collider)
				
			elif collider.is_in_group("filters"):
				if "filter_color_name" in collider:
					current_color_name = collider.filter_color_name
				if "filter_visual_color" in collider:
					current_color = collider.filter_visual_color
				
				# Pass straight through
				current_pos = hit_pos + (current_dir * 2.0)
				exceptions.append(collider)
				
			elif collider.is_in_group("targets"):
				if collider.has_method("on_hit"):
					collider.on_hit(current_color_name)
				current_pos = hit_pos + (current_dir * 2.0)
				exceptions.append(collider)
			else:
				# Wall hit
				break
		else:
			draw_laser_segment(current_pos, end_pos, current_color)
			break

func draw_laser_segment(start: Vector2, end: Vector2, color: Color):
	var local_start = to_local(start)
	var local_end = to_local(end)
	draw_line(local_start, local_end, color, LASER_WIDTH, true)
	draw_circle(local_end, LASER_WIDTH / 2.0, color)

func get_starting_dir_vector() -> Vector2:
	match starting_direction:
		Dir.RIGHT: return Vector2.RIGHT
		Dir.LEFT:  return Vector2.LEFT
		Dir.UP:    return Vector2.UP
		Dir.DOWN:  return Vector2.DOWN
	return Vector2.RIGHT
