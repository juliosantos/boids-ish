require "matrix"
require "pry"

class Position < Struct.new(:x, :y, :z)
  def - (position)
    to_vector - position.to_vector
  end

  def to_vector
    Vector[x, y, z]
  end

  def distance_to(position)
    Math.sqrt((position.x - x)**2 + (position.y - y)**2 + (position.z - z)**2)
  end
end

class Velocity < Struct.new(:dx, :dy, :dz); end

class Flyer
  attr_accessor :id, :position, :velocity

  MAX_ACCELERATION = 1
  MAX_VELOCITY = 1
  COLLISION_RADIUS = 1

  def initialize(id:, position:, velocity:)
    @id = id
    @position = position
    @velocity = velocity
  end

  def update
    @position.x += @velocity.dx
    @position.y += @velocity.dy
    @position.z += @velocity.dz
  end

  def distance_to(other_flyer)
    position.distance_to(other_flyer.position)
  end

  def check_collision(other_flyers)
    return if other_flyers.empty?

    other_flyers.map do |other_flyer|
      distance_to(other_flyer)
    end.min < COLLISION_RADIUS && raise("collision")
  end

  def maintain_distance_from(other_flyer, distance=0, options = {})
    raise "collision" if options[:detect_collision] && distance_to(other_flyer) < COLLISION_RADIUS

    acceleration = ((distance_to(other_flyer)-distance)**3).clamp(-MAX_ACCELERATION, MAX_ACCELERATION)

    Vector[other_flyer.position.x - @position.x, other_flyer.position.y-@position.y].then do |vector|
      return if vector.zero?

      vector = vector.normalize

      @velocity.dx = (@velocity.dx + vector[0]*acceleration).clamp(-MAX_VELOCITY, MAX_VELOCITY)
      @velocity.dy = (@velocity.dy + vector[1]*acceleration).clamp(-MAX_VELOCITY, MAX_VELOCITY)
    end
  end

  def move_with(other_flyer)
    new_direction_vector = velocity_vector + other_flyer.velocity_vector

    acceleration_x = new_direction_vector[0].clamp(-MAX_ACCELERATION, MAX_ACCELERATION)
    acceleration_y = new_direction_vector[1].clamp(-MAX_ACCELERATION, MAX_ACCELERATION)

    #binding.pry

    @velocity.dx = (@velocity.dx + acceleration_x).clamp(-MAX_VELOCITY, MAX_VELOCITY)
    @velocity.dy = (@velocity.dy + acceleration_y).clamp(-MAX_VELOCITY, MAX_VELOCITY)

    #puts @velocity
  end

  def velocity_vector
    Vector[@velocity.dx, @velocity.dy]
  end

  def move_away_from(other_flyers)
    return if other_flyers.empty?

    reaction_vector = other_flyers.map do |other_flyer| Vector[@position.x - other_flyer.position.x, @position.y - other_flyer.position.y]; end.reduce(:+)

    acceleration_x = reaction_vector[0].clamp(-MAX_ACCELERATION, MAX_ACCELERATION)
    acceleration_y = reaction_vector[1].clamp(-MAX_ACCELERATION, MAX_ACCELERATION)
    
    @velocity.dx = (@velocity.dx + acceleration_x).clamp(-MAX_VELOCITY, MAX_VELOCITY)
    @velocity.dy = (@velocity.dy + acceleration_y).clamp(-MAX_VELOCITY, MAX_VELOCITY)

    #binding.pry
  end

  def approach(other_flyers, scale_acceleration:1)
    target_center = [
      other_flyers.map(&:position).map(&:x).sum / other_flyers.size,
      other_flyers.map(&:position).map(&:y).sum / other_flyers.size,
      other_flyers.map(&:position).map(&:z).sum / other_flyers.size,
    ]

    reaction_vector = Vector[
      target_center[0] - @position.x,
      target_center[1] - @position.y,
      target_center[2] - @position.z,
    ]

    acceleration_x, acceleration_y, acceleration_z =
      (reaction_vector.normalize * scale_acceleration * MAX_ACCELERATION).to_a

    @velocity.dx = (@velocity.dx + acceleration_x).clamp(-MAX_VELOCITY, MAX_VELOCITY)
    @velocity.dy = (@velocity.dy + acceleration_y).clamp(-MAX_VELOCITY, MAX_VELOCITY)
    @velocity.dz = (@velocity.dz + acceleration_z).clamp(-MAX_VELOCITY, MAX_VELOCITY)
  rescue
    binding.pry
  end

  def escape(other_flyers)
    return if other_flyers.empty?

    target_center = [
      other_flyers.map(&:position).map(&:x).sum / other_flyers.size,
      other_flyers.map(&:position).map(&:y).sum / other_flyers.size,
    ]

    reaction_vector = Vector[@position.x - target_center[0], @position.y - target_center[1]]

    acceleration_x = reaction_vector[0].clamp(-MAX_ACCELERATION, MAX_ACCELERATION)
    acceleration_y = reaction_vector[1].clamp(-MAX_ACCELERATION, MAX_ACCELERATION)

    @velocity.dx = (@velocity.dx + acceleration_x).clamp(-MAX_VELOCITY, MAX_VELOCITY)
    @velocity.dy = (@velocity.dy + acceleration_y).clamp(-MAX_VELOCITY, MAX_VELOCITY)
  end

  def separate(other_flyers, scale_acceleration:1)
    return if other_flyers.empty?

    other_flyers
      .map(&:position)
      .map(&:to_vector)
      .zip(Array.new(other_flyers.size) { @position.to_vector })
      .map{ |pv| pv.reduce(:-) }
      .reduce(Vector[0, 0, 0]) do |memo, vector|
        memo = memo - vector
      end
      .then do |reaction_vector|
        return if reaction_vector.zero?

        acceleration_x, acceleration_y, acceleration_z =
          (reaction_vector.normalize * scale_acceleration * MAX_ACCELERATION).to_a

        @velocity.dx = (@velocity.dx + acceleration_x).clamp(-MAX_VELOCITY, MAX_VELOCITY)
        @velocity.dy = (@velocity.dy + acceleration_y).clamp(-MAX_VELOCITY, MAX_VELOCITY)
        @velocity.dz = (@velocity.dz + acceleration_z).clamp(-MAX_VELOCITY, MAX_VELOCITY)
      rescue
        binding.pry
      end
  end
end

def plot(attractors, flyers)
  plot_data = [
    attractors.map do |attractor|
      [attractor.position.x, attractor.position.y, attractor.position.z, "💰"].join("\t")
    end.join("\n"),
    flyers.map.with_index do |flyer, index|
      #[flyer.position.x, flyer.position.y, flyer.position.z, flyer.id].join("\t")
      [flyer.position.x, flyer.position.y, flyer.position.z, "*"].join("\t")
    end.join("\n"),
  ].join("\n")

  File.write("frame.txt", plot_data.to_s)
end

flyers = Array.new(200) do |i|
  Flyer.new(
    id: ("A".."Z").to_a[i],
    position: Position.new(*[(-200.00..200.00), (-200.00..200.00), (-200.00..200.00)].map(&method(:rand))),
    velocity: Velocity.new(1, 1, 1),
  )
end

fixed_attractors = [
  Flyer.new(
    id: nil,
    position: Position.new(0, 0, 0),
    velocity: Velocity.new(0, 0, 0),
  ),
]
fixed_attractors = []

orbiting_attractors = Array.new(3) do |i|
  Flyer.new(
    id: i,
    position: Position.new(0, 0, 0),
    velocity: Velocity.new(0, 0, 0),
  )
end

target_distance_between_fliers = 20
target_distance_from_attractors = 50

attractor_orbit_speed = 1
attractor_orbit_radius = 100
attractor_orbit_scatter = 360 / orbiting_attractors.size
sleep_time = 0

center_attractor = Flyer.new(
  id: nil,
  position: Position.new(0, 0, 0),
  velocity: Velocity.new(0, 0, 0),
)
attractors = [center_attractor]
  
plot(attractors, flyers)

10e7.to_i.times do |i|
  #attractors.each_with_index do |orbiting_attractor, index|
    #angle_deg = (i + 0 * attractor_orbit_scatter) % 360
    #angle_rad = angle_deg * (2 * Math::PI) / 360

    #orbiting_attractors[0].position.x = attractor_orbit_radius*0.5 * Math.cos(attractor_orbit_speed * angle_rad)
    #orbiting_attractors[0].position.y = attractor_orbit_radius*0.5 * Math.sin(attractor_orbit_speed * angle_rad)
    #orbiting_attractors[1].position.x = attractor_orbit_radius*1.0 * Math.sin(attractor_orbit_speed * angle_rad)
    #orbiting_attractors[1].position.y = attractor_orbit_radius*1.0 * Math.cos(attractor_orbit_speed * angle_rad)
    #orbiting_attractors[2].position.x = attractor_orbit_radius*1.5 * Math.cos(attractor_orbit_speed * angle_rad)
    #orbiting_attractors[2].position.y = attractor_orbit_radius*1.5 * Math.sin(attractor_orbit_speed * angle_rad)

    #attractors.each_with_index do |orbiting_attractor, index|
    #  if index % 2 == 0
    #    orbiting_attractor.position.z = Math.sin(i / 10 / 360.0 * Math::PI*2)*200
    #  else
    #    orbiting_attractor.position.z = Math.cos(i / 10 / 360.0 * Math::PI*2)*200
    #  end
    #end
  #end

  flyers.each do |flyer|
    other_flyers = flyers - [flyer]

    nearby_flyers = other_flyers.select do |other_flyer|
      flyer.distance_to(other_flyer) < target_distance_between_fliers
    end

    flyer.separate(nearby_flyers, scale_acceleration: 1)
    flyer.approach(other_flyers, scale_acceleration: 1e-2)
    flyer.approach(attractors, scale_acceleration: 1e-1)

    flyer.update
  end

  flyers.sort_by do |flyer|
    flyer.distance_to(attractors[0])
  end.each do |flyer|
    other_flyers = flyers - [flyer]
    nearby_flyers = other_flyers.select do |other_flyer|
      flyer.distance_to(other_flyer) < target_distance_between_fliers
    end

    #flyer.check_collision(nearby_flyers)
  end

  plot(attractors, flyers)
end

10e7.to_i.times do |i|
  all_attractors = fixed_attractors + orbiting_attractors

  #orbiting_attractors.each_with_index do |orbiting_attractor, index|
  #  angle_deg = (i + index * attractor_orbit_scatter) % 360
  #  angle_rad = angle_deg * (2 * Math::PI) / 360

  #  orbiting_attractor.position.x = attractor_orbit_radius * Math.cos(attractor_orbit_speed * angle_rad)
  #  orbiting_attractor.position.y = attractor_orbit_radius * Math.sin(attractor_orbit_speed * angle_rad)
  #end

  angle_deg = (i + 0 * attractor_orbit_scatter) % 360
  angle_rad = angle_deg * (2 * Math::PI) / 360
  orbiting_attractors[0].position.x = attractor_orbit_radius*0.5 * Math.cos(attractor_orbit_speed * angle_rad)
  orbiting_attractors[0].position.y = attractor_orbit_radius*0.5 * Math.sin(attractor_orbit_speed * angle_rad)
  orbiting_attractors[1].position.x = attractor_orbit_radius*1.5 * Math.sin(attractor_orbit_speed * angle_rad)
  orbiting_attractors[1].position.y = attractor_orbit_radius*1.5 * Math.cos(attractor_orbit_speed * angle_rad)

  flyers.shuffle.each do |flyer|
    other_flyers = (flyers - [flyer]).shuffle

    while ((nearby_flyers = other_flyers.select{|f| flyer.distance_to(f) < target_distance_between_fliers/3 }).any?)
      nearby_flyers.shuffle.each do |other_flyer|
        flyer.maintain_distance_from(other_flyer, target_distance_between_fliers, detect_collision: false)
        flyer.update
        flyer.move_with(other_flyer)
        flyer.update
        #plot(all_attractors, flyers)
      end
    end

    while ((nearby_attractors = all_attractors.select{|a| flyer.distance_to(a) < target_distance_from_attractors }).any?)
      nearby_attractors.each do |attractor|
        flyer.maintain_distance_from(attractor, target_distance_from_attractors)
        flyer.update
      end
    end

    flyer.approach(all_attractors)
    flyer.update
  end

  plot(all_attractors, flyers) if i%5==0
  sleep sleep_time
end
