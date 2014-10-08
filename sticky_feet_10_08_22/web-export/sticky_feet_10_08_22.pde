//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: simulation set-up and various helper routines

import processing.opengl.*;

float sx = 1280;              // width of simulation region
float sy = 960;               // height

//float sx = 640;              // width of simulation region
//float sy = 480;              // height

int target_creature_count = 100;
int num_groups = 1;
creature[] group_representative = new creature[num_groups];

float world_width = 70;       // width of the world in creature units
float world_height = world_width * sy / sx;
int stroke_width = 1;         // width of drawn line segments

float mutation_rate = 0.1;        // probability of mutating when a new creature is created
float mutate_again  = 0.4;        // if mutation, probability of mutating more than once
float competition_noise = 0.0;    // amount of noise in declaring winner, in [0,1]
int max_segments = 15;            // maximum number of segments in a creature

float heart_radius = 0.5;
int tail_length_global = 60;
int tail_update_rate = 40;

ArrayList creatures = new ArrayList();    // list of creatures

int counter = 0;                 // counts number of time-steps
int species_count = 0;           // unique id for new creatures
int birth_count = 0;             // number of total births in simulation
float time = 0;                  // global clock
boolean auto_write_flag = true;  // whether to automatically write out state files
int auto_write_count = 200000;   // number of timesteps between automatic file writing
int world_seed = 0;              // random number seed for the world

float dt = 0.1;                 // simulation time-step
int steps_per_draw = 100;        // how many simulation steps to take before drawing

float viscous_damping = 0.5;     // global damping constant
float friction_coeff = 2.0;      // friction coefficient with floor and walls
float spring_k_global = 1;       // global multiplier for spring constants
float spring_damp_global = 1;    // global multiplier for spring damping
float default_freq = 0.5;        // default frequency for springs
float default_k_spring = 5;      // default spring constant
float default_k_damp = 0.5;      // default spring damping value

boolean simulation_flag = true;       // perform simulation?
boolean sensor_show_flag = false;     // show sensor positions?
boolean tail_flag = false;            // draw the creature's tail?
boolean heart_draw_flag = true;       // draw the creature's heart?
boolean clip_flag = true;             // clip the drawing commands?
boolean draw_info_flag = false;       // draw information text?
boolean frame_flag = false;           // draw a frame around the border of the screen?

// colors of various parts of the interface
color background_color = color (255, 255, 255);
color bright_color = color (0, 0, 0);
color dull_color = color (180, 180, 180);
color fixed_color = color (255, 0, 0);
color highlight_color = color (0, 255, 0);
color crossing_color = color (255, 200, 0);
color mouth_color = color (0, 0, 0);
color heart_color = color (200, 0, 0);
color tail_color = color (220, 220, 220);
color select_color = color (150, 150, 150);
color red = color (255, 0, 0);
color green = color (0, 255, 0);

search_grid creature_grid;       // grid for fast spatial search for creatures

PFont font;    // font for drawing letters in window

// initialize various things
void setup()
{
  int i;
  creature c;
  
  world_seed = (int) random(10000);
  randomSeed(world_seed);
  println ("random number seed = " + world_seed);

  // set the window size
  size ((int) sx, (int) sy, OPENGL);
//  hint(ENABLE_OPENGL_4X_SMOOTH);
//  hint(DISABLE_OPENGL_2X_SMOOTH);  // use this on laptop to stop flickering
  
  // set some default colors
  stroke (bright_color);
  fill (bright_color);
  background (background_color);
  
  // width of lines
  strokeWeight(stroke_width);
  
  // create initial set of creatures
  init_creatures();
  
  println (creatures.size() + " creatures");
  
  // initialize grid for fast center-of-mass finding
  int nx = 10;
  int ny = 10;
  creature_grid = new search_grid (nx, ny, nx / world_width, ny / world_height);
  
  // load font
  font = loadFont ("ArialNarrow-20.vlw");
  textFont (font, 20);
  
  frameRate(9000);

  println ("See README.txt for keyboard commands");
}

// delete all of the creatures from the environment
void delete_all_creatures()
{
  int i;
  
  // remove all creatures
  for (i = creatures.size() - 1; i >= 0; i--)
    creatures.remove(i);
  
  // remove all events from the list of kills
  for (i = kill_list.size() - 1; i >= 0; i--) {
    cross_event e = (cross_event) kill_list.get(i);
    kill_list.remove(i);
  }
}

// make the initial distribution of creatures
void init_creatures()
{
  int i;
  creature c;
  
  // first, delete all creatures
  delete_all_creatures();
  
  // re-set various counts and flags
  counter = 0;
  birth_count = 0;
  species_count = 0;
  time = 0;
  
  // sessile creature
  c = new creature();
  birth_by_hand(c);
  c.add_point(7, 6, false);
  c.add_point(6, 6, false);
  c.add_segment (0, 1, 1, 0, 0, 0, 0);
  c.points[0].is_heart = true;
  c.segments[0].sensor_dist = 0;
  c.translate(random (world_width), random (world_height));
  creatures.add(c);
  
  // create duplicates creatures and place them randomly
  int num = target_creature_count - num_groups - 1;
  for (i = 0; i < num; i++) {
    c = (creature) creatures.get(0);
    boolean birth_successful = birth (c, 10, false);
    c = (creature) creatures.get(creatures.size()-1);
    c.group_id = i % num_groups;
  }
  
  // one-segment creature
  c = new creature();
  birth_by_hand(c);
  c.add_point(7, 5.5, false);
  c.add_point(6, 5.5, false);
  c.add_segment (0, 1, 1.0, 0.2, default_freq * 2, 0, 1.0);
  c.points[1].is_mouth = true;
  c.points[0].is_heart = true;
  c.segments[0].sensor_set (140, 3, 1.7, SENSOR_HEART);
  c.segments[0].controller_set (CONTROL_FOOT_AMP, CONTROLLER_CONSTANT, 0.0, -1);
  creatures.add(c);
  c.translate(0.5 * world_width, 0.5 * world_height);
  c.rotate(0.3);
  c.col = green;

  // maybe create multiple groups
  if (num_groups > 1) {
    // duplicate the last creature made, so there are num_group copies in total
    for (i = 0; i < num_groups-1; i++) {
      birth (c, 10, false);
    }
    // make sure all of these creatures have the correct group_id and color
    for (i = 0; i < num_groups; i++) {
      c = (creature) creatures.get(creatures.size() - i - 1);
      group_representative[i] = c;
      c.group_id = i;
      pick_color_from_group (c, i, false);
    }
  }  
  
}

// perform one cycle of simulation
void draw()
{
  int i;
  
  // maybe take one simulation timestep
  if (simulation_flag) {
    // take a timestep
    one_timestep();
  }
  
  float x = world_width * mouseX / sx;
  float y = world_width * (sy - mouseY) / sx;

  // draw everything, but maybe not every time-step
  if (counter % steps_per_draw == 0) {
    draw_all();
  }
}

// draw everything that goes on the screen
void draw_all()
{
  // clear screen
  background(background_color);
  
  // draw kills
  draw_kills();

  // draw all creatures
  draw_all_creatures();
  
  // maybe draw frame around window's border
  if (frame_flag) {
    stroke (bright_color);
    noFill();
    strokeWeight(4);
    line (0, 0, 0, sy);
    line (0, sy, sx, sy);
    line (sx, sy, sx, 0);
    line (sx, 0, 0, 0);
    strokeWeight(stroke_width);
  }
  
  // maybe draw information
  if (draw_info_flag == true) {
    draw_info();
  }  
}

void draw_info()
{
  float xpos = 20;
  
  fill (bright_color);
  
  text ("counter       = " + counter, xpos, 40);
  text ("birth count   = " + birth_count, xpos, 60);
  text ("species count = " + species_count, xpos, 80);
  text ("num creatures = " + creatures.size(), xpos, 100);
}

// take one simulation time-step for all creatures
void one_timestep() {
  int i;
  
  // calculate the sensor readings of the creatures
  sensor_check();
  
  // move each creature
  for (i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    c.one_timestep();
  }
  
  // see if creatures need to wrap around screen
  check_edge_wrap();
  
  // see if any creatures eat each other
  check_eating();
  
  // see if we should write out creature file
  if (auto_write_flag && counter % auto_write_count == 0 && counter > 0) {
    println ("writing creatures to a file at timestep " + counter);
    write_creatures_to_file();
    // re-seed the random number generator
    randomSeed(world_seed);
  }
  
  // advance the clock
  time += dt;
  counter++;
}

// draw all of the creatures
void draw_all_creatures() {
  int i;
  for (i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    c.draw();
  }
}

// draw a line in world-space
void line_world (float x1, float y1, float x2, float y2)
{
  float s = sx / world_width;
  float ww = world_width;
  float hh = world_height;
  
  if (!clip_flag) {
    line (x1 * s, (hh - y1) * s, x2 * s, (hh - y2) * s);
    return;
  }

  line_clip (x1 * s, (hh - y1) * s, x2 * s, (hh - y2) * s);
  
  if (x1 < 0 || x2 < 0)
    line_clip ((x1 + ww) * s, (hh - y1) * s, (x2 + ww) * s, (hh - y2) * s);
    
  if (y1 < 0 || y2 < 0)
    line_clip (x1 * s, -y1 * s, x2 * s, -y2 * s);
  
  if (x1 > ww || x2 > ww)
    line_clip ((x1 - ww) * s, (hh - y1) * s, (x2 - ww) * s, (hh - y2) * s);
  
  if (y1 > hh || y2 > hh)
    line_clip (x1 * s, (2 * hh - y1) * s, x2 * s, (2 * hh - y2) * s);
}

// draw a clipped line in world-space
void line_clip (float x1, float y1, float x2, float y2)
{
  // if line doesn't cross right edge, just draw it and return
  if (x1 < sx && x2 < sx) {
    line (x1, y1, x2, y2);
    return;
  }
  
  // if line is entirely on the wrong side of the right edge, don't draw anything
  if (x1 > sx && x2 > sx)
    return;
  
  // if we get here, we have to clip against the right edge

  // figure out where the clip point (x,y) is
  float t = (sx - x1) / (x2 - x1);
  float x = sx;
  float y = y1 + t * (y2 - y1);

  if (x1 < x2)
    line (x1, y1, x, y);
  else
    line (x, y, x2, y2);
}

// draw a circle in world-space
void circle_world (float x, float y, float rad)
{
  float s = sx / world_width;
  float ww = world_width;
  float hh = world_height;
  boolean my_circle_flag = true;
  
  rad *= s;
  
  if (my_circle_flag) {
    if (!clip_flag) {
      my_circle (x * s, (hh - y) * s, rad);
      return;
    }

    if (x < ww)
      my_circle (x * s, (hh - y) * s, rad);
    
    if (x < 0)
      my_circle ((x + ww) * s, (hh - y) * s, rad);
    
    if (y < 0)
      my_circle (x * s, -y * s, rad);
    
    if (x > ww)
      my_circle ((x - ww) * s, (hh - y) * s, rad);
    
    if (y > hh)
      my_circle (x * s, (2 * hh - y) * s, rad);  }
  else {
    rad *= 2;  // ellipse command uses width (diameter for circle), not radius
  
    if (!clip_flag) {
      ellipse (x * s, (hh - y) * s, rad, rad);
      return;
    }

    if (x < ww)
      ellipse (x * s, (hh - y) * s, rad, rad);
    
    if (x < 0)
      ellipse ((x + ww) * s, (hh - y) * s, rad, rad);
    
    if (y < 0)
      ellipse (x * s, -y * s, rad, rad);
    
    if (x > ww)
      ellipse ((x - ww) * s, (hh - y) * s, rad, rad);
    
    if (y > hh)
      ellipse (x * s, (2 * hh - y) * s, rad, rad);
  }
}

// my circle drawing routine
void my_circle(float x, float y, float rad)
{
  int steps = 32;
  
  float xold = x + rad;
  float yold = y;
  
  strokeJoin(MITER);
  beginShape();
  for (int i = 0; i <= steps; i++) {
    float theta = 2 * 3.1415926535 * i / (float) steps;
    float xnew = x + rad * cos(theta);
    float ynew = y + rad * sin(theta);
//    line (xold, yold, xnew, ynew);
    vertex (xnew, ynew);
    xold = xnew;
    yold = ynew;
  }
  endShape();
}

// check to see if creature moved off one edge of the screen
void check_edge_wrap()
{
  int i,j;
  
  for (i = 0; i < creatures.size(); i++) {
    
    creature c = (creature) creatures.get(i);
    if (c.pnum == 0)
      continue;
    
    c.find_bounds();  // find bounding box for creature and store in global variables (yuck)
    
    if (c.xmax < 0) {
      for (j = 0; j < c.pnum; j++) {
        c.points[j].x    += world_width;
        c.points[j].xold += world_width;
      }
    }
    else if (c.xmin > world_width) {
      for (j = 0; j < c.pnum; j++) {
        c.points[j].x    -= world_width;
        c.points[j].xold -= world_width;
      }
    }

    if (c.ymax < 0) {
      for (j = 0; j < c.pnum; j++) {
        c.points[j].y    += world_height;
        c.points[j].yold += world_height;
      }
    }
    else if (c.ymin > world_height) {
      for (j = 0; j < c.pnum; j++) {
        c.points[j].y    -= world_height;
        c.points[j].yold -= world_height;
      }
    }
  }
}

// process keyboard events
void keyPressed() {
  
//  println ("keyPressed");

  if (key == ' ') {
     simulation_flag = !simulation_flag;
     if (simulation_flag)
       println ("simulation on");
     else
       println ("simulation off");
  }
  else if(key == 'p' || key == 'P') {
     saveFrame("frame-####.png");
  }
  else if(key == 'd' || key == 'D') {
     draw_info_flag = !draw_info_flag;
     println ("draw_info_flag = " + draw_info_flag);
  }
  else if(key == 'i' || key == 'I') {
    init_creatures();
    simulation_flag = false;
    record_species_flag = false;
    draw_all();
  }
  else if(key == 'r') {  // use chooser to specify file name
     println ("reading creatures from a file");
     read_creatures_from_file(true);
     draw_all();
  }
  else if(key == 'R') {  // use "creatures.txt" for file name
     println ("reading creatures from a file");
     read_creatures_from_file(false);
     draw_all();
  }
  else if(key == 's' || key == 'S') {
     simulation_flag = false;
     one_timestep();
     println ("single step");
  }
  else if(key == 't' || key == 'T') {
     tail_flag = !tail_flag;
     println ("tail_flag = " + tail_flag);
  }
  else if(key == 'w' || key == 'W') {
     println ("writing creatures to a file");
     write_creatures_to_file();
  }
  else if(key == 'x' || key == 'X') {
     sensor_show_flag = !sensor_show_flag;
     if (sensor_show_flag)
       println ("showing sensors");
     else
       println ("not showning sensors");
     draw_all();
  }
  else if(key == 'q' || key == 'Q') {
     exit();
  }
}

//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: create new creatures (birth)

// Create a new creature that is a copy of the parent.
// Return "true" if creature was successfully created and placed.
boolean birth (creature parent, int num_tries, boolean mutate_okay)
{
  int i,j;
  creature c;
  boolean did_mutate = false;
  
  // create the new creature
  // (note that the copy routine adds the creature to the list of all creatures in the world)
  creature child = parent.copy();
  
  // maybe mutate child
  if (mutate_okay && random(1) < mutation_rate) {
    mutate_creature (child);
    did_mutate = true;
  }
  
  // add the same random amount to the phase of all segments
  float dp = 0.2 * (random(1) - 0.5);
  for (i = 0; i < child.snum; i++) {
    segment s = child.segments[i];
    s.phase += dp;
    if (s.phase < 0) s.phase += 1;
    if (s.phase > 1) s.phase -= 1;
  }
  
  // add random amount to creature's global phase
  child.phase += 0.2 * (random(1) - 0.5);
  if (child.phase < 0) child.phase += 1;
  if (child.phase > 1) child.phase -= 1;
  
  // calculate bounding boxes for all creatures
  for (i = 0; i < creatures.size(); i++) {
    c = (creature) creatures.get(i);
    c.find_bounds();
  }
  
  // rotate the child creature to a random orientation
  float theta = random (PI * 2);
  child.rotate (theta);
  
  // now attempt several times to randomly place child so that it
  // does not intersect another creature
  for (i = 0; i <num_tries; i++) {
    
    // pick random position to try for child
    float rx = random (world_width);
    float ry = random (world_height);
    
    // place the child centered at (rx, ry)
    child.translate (rx, ry);

    // see if this new position for the child intersects any other creatures
    boolean was_intersection = false;
    for (j = 0; j < creatures.size(); j++) {
      c = (creature) creatures.get(j);
      if (c == child)
        continue;
      if (creatures_intersect (c, child)) {
        was_intersection = true;
        break;
      }
    }
    
    // if there was no intersection, we successfully birthed
    if (was_intersection == false) {
      // record successful birth and give inidividual ID to creature
      child.individual_id = birth_count++;
      // update species count and creature's species ID, if necessary
      if (did_mutate) {
        child.species_id = species_count++;        // record the species count
        new_species(child, parent.species_id);  // add the new species to the species list
        increment_offspring_count(parent);         // increment the offspring count of parent species
      }
      increment_species_count(child);        // increase the count of individuals of a species
      return (true);
    }
  }
  
  // if we get here, we were not able to find a place for the child,
  // so we need to delete it from the list of creatures
  creatures.remove(creatures.size()-1);
  
  // signal that we were unable to place a new creature
  return (false);
}

// performed creature birth "by hand", and need to take care of a few things
void birth_by_hand(creature c)
{
  c.individual_id = birth_count++;
  c.species_id = species_count++;
  new_species(c, -1);                // add the new species to the species list
  increment_species_count(c);        // increase the count of individuals of a species
}

// see whether two creatures intersect one another
// (assumes that the creature's bounds are up-to-date)
boolean creatures_intersect (creature c1, creature c2) {
  
  boolean x_overlap = true;
  boolean y_overlap = true;
  
  if (c1.xmax < c2.xmin || c2.xmax < c1.xmin)
    x_overlap = false;
    
  if (c1.ymax < c2.ymin || c2.ymax < c1.ymin)
    y_overlap = false;
  
  if (x_overlap == true && y_overlap == true)
    return (true);
  else
    return (false);
}
//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: mass-spring crawling creature classes

int num_controllers = 3;
final int CONTROL_AMP        = 0;
final int CONTROL_FOOT_AMP   = 1;
final int CONTROL_FOOT_SHIFT = 2;

// 2D point-mass class
class point {
  
  float x,y;
  float xold,yold;
  float vx,vy;
  float vxold,vyold;
  float ax,ay;
  float mass;
  boolean fixed_position;    // is this mass point fixed in position?
  boolean is_mouth;          // does this point act as a mouth for the creature?
  boolean is_heart;          // is this the creature's heart?
  float friction;            // amount of friction this mass has at the current time (may vary with time)
  
  point (float px, float py, boolean fix) {
    x = xold = px;
    y = yold = py;
    mass = 1;
    fixed_position = fix;
    is_mouth = false;
    is_heart = false;
    friction = 0;
  }
}

// one segment for a mass-spring creature
class segment {
  int i1,i2;         // indiices of points that the segment connects
  float length;      // natural length of segment
  float k_spring;    // spring constant
  float k_damp;      // damping coefficient
  float amp;         // amplitude of sinusoidal length change
  float freq;        // frequency of sinusoidal motion
  float phase;       // phase of sinusoidal motion
  float foot_amp;    // amplitude of foot friction for two endpoints
  float foot_shift;  // shift of foot amplitude
  
  // sensor attributes
  float sensor_cos;    // cosine of sensor angle
  float sensor_sin;    // sine of sensor angle
  float sensor_dist;   // distance of sensor from segment
  float sensor_rad;    // radius of sensor
  int sensor_type;     // sensitive to heart or mouth?  (SENSOR_HEART or SENSOR_MOUTH)
  float sensor_value;  // value returned by the sensor
  
  // controllers for various parameters
  controller[] controllers;
  
  segment(int i, int j, float len) {
    i1 = i;
    i2 = j;
    length = len;
    create_helper();
  }
  
  segment(int i, int j, float len, float a, float f, float p, float b) {
    i1 = i;
    i2 = j;
    length = len;
    create_helper();
    
    amp = a;
    freq = f;
    phase = p;
    foot_amp = b;
  }
  
  void create_helper() {
    k_spring = default_k_spring;
    k_damp = default_k_damp;
    
    amp = 0;
    freq = default_freq;
    phase = 0;
    foot_amp = 0;
    
    sensor_set (0, 0, 0, SENSOR_HEART);
    
    controllers = new controller[num_controllers];
    for (int i = 0; i < num_controllers; i++)
      controllers[i] = new controller (CONTROLLER_CONSTANT, 0, -1);
  }
  
  // copy the attributes of this sensor to another (doesn't include length and mass pointers)
  void copy_attributes(segment snew) {
    snew.k_spring = k_spring;
    snew.k_damp = k_damp;
    snew.sensor_cos = sensor_cos;
    snew.sensor_sin = sensor_sin;
    snew.sensor_rad = sensor_rad;
    snew.sensor_type = sensor_type;
    snew.sensor_dist = sensor_dist;
    for (int i = 0; i < num_controllers; i++) {
      snew.controllers[i].type = controllers[i].type;
      snew.controllers[i].weight = controllers[i].weight;
      snew.controllers[i].segment_num = controllers[i].segment_num;
    }
  }
  
  void sensor_set (float angle, float d, float rad, int stype) {
    angle *= PI / 180;
    sensor_cos = cos(angle);
    sensor_sin = sin(angle);
    sensor_dist = d;
    sensor_rad = rad;
    sensor_type = stype;  // SENSOR_HEART or SENSOR_MOUTH
  }
  
  void controller_set (int index, int t, float w, int snum) {
    controllers[index].type = t;   //  CONTROLLER_CONSTANT or CONTROLLER_SENSOR
    controllers[index].weight = w;
    controllers[index].segment_num = snum;
  }
}

// controllers, used to modify segment attributes based on sensors and so on
class controller {
  int type;                // type of controller (CONTROLLER_CONSTANT or CONTROLLER_SENSOR)
  float weight;            // controller weight (strength)
  int segment_num;         // which segment (if any) the controller gets its value from
  float value;             // calculated value of the controller
  
  controller (int t, float w, int snum) {
    type = t;
    weight = w;
    segment_num = snum;
  }
}

// mass-spring creature class
class creature {
  
  int pnum,pmax;
  point[] points;    // point masses of creature
  
  int snum,smax;
  segment[] segments;   // segments that connect the points
  
  //  bounding box for creature
  float xmin,xmax;
  float ymin,ymax;
  
  // center of mass (other creatures can sense this)
//  float cx,cy;
  
  // heart and mouth positions
  float hx,hy;
  float mx,my;
  
  // phase relative to global clock
  float phase;
  
  // creature appearance
  color col;
  
  // group this creature belongs to (for segregating populations)
  int group_id;
  
  int individual_id;     // unique creature identifier for an individual
  int species_id;        // identifier for the creature's species
  int status;            // for marking creatures that were eaten
  boolean on_near_list;  // whether creature is already on the list of nearby creatures
  
  // tail (for drawing where creature has been recently)
  int tail_length = tail_length_global;
  int tail_ptr = 0;
  float[] xtail;
  float[] ytail;
  
  // whether user has selected this creature with mouse
  boolean select_flag;
  
  // create a new creature
  creature() {
    int i;
    
    pnum = 0;
    pmax = 20;
    points = new point[pmax];
    
    snum = 0;
    smax = 20;
    segments = new segment[smax];
    
    col = bright_color;
    
    status = ALIVE;
    
    phase = 0;
    
    xtail = new float[tail_length];
    ytail = new float[tail_length];
    for (i = 0; i < tail_length; i++) {
      xtail[i] = 0.0;
      ytail[i] = 0.0;
    }
    
    // these ID's should be set by other routines
    individual_id = 0;
    species_id = 0;
    group_id = 0;
    
    // all creatures start out not selected
    select_flag = false;
  }
  
  void add_point (float xx, float yy, boolean fixed) {
    point p = new point(xx, yy, fixed);
    // make sure there is enough space for the new point
    if (pnum == pmax) {
      pmax *= 2;
      point[] points_new = new point[pmax];
      for (int i = 0; i < pnum; i++)
        points_new[i] = points[i];
      points = points_new;
    }
    // add point to list of points
    points[pnum++] = p;
  }
  
  void add_segment (int i1, int i2, float len) {
    segment s = new segment (i1, i2, len);
    // make sure there is enough space for the new segment
    if (snum == smax) {
      smax *= 2;
      segment[] segments_new = new segment[smax];
      for (int i = 0; i < snum; i++)
        segments_new[i] = segments[i];
      segments = segments_new;
    }
    // add segment to list of segments
    segments[snum++] = s;
  }
  
  void add_segment (int i1, int i2, float len, float amp, float freq, float phase, float foot_amp) {
    segment s = new segment (i1, i2, len, amp, freq, phase, foot_amp);
    // make sure there is enough space for the new segment
    if (snum == smax) {
      smax *= 2;
      segment[] segments_new = new segment[smax];
      for (int i = 0; i < snum; i++)
        segments_new[i] = segments[i];
      segments = segments_new;
    }
    // add segment to list of segments
    segments[snum++] = s;
  }
  
  // make a copy of a given creature
  creature copy()
  {
    int i;
    
    // create a new creatures and add it to the list of all creatures in the world
    creature c = new creature();
    creatures.add(c);
    c.col = col;
    c.phase = phase;
    c.select_flag = false;

    // belongs to same species and group as parent
    c.species_id = species_id;
    c.group_id = group_id;
    
    // create duplicate point masses
    for (i = 0; i < pnum; i++) {
      point p = points[i];
      c.add_point (p.x, p.y, p.fixed_position);
      point pnew = c.points[i];
      pnew.mass = p.mass;
      pnew.is_mouth = p.is_mouth;
      pnew.is_heart = p.is_heart;
    }
    
    // create duplicate segments
    for (i = 0; i < snum; i++) {
      segment s = segments[i];
      c.add_segment (s.i1, s.i2, s.length, s.amp, s.freq, s.phase, s.foot_amp);
      segment snew = c.segments[i];
      s.copy_attributes (snew);
    }
    
    return (c);
  }
  
  // place a creature centered on a given position (x,y)
  void translate (float x, float y)
  {
    // find the bounds of the creature
    find_bounds();
    
    // calculate appropriate translation values
    float dx = x - 0.5 * (xmax + xmin);
    float dy = y - 0.5 * (ymax + ymin);
    
    // translate the creature
    for (int i = 0; i < pnum; i++) {
      points[i].x += dx;
      points[i].y += dy;
      points[i].xold = points[i].x;
      points[i].yold = points[i].y;
    }
    
    // calculate new bounds
    find_bounds();
  }
  
  // rotate a creature by a given angle (in radians)
  void rotate (float theta) {
    
    // find the bounds of the creature
    find_bounds();
    
    // calculate creature center
    float cx = 0.5 * (xmin + xmax);
    float cy = 0.5 * (ymin + ymax);
    
    float cos_theta = cos(theta);
    float sin_theta = sin(theta);
    
    // perform rotation around the creature's center
    for (int i = 0; i < pnum; i++) {
      float x = points[i].x - cx;
      float y = points[i].y - cy;
      float xnew = cos_theta * x - sin_theta * y;   // CHECK THIS!!!
      float ynew = sin_theta * x + cos_theta * y;
      points[i].x = xnew + cx;
      points[i].y = ynew + cy;
      points[i].xold = points[i].x;
      points[i].yold = points[i].y;
    }
    
    // calculate the new bounds
    find_bounds();
  }
  
  // draw a creature
  void draw() {
    int i;
    
    // draw the creature's tail
    if (tail_flag) {
      stroke(tail_color);
      fill (tail_color);
      for (i = 0; i < tail_length; i++)
        circle_world (xtail[i], ytail[i], 0.1);
    }
    
    // draw all the line segments of the creature
    for (i = 0; i < snum; i++) {
      
      stroke (col);
      fill (col);
    
      segment s = segments[i];
      int i1 = segments[i].i1;
      int i2 = segments[i].i2;
      
      float x1 = points[i1].x;
      float y1 = points[i1].y;
      float x2 = points[i2].x;
      float y2 = points[i2].y;
      
      // calculate direction of segment and it's midpoint
      float dx = x1 - x2;
      float dy = y1 - y2;
      float len = sqrt (dx*dx + dy*dy);
      if (len > 0) {
        dx /= len;
        dy /= len;
      }
      float mx = 0.5 * (x1 + x2);
      float my = 0.5 * (y1 + y2);
      
      /*
      // show its direction of bias, if any
      if (segments[i].foot_amp != 0) {
        
      float xx,yy;
      float tiny = 0.1;
        if (segments[i].foot_amp < 0)
          tiny *= -1;
          
        xx = mx + tiny * (dx - dy);
        yy = my + tiny * (dy + dx);
        line_world (mx, my, xx, yy);
        xx = mx + tiny * (dx + dy);
        yy = my + tiny * (dy - dx);
        line_world (mx, my, xx, yy);
      }
      */
      
      // calculate value of sensor coefficient
      
      float eps = 0.1;
      float coef = 0.5 * (segments[i].controllers[CONTROL_FOOT_AMP].weight + 1);
      float px = x1 + coef * (x2 - x1);
      float py = y1 + coef * (y2 - y1);
      
      // maybe show the sensor position
//      if (sensor_show_flag && s.sensor_value > 0) {
      if (sensor_show_flag && s.sensor_dist > 0) {
        float rot_dx = s.sensor_dist * (dx * s.sensor_cos - dy * s.sensor_sin);
        float rot_dy = s.sensor_dist * (dx * s.sensor_sin + dy * s.sensor_cos);
        
        stroke (dull_color);
        fill (dull_color);
        
        // draw filled or open circle, depending on if sensor has been triggered
        if (s.sensor_value > 0)
          fill(dull_color);
        else
          noFill();
        
        circle_world (mx + rot_dx, my + rot_dy, 0.1 * (1 + 2 * s.sensor_value));
        line_world (px, py, mx + rot_dx, my + rot_dy);
      }

      stroke (col);
      fill (col);
      
      // draw the main body segment
      line_world (x1, y1, x2, y2);
    }
    
    // draw all the point masses of the creature
    for (i = 0; i < pnum; i++) {
      float x = points[i].x;
      float y = points[i].y;
      
      if (points[i].fixed_position) {
        stroke (fixed_color);
        fill (fixed_color);
      }
      else {
        stroke (col);
        fill (col);
      }

      float radius = 1;
      
      radius = 1 + 1 * points[i].friction;    // use this line to show sticky feet
      radius *= 0.1;

      circle_world (x, y, radius);

      // show mouths
      if (points[i].is_mouth) {
        radius = 0.3;
        stroke (mouth_color);
        noFill();
        if (status == ALIVE)
          circle_world (x, y, radius);
      }

      // show hearts
      if (points[i].is_heart && heart_draw_flag) {
        radius = heart_radius;
        stroke (heart_color);
        noFill();
        if (status == ALIVE)
          circle_world (x, y, radius);
      }
    }
    
    // highlight it, if user has selected it
    if (select_flag) {
      find_bounds();
      stroke(select_color);
      noFill();
      float dx = abs(xmax - xmin);
      float dy = abs(ymax - ymin);
      float mx = 0.5 * (xmax + xmin);
      float my = 0.5 * (ymax + ymin);
      float rad;
      float s = sx / world_width;
      if (dx > dy)
        rad = s * dx + 2;
      else
        rad = s * dy + 2;
      circle_world (mx, my, rad);
    }

  }  // end of draw()

  // calculate forces/accelerations for the point masses
  void calculate_acceleration()
  {
    int i;
    
    // zero out the accelerations and any artificial friction
    for (i = 0; i < pnum; i++) {
      points[i].ax = 0;
      points[i].ay = 0;
      points[i].friction = 0;
    }
    
    // calculate forces due to segments (springs)
    for (i = 0; i < snum; i++) {
      
      segment s = segments[i];
      float k = s.k_spring * spring_k_global;      // spring constant for this segment
      float damp = s.k_damp * spring_damp_global;  // spring damping value for segment
      
      // calculate rest length of spring, which may vary sinusoidally with time
      float rest_length = s.length;
      float amp = s.amp + s.controllers[CONTROL_AMP].value;
      float ph = s.phase + phase;
      float sin_theta = sin(time * s.freq + ph * 2 * PI);
      float cos_theta = cos(time * s.freq + ph * 2 * PI);
      if (s.amp != 0) {
        rest_length += amp * s.length * sin_theta;
      }
      
      point p1 = points[s.i1];
      point p2 = points[s.i2];
      float dx = p1.x - p2.x;
      float dy = p1.y - p2.y;
      float len = sqrt (dx*dx + dy*dy);
      
      // equation of motion for a damped spring
      float dvx = p1.vx - p2.vx;
      float dvy = p1.vy - p2.vy;
      float damping = damp * (dx * dvx + dy * dvy) / len;
      float fx = -(k * (len - rest_length) + damping) * dx / len;
      float fy = -(k * (len - rest_length) + damping) * dy / len;
      
      // add appropriate forces to each point
      p1.ax += fx;
      p1.ay += fy;
      p2.ax -= fx;
      p2.ay -= fy;

      // bias of spring to more one or the other mass more
      float foot_amp = s.foot_amp + s.controllers[CONTROL_FOOT_AMP].value;
      if (cos_theta > 0)
        foot_amp *= -1;
      
      foot_amp += s.controllers[CONTROL_FOOT_SHIFT].value;

      // incorporate bias by modifying the mass' friction coefficients
      
      p1.friction -= foot_amp;
      p2.friction += foot_amp;
    }
    
    // clamp any frictional foot_amp ("sticky feet") to proper range of [0,1]
    for (i = 0; i < pnum; i++) {
      if (points[i].friction < 0) points[i].friction = 0;
      if (points[i].friction > 1) points[i].friction = 1;
    }
    
    // viscous damping
    if (viscous_damping > 0)
      for (i = 0; i < pnum; i++) {
        
        // regular viscous damping
        points[i].ax -= viscous_damping * points[i].vx;
        points[i].ay -= viscous_damping * points[i].vy;
        
        // maybe extra artificial damping due to "sticky feet"

        float sticky = points[i].friction;   
        float k = 10.0;
        
        points[i].ax -= k * sticky * points[i].vx;
        points[i].ay -= k * sticky * points[i].vy;
      }
    
    // convert forces to accelerations
    for (i = 0; i < pnum; i++) {
      points[i].ax /= points[i].mass;
      points[i].ay /= points[i].mass;
    }
    
  }
  
  // return the bounds of a creature (actually store in global variables)
  void find_bounds()
  {
    int i;
    xmin =  1e20;
    xmax = -1e20;
    ymin =  1e20;
    ymax = -1e20;

    for (i = 0; i < pnum; i++) {
      float x = points[i].x;
      float y = points[i].y;
      if (x < xmin) xmin = x;
      if (x > xmax) xmax = x;
      if (y < ymin) ymin = y;
      if (y > ymax) ymax = y;
    }
  }
  
  // take one timestep for the creature
  void one_timestep()
  {
    int i;
    
    // calculate accelerations due to forces on the point-masses
    calculate_acceleration();
    
    // perform modified Euler simulation step
    for (i = 0; i < pnum; i++) {
      
      point p = points[i];
      
      // don't move points with fixed positions
      if (p.fixed_position)
        continue;
      
      p.xold = p.x;
      p.yold = p.y;
      
      float vx_old = p.vx;
      float vy_old = p.vy;
      p.vx = p.vx + dt * p.ax;
      p.vy = p.vy + dt * p.ay;
      p.x = p.x + dt * (p.vx + vx_old) * 0.5;
      p.y = p.y + dt * (p.vy + vy_old) * 0.5;
      
    }
  }
  
}  // end class creature
//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: creatures file I/O

import javax.swing.JFileChooser;

String run_dir = "";

// write descriptions of the creatures to a file
void write_creatures_to_file()
{
  int i,j,k;
  String filename = "creatures.txt";
  
  // see which directory number to write into
  if (run_dir.equals(""))
    find_directory_count();
  
  filename = String.format ("creatures_%07d.txt", counter);
  filename = run_dir + "/" + filename;

  PrintWriter out = createWriter (filename);
  
  out.println ("counter " + counter + " " + time + " " + dt);
  out.println ("world_width " + world_width);
  out.println ("num_groups " + num_groups);
  out.println ("birth_count " + birth_count);
  out.println ("species_count " + species_count);
  out.println ("num_creatures " + creatures.size());
  out.println ("world_seed " + world_seed);
  
  out.println ("clear_creatures");
  
  for (j = 0; j < creatures.size(); j++) {
    creature c = (creature) creatures.get(j);
    write_creature (c, out);
  }
  
  out.flush();
  out.close();
}

// write a single creature to a file
void write_creature(creature c, PrintWriter out)
{
  int i,k;
  
  // in case we have a null creature (can happen after reading in an old species file)
  if (c == null) {
    out.println ("creature_start 0 0");
    out.println ("creature_end");
    return;
  }
  
  out.println ("creature_start " + c.pnum + " " + c.snum);

  out.println ("color " + red(c.col) + " " + green(c.col) + " " + blue(c.col));
  out.println ("phase " + c.phase);
  out.println ("ids " + c.species_id + " " + c.group_id + " " + c.individual_id);
    
  // write out all of the point masses
  for (i = 0; i < c.pnum; i++) {
    point p = c.points[i];
    out.println ("point " + p.x + " " + p.y + " " + p.mass + " " + p.fixed_position + " " + p.is_mouth + " " + p.is_heart);
  }
  
  // write out the segments
  for (i = 0; i < c.snum; i++) {
    segment s = c.segments[i];
    out.print ("segment " + s.i1 + " " + s.i2 + " " + s.length + " " + s.k_spring + " ");
    out.println (s.k_damp + " " + s.amp + " " + s.freq + " " + s.phase + " " + s.foot_amp);
    out.println ("sensor " + s.sensor_cos + " " + s.sensor_sin + " " + s.sensor_dist + 
                 " " + s.sensor_rad + " " + s.sensor_type);
    for (k = 0; k < num_controllers; k++) {
      out.println ("controller " + k + " " + s.controllers[k].type + " " + s.controllers[k].weight +
                   " " + s.controllers[k].segment_num);
    }
  }

  out.println ("creature_end");
}

// read creatures from a file, if necessary using a file chooser
void read_creatures_from_file(boolean use_chooser)
{
  int i;
  String filename = "";
  
  // find name of current directory
  String path = dataPath("");
  path = path.replace("data/", "");  // get rid of ending "data/"
//  println ("using path = " + path);
  
  if (use_chooser) {
    // open up a browser to look for creature file
    noLoop();
    JFileChooser chooser = new JFileChooser(path);
    chooser.setFileFilter(chooser.getAcceptAllFileFilter());
    int returnVal = chooser.showOpenDialog(null);
    if (returnVal == JFileChooser.APPROVE_OPTION) {
      println("Reading creatures from: " + chooser.getSelectedFile().getName());
//    filename = chooser.getSelectedFile().getName();
      filename = chooser.getSelectedFile().getAbsolutePath();
    }
    loop();
  }
  else {
    filename = "creatures.txt";
  }
  
  println ("file selected is: " + filename);
  
  read_creatures(filename);
}

// read creatures from a specified file
void read_creatures(String filename)
{
  int i;
  
  // first, delete all creatures
  delete_all_creatures();

  // set birth count to zero -- old files didn't record this
  birth_count = 0;

  // read all strings from the file
  String lines[] = loadStrings(filename);

//  println("there are " + lines.length + " lines");

  // parse each string
  for (i=0; i < lines.length; i++) {
//    println(lines[i]);
    parse_line (lines[i]);
  }
  
  // make sure there is a birth representative for each group
  for (i = 0; i < creatures.size()-1; i++) {
    creature c = (creature) creatures.get(i);
    group_representative[c.group_id] = c;
  }
  
  // reconstruct species list as best I can
  reconstruct_species();

  println ("read " + creatures.size() + " creatures from the file");
  if (birth_count == 0)
    println ("old file format -- birth count and individual ID's set to zero");
    
  // re-seed the random number generator
  randomSeed(world_seed);
}

// parse a line from a creature description file
void parse_line (String line)
{
  int i;
  creature c = null;
  
  String[] words = split (line, " ");
  String w = words[0];
  
  if (w.equals ("clear_creatures")) {
    // remove all creatures from world
    delete_all_creatures();
  }
  else if (w.equals ("counter")) {
    counter = int(words[1]);
    time = float(words[2]);
//    dt = float(words[3]);
  }
  else if (w.equals ("world_width")) {
    float ww = float(words[1]);
    if (ww != world_width) {
      println();
      println ("Warning!!! New world width = " + ww);
      println();
      world_width = ww;
      world_height = world_width * sy / sx;
      // initialize grid for fast center-of-mass finding
      int nx = 10;
      int ny = 10;
      creature_grid = new search_grid (nx, ny, nx / world_width, ny / world_height);
    }
  }
  else if (w.equals ("num_groups")) {
    num_groups = int(words[1]);
    group_representative = new creature[num_groups];
  }
  else if (w.equals ("creature_id")) {  // old name for species count
    species_count = int(words[1]);
  }
  else if (w.equals ("species_count")) {
    species_count = int(words[1]);
  }
  else if (w.equals ("birth_count")) {
    birth_count = int(words[1]);
  }
  else if (w.equals ("num_creatures")) {
    // don't need this number
  }
  else if (w.equals ("world_seed")) {
    world_seed = int(words[1]);
  }
  else if (w.equals ("creature_start")) {
    // create a new creature
    c = new creature();
    creatures.add(c);
    int a,b;
    a = int(words[1]);
    b = int(words[2]);
//    println ("creature_start: " + a + " " + b);
    c.pnum = 0;
    c.snum = 0;
  }
  else if (w.equals ("color")) {
    // set color of creature
    int r = int(words[1]);
    int g = int(words[2]);
    int b = int(words[3]);
    c = (creature) creatures.get(creatures.size() - 1);
    c.col = color (r,g,b);
  }
  else if (w.equals ("id")) {  // old ID's
    // set color of creature
    int species_id = int(words[1]);
    int group_id = int(words[2]);
    c = (creature) creatures.get(creatures.size() - 1);
    c.species_id = species_id;
    c.group_id = group_id;
    c.individual_id = 0;      // not right, but don't have this info
  }
  else if (w.equals ("ids")) {  // new ID's
    // set color of creature
    int species_id = int(words[1]);
    int group_id = int(words[2]);
    int individual_id = int(words[3]);
    c = (creature) creatures.get(creatures.size() - 1);
    c.species_id = species_id;
    c.group_id = group_id;
    c.individual_id = individual_id;
  }
  else if (w.equals ("phase")) {
    // set color of creature
    float p = float(words[1]);
    c = (creature) creatures.get(creatures.size() - 1);
    c.phase = p;
  }
  else if (w.equals ("point")) {  // create a point mass
    float x = float(words[1]);
    float y = float(words[2]);
    float mass = float(words[3]);
    boolean fixed = boolean(words[4]);
    boolean is_mouth = boolean(words[5]);
    boolean is_heart = boolean(words[6]);
    c = (creature) creatures.get(creatures.size() - 1);
    c.add_point (x, y, fixed);
    c.points[c.pnum-1].is_mouth = is_mouth;
    c.points[c.pnum-1].is_heart = is_heart;
  }
  else if (w.equals ("segment")) {   // create a segment connecting two masses
    int i1 = int(words[1]);
    int i2 = int(words[2]);
    float len = float(words[3]);
    float k_spring = float(words[4]);
    float k_damp = float(words[5]);
    float amp = float(words[6]);
    float freq = float(words[7]);
    float phase = float(words[8]);
    float bias = float(words[9]);
    c = (creature) creatures.get(creatures.size() - 1);
    c.add_segment (i1, i2, len, amp, freq, phase, bias);
  }
  else if (w.equals ("sensor")) {   // set the sensor values for a segment
    float cs = float(words[1]);
    float sn = float(words[2]);
    float dist = float(words[3]);
    float rad = float(words[4]);
    c = (creature) creatures.get(creatures.size() - 1);
    segment s = c.segments[c.snum-1];
    s.sensor_cos = cs;
    s.sensor_sin = sn;
    s.sensor_dist = dist;
    s.sensor_rad = rad;
    if (words.length == 5 || words[5].equals("")) {    // old version, always sensed hearts
//      println ("old sensor type");
      s.sensor_type = SENSOR_HEART;
    }
    else {                                            // new version, might sense heart or mouth
//      println ("new sensor type");
      s.sensor_type = int(words[5]);
    }
  }
  else if (w.equals ("controller")) {   // set a controller's values
    int index = int(words[1]);
    int type = int(words[2]);
    float weight = float(words[3]);
    int segment_num = int(words[4]);
    c = (creature) creatures.get(creatures.size() - 1);
    segment s = c.segments[c.snum-1];
    s.controllers[index].type = type;
    s.controllers[index].weight = weight;
    s.controllers[index].segment_num = segment_num;
  }
  else if (w.equals ("creature_end")) {
    int num = creatures.size();
//    println ("done reading creature " + num);
  }
  else {
    println ("bad line: " + line);
  }
  
}

// look for which of run01, run02, run03... is not yet defined
void find_directory_count()
{
  File dir;
  boolean done = false;
  String file;
  int dir_count = 0;
  
  // find name of current directory
  
  do {
    dir_count++;
    file = String.format ("run%02d", dir_count);
    run_dir = dataPath(file);
    run_dir = run_dir.replace("data/", "");  // get rid of ending "data
//    println ("checking path = " + run_dir);
    dir = new File(dataPath(run_dir));
    if (!dir.exists()) { done = true; }
  } while (!done);
  
  println ("creating directory " + file);
  dir.mkdir();
}

//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: find nearest objects such as point or segment

// find nearest point-mass and the associated creature
int find_near_point(float x, float y) {
    
  int j;

  // find the nearest creature and its nearest point-mass to the mouse position
  float min_len = 1e20;
  int pmin = -1;
    
  creature c = (creature) creatures.get(0);
  for (j = 0; j < c.pnum; j++) {
    float dx = x - c.points[j].x;
    float dy = y - c.points[j].y;
    float len = sqrt (dx*dx + dy*dy);
    if (len < min_len) {
      pmin = j;
      min_len = len;
     }
  }
  
  if (min_len > 0.18)
    return (-1);
  
  return pmin;
}

// find nearest segment to a given position
int find_near_segment(float x, float y) {
    
  int i;

  // find the nearest segment to the mouse position
  float min_len = 1e20;
  int smin = -1;
    
  creature c = (creature) creatures.get(0);
  for (i = 0; i < c.snum; i++) {
    int i1 = c.segments[i].i1;
    int i2 = c.segments[i].i2;
    float len = distance_to_segment (x, y, c.points[i1], c.points[i2]);
    if (len >= 0 && len < min_len) {
      smin = i;
      min_len = len;
     }
  }
  
  if (min_len > 0.2)
    return (-1);
  
  return smin;
}

// find the distance from a given point to a segment
float distance_to_segment (float x, float y, point p1, point p2)
{
  float x1 = p1.x;
  float y1 = p1.y;
  float x2 = p2.x;
  float y2 = p2.y;
  
  // calculate the implicit line equation f(x,y) = ax + by + c
  float a = y2 - y1;
  float b = x1 - x2;
  float c = y1 * x2 - x1 * y2;
  float len = sqrt (a*a + b*b);
  
  if (len > 0) {
    a /= len;
    b /= len;
    c /= len;
  }
  
  // t says how far to the line
  float t = a * x + b * y + c;
  
  // project point onto line segment
  float xx = x - a * t;
  float yy = y - b * t;
  
  // s in the range [0,1] says that the projected point is between the endpoints
  float s;
  if (abs(a) < abs(b)) {
    s = (xx - x1) / (x2 - x1);
  }
  else {
    s = (yy - y1) / (y2 - y1);
  }
  
//  println ("dist = " + abs(t));
//  println ("xx yy = " + xx + " " + yy);
//  println ("s = " + s);
  
  // return -1 if projected point isn't even between the endpoints
  if (s < 0 || s > 1)
    return (-1);
  else
    return (abs(t));
}

//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: check for intersection between path of a mouth and segments

ArrayList cross_list = null;
ArrayList birth_queue = null;
ArrayList kill_list = new ArrayList();

// creature status (alive or dead)
final int ALIVE = 1;
final int DEAD  = 2;

// how many frames to show kill
int show_kill_frames = 10;

// class that records a crossing event (mouth passes over segment)
class cross_event {
  creature c1;  // creature whose mouth crossed anther's segment
  creature c2;  // creature whose segment was crossed
  float time;   // when crossing occured in current timestep
  float x,y;    // location of crossing
  int count;    // counts down to zero, at which point event is deleted
  
  cross_event (creature c, creature cc, float t, float xx, float yy) {
    c1 = c;
    c2 = cc;
    time = t;
    x = xx;
    y = yy;
    count = show_kill_frames;
  }
}

// Check to see if any creatures eat other creatures
void check_eating()
{
  int i,j,k;
  
  // we start with an empty list of crossing events
  cross_list = new ArrayList();
  
  // place creatures in 2D grid based on bounds
  creature_grid.place_creatures_from_bounds();
  
  // examine each creature to see if it eats another ("crossing events")
  // (fast method, using search grid)
  for (i = 0; i < creatures.size(); i++) {
    creature c1 = (creature) creatures.get(i);
    
    // find mouths of creature c1
    for (j = 0; j < c1.pnum; j++)
      if (c1.points[j].is_mouth) {
        point mouth = c1.points[j];
        
        // find range of motion of the mouth
        float xmin,xmax,ymin,ymax;
        if (mouth.x < mouth.xold) {
          xmin = mouth.x;
          xmax = mouth.xold;
        }
        else {
          xmin = mouth.xold;
          xmax = mouth.x;
        }
        if (mouth.y < mouth.yold) {
          ymin = mouth.y;
          ymax = mouth.yold;
        }
        else {
          ymin = mouth.yold;
          ymax = mouth.y;
        }
        
        // widen this range by the radius of the heart
        xmin -= heart_radius;
        xmax += heart_radius;
        ymin -= heart_radius;
        ymax += heart_radius;
        
//println();
//println ("creature number " + i);
        
        // create list of nearby creatures
        creature_grid.make_near_list (xmin, xmax, ymin, ymax);
        
//println ("num_near = " + num_near);
//println();

        // examine each nearby creature to see if mouth eats it
        for (k = 0; k < num_near; k++) {
          creature c2 = near_creatures[k];
          if (c1 == c2)
            continue;
          //cross_event eats12 = creature_mouth_eats_other (c1, c2, mouth);
          cross_event eats12 = creature_mouth_eats_heart (c1, c2, mouth);
          if (eats12 != null) {
            add_cross_event (eats12);
//            println ("cross: " + c1.id + " " +  c2.id);
          }
        }
      }
  }
    
  // nothing more to do here if there were no crossing events
  if (cross_list.size() == 0)
    return;
  
  // mark all creatures as being alive
  for (i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    c.status = ALIVE;
  }
  
  // process the list of cross events
  // SHOULD SORT THE LIST BY TIME !!!!
  
  birth_queue = new ArrayList();  // initialize the birth queue as empty
  
  for (i = cross_list.size() - 1; i >= 0; i--) {
    cross_event e = (cross_event) cross_list.get(i);
    cross_list.remove(i);
    // process the eating event
    if (e.c1.status == ALIVE && e.c2.status == ALIVE) {
      
      // maybe add noise to the competition by sometimes swapping winner & loser
      if (random(1) < competition_noise && e.c2.species_id != 0) {
        creature temp_creature = e.c1;
        e.c1 = e.c2;
        e.c2 = temp_creature;
      }
      
      e.c2.status = DEAD;          // the second creature dies
      increment_kill_count(e.c1);  // record the kill of the first creature
      kill_list.add(e);            // add this event to the list of kills
        
      // note that c1 is now the birth representative for its group
      group_representative[e.c1.group_id] = e.c1;
      
      // add a creature to the birth queue
      if (e.c1.group_id == e.c2.group_id)
        birth_queue.add (e.c1);                    // add c1 to birth queue if c1 and c2 are in same group
      else
        birth_queue.add (group_representative[e.c2.group_id]);   // add representative of c2's group if not from same group
    }
  }
  
  // Remove the dead creatures from the world.
  // Note that we count down from the end of the list to do this.
  for (i = creatures.size() - 1; i >= 0; i--) {
    creature c = (creature) creatures.get(i);
    if (c.status == DEAD) {
      decrement_species_count(c);    // decrement the count of individuals of a species
      creatures.remove(i);
//      println("death");
    }
  }
  
  
  // try to give birth to the creatures on the birth queue
  for (i = birth_queue.size()-1; i >= 0; i--) {
    creature c = (creature) birth_queue.get(i);
    
    // attempt to birth a new creature that is a clone of the parent c,
    // possibly with mutation
    boolean birth_successful = birth (c, 40, true);
    
    // remove this creature from the birth queue if we had a successful birth
    if (birth_successful) {
      birth_queue.remove(i);
//      println ("birth");
    }
  }
  
}

// add a crossing event to the list of such events
void add_cross_event (cross_event event)
{
  cross_list.add(event);
}

// see if creature 1's mouth eats creature 2's heart
cross_event creature_mouth_eats_heart (creature c1, creature c2, point mouth)
{
  int j;
  float tmin = 1e20;
  cross_event cross = null;
  
  // see if mouth of creature 1 crosses the heart of creature 2
  for (j = 0; j < c2.pnum; j++) {
    point p = c2.points[j];
    if (!p.is_heart) {
      continue;
    }
    float t = mouth_heart_intersect (mouth, p);
    if (t != -1 && t < tmin) {
      float x = mouth.xold + t * (mouth.x - mouth.xold);
      float y = mouth.yold + t * (mouth.y - mouth.yold);
      cross = new cross_event (c1, c2, t, x, y);
      tmin = t;
    }
  }
  
  return cross;
}

// See if the path of a mouth (m) crosses a heart (h).
// returns "time" of crossing, or -1 if no crossing
float mouth_heart_intersect (point m, point h)
{
  float t;
  float rad_sq = heart_radius * heart_radius;  // shorthand for heart radius squared

  // we want our heart (hx,hy) to vary with t:
  // hx = hxo + t * hxd
  // hy = hyo + t * hyd

  float hxo = h.xold;
  float hyo = h.yold;

  float hxd = h.x - h.xold;
  float hyd = h.y - h.yold;

//  println ("hxo hyo hxd hyd: " + hxo + " " + hyo + " " + hxd + " " + hyd);

  // our mouth point m can also vary with time, m = mo + t * md

  float mxo = m.xold;
  float myo = m.yold;
  float mxd = m.x - m.xold;
  float myd = m.y - m.yold;

  // re-position the mouth if it is on the other side of the grid from the heart

  float ww = world_width;
  float hh = world_height;
  float w2 = 0.5 * world_width;
  float h2 = 0.5 * world_height;
  
//  println ("mxo myo: " + mxo + " " + myo);
  
  if (abs(mxo - hxo) > w2) {
    if (mxo < w2)
      mxo += ww;
    else
      mxo -= ww;
  }
  if (abs(myo - hyo) > h2) {
    if (myo < h2)
      myo += hh;
    else
      myo -= hh;
  }
  
//  println ("mxo myo: " + mxo + " " + myo);

  // Since we only care about the relative position of m with respect
  // to the heart, we can subtract the motion of the heart from the
  // path of m and from the heart itself.

  mxd -= hxd;
  myd -= hyd;

  // We can also subtract the initial position of the heart from m,
  // effectively placing the heart at (0,0).

  mxo -= hxo;
  myo -= hyo;

  // From now on, h = (0, 0) since we have effectively moved it to the origin
  // and removed all the motion from the heart.
  
  // See whether the mouth is inside the heart
  
  if (mxo * mxo + myo * myo < rad_sq)
    return (0.0);

  // See whether the path of the mouth passes thru the circle of
  // the heart (with center = (0,0) and heart_radius).  Do this
  // by solving the appropriate quadratic equation.

  float a = mxd * mxd + myd * myd;
  float b = 2 * (mxd * mxo + myd * myo);
  float c = mxo * mxo + myo * myo - rad_sq;

  // imaginary roots means no intersection
  float d = b*b - 4*a*c;
  if (d < 0)
    return (-1);

  // no roots if a = 0
  if (abs(a) < 1e-14)
    return (-1);

  // find values of roots
  float t1 = (-b + sqrt(d)) / (2 * a);
  float t2 = (-b - sqrt(d)) / (2 * a);

  // no intersection if roots aren't in the range [0,1]
  if ((t1 < 0 || t1 > 1) && (t2 < 0 || t2 > 1))
    return (-1);

  // return the smaller root as the time of first intersection
  if (t1 < t2)
    return (t1);
  else
    return (t2);
}

// draw all of the creature kills
void draw_kills()
{
  int i;
  int duration = 5;   // duration of showing the kill
  
  for (i = kill_list.size() - 1; i >= 0; i--) {
    cross_event e = (cross_event) kill_list.get(i);
    if (e.count <= 0) {
      kill_list.remove(i);
    }
  }

  // draw a filled circle to highlight the kill
  for (i = kill_list.size() - 1; i >= 0; i--) {
    
    cross_event e = (cross_event) kill_list.get(i);
    
    // determine how far into kill drawing we are
    float t = e.count / (float) show_kill_frames;
        
    // fade color of creature to white
    float s = (1-t);
    color ctemp = e.c2.col;
    int r = (int) red(e.c2.col);
    int g = (int) green(e.c2.col);
    int b = (int) blue(e.c2.col);
    r = (int) (r + s * (255 - r));
    g = (int) (g + s * (255 - g));
    b = (int) (b + s * (255 - b));
    e.c2.col = color (r, g, b);
    
    // draw creature and restore its original color
    e.c2.draw();
    e.c2.col = ctemp;
     
    // draw shrinking circle at kill location
    stroke (crossing_color);
    fill (crossing_color);
    circle_world (e.x, e.y, t);
    
    // decrement the kill draw count
    e.count--;
  }

}

//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: creature mutations

// segment size bounds

float min_seg_length = 0.5;
float max_seg_length = 1.5;

// all mutation probabilities are normalized within each category so they sum to one

// broad mutation probabilities

float p_mutate_topology = 1;        // number and configuration of segments
float p_mutate_behavior = 1;        // sensors and controllers
float p_mutate_segment_props = 1;   // segment phase, amplitude, length, etc.

// specific topology mutation probabilities

float p_delete_segment = 1;
float p_add_dangling_segment = 1;
float p_connect_ends = 1;
float p_fuse_ends = 1;
float p_add_triangle = 1;

// specific behavior mutation probabilities

float p_replicate_controllers = 5;
float p_alter_phase = 5;
float p_sensor_angle = 1;
float p_sensor_radius = 1;
float p_sensor_distance = 1;
float p_sensor_type = 1;
float p_control_amp = 1;
float p_contrl_foot_amp = 1;
float p_control_foot_shift = 1;
float p_mouth_heart = 1;

// specific segment change mutation probabilities

float p_alter_segment_length = 1;
float p_alter_segment_amp = 1;
float p_alter_segment_freq = 1;
float p_alter_foot_amp = 1;

int[] point_valence = new int[200];   // valences of the point masses for a creature

// mutate a given creature
void mutate_creature(creature c)
{
  int i,j;
  
  println("");
  
  // now mutate the creature once
  mutate_creature_once(c);
  
  // maybe mutate it more
  int mutate_count = 1;
  while (random(1) < mutate_again) {
    mutate_creature_once(c);
    mutate_count++;
  }

  // make sure all points are mouths (why?)
//  all_mouths_and_hearts(c);
 
  // pick new color for this creature
  
  int lo_min = 20;
  int hi_max = 255;
  
  if (num_groups == 1) {  // pick entirely random color if there is just one group
    int red = (int) random (lo_min, hi_max);
    int grn = (int) random (lo_min, hi_max);
    int blu = (int) random (lo_min, hi_max);
    c.col = color (red, grn, blu);
  }
  else {
    // pick a new random color for this creature based on group id
    pick_color_from_group (c, c.group_id, true);
  }
  
}

// list of probabilities to choose from
float[] prob_values = new float[20];
float[] prob_sums = new float[20];
int prob_count = 0;

// select from probability list, return an integer that specifies the selection
int pick_from_probabilities()
{
  int i;
  
  // signal error if there are no given probabilities
  if (prob_count == 0) {
    println ("no probabilities given");
    exit();
  }
  
  // turn probabilitis into partial sums
  float sum = 0;
  for (i = 0; i < prob_count; i++) {
    sum += prob_values[i];
    prob_sums[i] = sum;
  }
  
  // check for zero sum
  if (sum == 0) {
    println ("probabilities sum to zero");
    exit();
  }
  
  // re-normalize based on sum
  for (i = 0; i < prob_count; i++) {
    prob_sums[i] /= sum;
  }
  
  // select randomly from among choices, based on probabilities
  float r = random(1);
  for (i = 0; i < prob_count; i++)
    if (r < prob_sums[i])
      return (i);

  // should never get here
  println ("pick_from_probabilities: random number out-of-bounds");
  return (0);
}

// mutate a creature once
void mutate_creature_once(creature c)
{
  // set the probabilities of each major type of mutation
  prob_values[0] = p_mutate_topology;
  prob_values[1] = p_mutate_behavior;
  prob_values[2] = p_mutate_segment_props;
  prob_count = 3;
  
  // select one of the mutation types at random
  switch (pick_from_probabilities()) {
    case 0:
      println ("mutating topology");
      mutate_topology(c);
      break;
    case 1:
      println ("mutating behavior");
      mutate_behavior(c);
      break;
    case 2:
      println ("mutating a segment");
      mutate_one_segment(c);
      break;
    default:
      println ("bad case in mutate_creature_once\n");
      exit();
  }
}

// mutate the topology of a given creature
void mutate_topology(creature c)
{
  // set the probabilities of each type of mutation
  prob_values[0] = p_delete_segment;
  prob_values[1] = p_add_dangling_segment;
  prob_values[2] = p_connect_ends;
  prob_values[3] = p_fuse_ends;
  prob_values[4] = p_add_triangle;
  prob_count = 5;

  boolean successful = false;

  do {
    switch (pick_from_probabilities()) {
      case 0:
        successful = delete_random_segment(c);
        break;
      case 1:
        successful = add_dangling_segment(c);
        break;
      case 2:
        successful = connect_dangling_ends(c);
        break;
      case 3:
        successful = fuse_dangling_ends(c);
        break;
      case 4:
        successful = add_triangle(c);
        break;
      default:
        println ("bad case in mutate_topology\n");
        exit();
    }
  } while (!successful);

  // see that it has the right number of mouths and hearts
  fix_mouth_count(c);
  fix_heart_count(c);
}

// mutate the property of one of a creature's segments
void mutate_one_segment(creature c)
{
  // randomly pick a segment to alter
  int index = (int) random(c.snum);
  segment s = c.segments[index];

  // set the probabilities of each type of mutation
  prob_values[0] = p_alter_segment_length;
  prob_values[1] = p_alter_segment_amp;
  prob_values[2] = p_alter_segment_freq;
  prob_values[3] = p_alter_foot_amp;
  prob_count = 4;

  boolean successful = false;

  switch (pick_from_probabilities()) {
    case 0:
      s.length = random (min_seg_length, max_seg_length);
      break;
    case 1:
      s.amp = random (0, 0.2);
      break;
    case 2:
      s.freq = random (0, default_freq * 2);
      break;
    case 3:
      s.foot_amp = random (0, 1);
      break;
    default:
      println ("bad case in mutate_one_segment\n");
      exit();
  }
}

// mutate the behavior of a creature at a single segment
void mutate_behavior(creature c)
{
  // randomly pick a segment to alter
  int index = (int) random(c.snum);
  segment s = c.segments[index];
  
  // set the probabilities of each type of mutation
  prob_values[0] = p_replicate_controllers;
  prob_values[1] = p_alter_phase;
  prob_values[2] = p_sensor_angle;
  prob_values[3] = p_sensor_radius;
  prob_values[4] = p_sensor_distance;
  prob_values[5] = p_sensor_type;
  prob_values[6] = p_control_amp;
  prob_values[7] = p_contrl_foot_amp;
  prob_values[8] = p_control_foot_shift;
  prob_values[9] = p_mouth_heart;
  prob_count = 10;

  boolean successful = false;

  switch (pick_from_probabilities()) {
    case 0:
      replicate_controllers (s, c);
      break;
    case 1:
      mutate_phase (s, c);
      break;
    case 2:
      float angle = random (0, 2 * PI);
      s.sensor_cos = cos (angle);
      s.sensor_sin = sin (angle);    
      break;
    case 3:
      s.sensor_rad = random (0.3, 4.0);
      break;
    case 4:
      s.sensor_dist = random (0.5, 6.0);  
      break;
    case 5:
      if (s.sensor_type == SENSOR_HEART)
        s.sensor_type = SENSOR_MOUTH;
      else
        s.sensor_type = SENSOR_HEART;
      break;
    case 6:
      s.controllers[CONTROL_AMP].type = CONTROLLER_SENSOR;
      s.controllers[CONTROL_AMP].weight = random(-0.2,0.2);    
      break;
    case 7:
      s.controllers[CONTROL_FOOT_AMP].type = CONTROLLER_SENSOR;
      s.controllers[CONTROL_FOOT_AMP].weight = random(-1,1);    
      break;
    case 8:
      s.controllers[CONTROL_FOOT_SHIFT].type = CONTROLLER_SENSOR;
      s.controllers[CONTROL_FOOT_SHIFT].weight = random(-1,1);    
      break;
    case 9:
      mutate_mouth_heart (c); 
      break;
    default:
      println ("bad case in mutate_behavior\n");
      exit();
  }
}

// copy the controllers of a segment to another segment
void replicate_controllers(segment s, creature c)
{
  int i;
  
  // bail if the creature only has one segment
  if (c.snum == 1)
    return;
    
  // pick random segment other than s
  segment s2;
  do {
    int index = (int) random (c.snum);
    s2 = c.segments[index];
  } while (s2 == s);
  
  // copy all of the controllers from s2 to s
  for (i = 0; i < num_controllers; i++) {
    s.controllers[i].type = s2.controllers[i].type;
    s.controllers[i].weight = s2.controllers[i].weight;
    s.controllers[i].segment_num = s2.controllers[i].segment_num;
  }
}

// mutate the phase of a given segment
void mutate_phase(segment s, creature c)
{
  float p = 0;
  
  // keep picking random phases until we've got a new one
  
  do {
  
    int r = (int) random(8);

    switch (r) {
      case 0:
      case 1:
        p = 0;      // more likely
        break;
      case 2:
      case 3:
        p = 0.5;    // more likely
        break;
      case 4:
        p = 0.3333333;
        break;
      case 5:
        p = 0.6666667;
        break;
      case 6:
        p = 0.25;
        break;
      case 7:
        p = 0.75;
        break;
      default:
        println ("bad case in mutate_phase: " + p);
        break;
    }
  
  } while (p == s.phase);
  
  // when we get here, we've got a new phase
  s.phase = p;
}

// mutate topology of the creature by adding a dangling segment
// Returns "false" if unable to make a change.
boolean add_dangling_segment(creature c)
{
  // check whether adding a segment will give too many segments
  if (c.snum + 1 > max_segments)
    return false;  

  // pick random segment to replicate
  int s_index = (int) random(c.snum);
  segment s = c.segments[s_index];
  
  // pick random point at which to add the segment
  int p_index = (int) random(c.pnum);
  point p = c.points[p_index];
  
  float len = s.length;
  float theta = random (0, 2 * PI);
  float x = p.x + len * cos(theta);
  float y = p.y + len * sin(theta);
  c.add_point (x, y, false);
  int p_index2 = c.pnum-1;

  if (random(1) < 0.5)
    c.add_segment (p_index, p_index2, s.length, s.amp, s.freq, s.phase, s.foot_amp);
  else
    c.add_segment (p_index2, p_index, s.length, s.amp, s.freq, s.phase, s.foot_amp);
  
  segment snew = c.segments[c.snum-1];
  s.copy_attributes (snew);
  
  return true;
}

// return how many dangling ends this creature has
int dangling_end_count(creature c)
{
  int i;
  
  // find the point valences
  find_point_valences(c);
  
  // count how many ends are dangling
  int dangle_count = 0;
  for (i = 0; i < c.pnum; i++)
    if (point_valence[i] == 1)
      dangle_count++;

  return (dangle_count);
}

// connect two dangling ends of a creature (if possible)
// Returns "false" if unable to make a change.
boolean connect_dangling_ends(creature c)
{
  int i;

  // check whether adding a segment will give too many segments
  if (c.snum + 1 > max_segments)
    return false;  
    
  // find the point valences
  find_point_valences(c);
  
  // if there are not enough dangling ends, bail
  if (dangling_end_count(c) < 2) {
//    println ("error: too few dangling ends in connect_dangling_ends()");
    return false;
  }
    
  int index1 = -1;
  int index2 = -1;
  point p1 = null;
  point p2 = null;

  // pick one point with a dangling end
  while (p1 == null) {
    index1 = (int) random (c.pnum);
    if (point_valence[index1] == 1)
      p1 = c.points[index1];
  }
  
  // pick a different point with a dangling end
  while (p2 == null) {
    index2 = (int) random (c.pnum);
    if (index1 != index2 && point_valence[index2] == 1)
      p2 = c.points[index2];
  }
  
  // see if these points are already connected
  // (this could only happen if this is a 1-segment creature)
  if (already_connected (p1, p2, c)) {
//    println ("error: two points already connected in connect_dangling_ends()");
    return false;
  }
  
  // pick random segment to replicate
  int s_index = (int) random(c.snum);
  segment s = c.segments[s_index];

  if (random(1) < 0.5)
    c.add_segment (index1, index2, s.length, s.amp, s.freq, s.phase, s.foot_amp);
  else
    c.add_segment (index2, index1, s.length, s.amp, s.freq, s.phase, s.foot_amp);
  
  segment snew = c.segments[c.snum-1];
  s.copy_attributes (snew);
  
  // maybe set this segment to be unmoving (zero amplitude)
  if (random(1) < 0.5) {
    snew.amp = 0;
  }
  
  // add a little randomness to position of one of the points (in case they are coincident)
  float epsilon = 0.1;
  p1.x += random(epsilon) - epsilon/2;
  p1.y += random(epsilon) - epsilon/2;
  
//  println ("successfully performed connect_dangling_ends()");

  // signal a successful change
  return true;
}

// Fuse two dangling ends of a creature (if possible) by making their endpoints the same.
// Returns "false" if unable to make a change.
boolean fuse_dangling_ends(creature c)
{
  int i;
  
  // find the point valences
  find_point_valences(c);
  
  // if there are not enough dangling ends, bail
  if (dangling_end_count(c) < 2) {
//    println ("error: too few dangling ends in fuse_dangling_ends()");
    return false;
  }
  
  int index1 = -1;
  int index2 = -1;
  point p1 = null;
  point p2 = null;

  // pick one point with a dangling end
  while (p1 == null) {
    index1 = (int) random (c.pnum);
    if (point_valence[index1] == 1)
      p1 = c.points[index1];
  }
  
  // pick a different point with a dangling end
  while (p2 == null) {
    index2 = (int) random (c.pnum);
    if (index1 != index2 && point_valence[index2] == 1)
      p2 = c.points[index2];
  }
  
  // see if these points are already connected
  // (this could only happen if this is a 1-segment creature)
  if (already_connected (p1, p2, c)) {
//    println ("error: two points already connected in connect_dangling_ends()");
    return false;
  }
  
  // find where these dangling ends are connected
  int connect1 = -1;
  int connect2 = -1;
  for (i = 0; i < c.snum; i++) {
    segment s = c.segments[i];
    if (s.i1 == index1)
      connect1 = s.i2;
    if (s.i2 == index1)
      connect1 = s.i1;
    if (s.i1 == index2)
      connect2 = s.i2;
    if (s.i2 == index2)
      connect2 = s.i1;
  }
  
  // error check
  if (connect1 == -1 || connect2 == -1) {
//    println ("error: can't find connections in fuse_dangling_ends()");
    return false;
  }
  
  // dont' perform this operation if the two segments connect to the same point
  if (connect1 == connect2) {
//    println ("oops in fuse_dangling_ends()");
    return false;
  }
  
  // go thru all segments and change all references of index2 to index1
  for (i = 0; i < c.snum; i++) {
    if (c.segments[i].i1 == index2)
      c.segments[i].i1 = index1;
    else if (c.segments[i].i2 == index2)
      c.segments[i].i2 = index1;
  }
  
  // get rid of any points that are no longer used
  delete_unused_points(c);

  // signal a successful change
  return true;
}

// add a triangle to a creature
// Returns "false" if unable to make a change.
boolean add_triangle(creature c)
{
  int i;
  int index;
  int tries = 0;
  boolean found_segment = false;
  segment s;
  
  // check whether adding two segments will give too many segments
  if (c.snum + 2 > max_segments)
    return false;
  
  // find the point valences
  find_point_valences(c);
  
  // try to find a segment with at least one point with valence less than 3
  do {
    // randomly pick a segment to alter
    index = (int) random(c.snum);
    s = c.segments[index];
    if (point_valence[s.i1] < 3 || point_valence[s.i2] < 3)
      found_segment = true;
    tries++;
  } while (tries < 20 && !found_segment);

  // bail if we didn't find good segment
  if (!found_segment) {
//    println ("error: can't find good segment in add_triangle()");
    return false;
  }
  
  // find center-of-mass of points attached to the selected segment
  float cx = 0;
  float cy = 0;
  int count = 0;
  
  for (i = 0; i < c.snum; i++) {
    segment s2 = c.segments[i];
    // only examine segments other than the selected one
    if (s == s2)
      continue;
    // check first point of s2 to make sure it's not part of s,
    // and if not, add this point's contribution to the center-of-mass
    if (s2.i1 != s.i1 && s2.i1 != s.i2) {
      cx += c.points[s2.i1].x;
      cy += c.points[s2.i1].y;
      count++;
    }
    // check second point of s2 to make sure it's not part of s
    if (s2.i2 != s.i1 && s2.i2 != s.i2) {
      cx += c.points[s2.i2].x;
      cy += c.points[s2.i2].y;
      count++;
    }
  }
  
  // calculate center-of-mass
  if (count > 0) {
    cx = cx / count;
    cy = cy / count;
  }
  
  point p1 = c.points[s.i1];
  point p2 = c.points[s.i2];
  
  // get length of segment
  float dx = p1.x - p2.x;
  float dy = p1.y - p2.y;
  float s_len = sqrt(dx*dx + dy*dy);
  
  // if this length is outside allowable range, clamp it
  if (s_len > max_seg_length) {
    s_len = max_seg_length;
  }
  else if (s_len < min_seg_length) {
    s_len = min_seg_length;
  }
  
  // choose length for new segment (but don't make too long or short)
  float new_length;
  if (random(1) < 0.5 || s_len > max_seg_length || s_len < min_seg_length) {
    new_length = random(min_seg_length, max_seg_length);
  }
  else {
    new_length = s_len;
  }
  
  // figure out the perpendicular length of new vertex from the segment midpoint
  float radical = new_length*new_length - 0.25*s_len*s_len;
  if (radical < 0) {
    new_length = s_len;
    radical = new_length*new_length - 0.25*s_len*s_len;
  }
  float perp_len = sqrt (radical);
  float mx = 0.5 * (p1.x + p2.x);
  float my = 0.5 * (p1.y + p2.y);
  dx /= s_len;
  dy /= s_len;
  
  // calculate two new possible point positions for third vertex of triangle
  float x1 = mx - perp_len * dy;
  float y1 = my + perp_len * dx;
  float x2 = mx + perp_len * dy;
  float y2 = my - perp_len * dx;
  
  // case where there are no other attached points
  if (count == 0) {
    cx = mx;
    cy = my;
  }
  
  // see which new point is farthest from the center-of-mass of other stuff
  dx = x1 - cx;
  dy = y1 - cy;
  float dist1 = dx*dx + dy*dy;
  dx = x2 - cx;
  dy = y2 - cy;
  float dist2 = dx*dx + dy*dy;
  
  // pick the farthest point from the center-of-mass and create new point here
  if (dist1 > dist2)
    c.add_point (x1, y1, false);
  else
    c.add_point (x2, y2, false);

  int p_index = c.pnum-1;
  
  // create two new segments that make up the triangle
  if (random(1) < 0.5) {
    c.add_segment (p_index, s.i1, new_length, s.amp, s.freq, s.phase, s.foot_amp);
    c.add_segment (p_index, s.i2, new_length, s.amp, s.freq, s.phase, s.foot_amp);
  }
  else {
    c.add_segment (s.i1, p_index, new_length, s.amp, s.freq, s.phase, s.foot_amp);
    c.add_segment (s.i2, p_index, new_length, s.amp, s.freq, s.phase, s.foot_amp);
  }
  
  // copy the attributes of some segment in the creature
  int rand_index = (int) random(c.snum-2.0);
  segment seg_rand = c.segments[rand_index];
  
  segment snew1,snew2;
  snew1 = c.segments[c.snum-2];
  seg_rand.copy_attributes (snew1);  
  snew2 = c.segments[c.snum-1];
  seg_rand.copy_attributes (snew2);
  
  // try to make sensor placement symmetric
  if (random(1) < 0.5) {
    snew1.sensor_sin *= -1;
  }
  else {
    snew2.sensor_sin *= -1;
  }
  
  // maybe cause the old segment to be still
  if (random(1) < 0.75) {
    s.foot_amp = 0;
  }

  return true;
}  
  
// delete a random segment from the creature
boolean delete_random_segment(creature c)
{
  int i;
  boolean[] point_visited = new boolean[c.pnum];
  
  // don't try to delete a segment if there is just one
  if (c.snum == 1)
    return (false);
  
  // don't try to delete a segment if there are only three
  // segments left (presumably in triangle configuration)
  if (c.snum < 4)
    return (false);
  
  // select a segment to delete
//  int del_index = (int) random(c.snum);
  int del_index = (int) random(3, c.snum);  // don't delete any of the first three segments
  segment s = c.segments[del_index];
  
  // now we need to see whether removing this segment will
  // cause the creature to be disconnected (which is not allowed)
  
  // mark all points as being unvisited so far
  for (i = 0; i < c.pnum; i++)
    point_visited[i] = false;
  
  // Find one point that isn't attached to the segment to delete,
  // and mark it as being visited.  One of the first three points
  // has to be okay for this.
  
  if (s.i1 != 0 && s.i2 != 0)
    point_visited[0] = true;
  else if (s.i1 != 1 && s.i2 != 1)
    point_visited[1] = true;
  else
    point_visited[2] = true;
  
  // repeatedly go thru segments and visit neighbors of visited points
  boolean was_changed;
  do {
    was_changed = false;
    for (i = 0; i < c.snum; i++) {
      segment s2 = c.segments[i];
      // skip the segment we are planning to delete
      if (s2 == s)
        continue;
      int i1 = s2.i1;
      int i2 = s2.i2;
      if (point_visited[i1] && !point_visited[i2]) {
        point_visited[i2] = true;
        was_changed = true;
      }
      else if (point_visited[i2] && !point_visited[i1]) {
        point_visited[i1] = true;
        was_changed = true;
      }
    }
  } while (was_changed);
  
  // find the point valences
  find_point_valences(c);
  
  // see if all the points with valence >1 were visited
  for (i = 0; i < c.pnum; i++)
    if (point_visited[i] == false && point_valence[i] > 1)
      return (false);
  
  // if we get here, deleting "s" won't make creature disconnected,
  // so delete it by shifting all the segments down
  for (i = del_index; i < c.snum-1; i++)
    c.segments[i] = c.segments[i+1];
  
  // decrease the segment count
  c.snum--;
  
  // get rid of any points that are no longer used
  delete_unused_points(c);
  
  // signal that we successfully deleted a segment
  return (true);
}

// delete unused points
void delete_unused_points(creature c)
{
  int i;
  int[] new_nums = new int[c.pnum];
  
  // find new point valences
  find_point_valences(c);
  
  // come up with new indices for points, omitting unused ones
  int count = 0;
  for (i = 0; i < c.pnum; i++)
    if (point_valence[i] > 0)
      new_nums[i] = count++;
    else
      new_nums[i] = -1;
  
  // copy only the used points into the point list
  for (int index = 0; index < c.pnum; index++)
    if (new_nums[index] != -1)
      c.points[new_nums[index]] = c.points[index];

  // adjust point count
  c.pnum = count;
  
  // go thru segments and change the endpoint indices
  for (i = 0; i < c.snum; i++) {
    segment s = c.segments[i];
    s.i1 = new_nums[s.i1];
    s.i2 = new_nums[s.i2];
  }
}

// find valence of the point masses (how many segments each is connected to)
void find_point_valences(creature c)
{
  int i;
  
  // zero out the valence counts
  for (i = 0; i < c.pnum; i++)
    point_valence[i] = 0;
  
  // go thru each segment and increment the point-mass counts
  for (i = 0; i < c.snum; i++) {
    segment s = c.segments[i];
    point_valence[s.i1]++;
    point_valence[s.i2]++;
  }
}

// see if two point masses of a creature are already connected by a segment
boolean already_connected(point p1, point p2, creature c)
{
  int i;
  
  // check each segment for connection between these points
  for (i = 0; i < c.snum; i++) {
    segment s = c.segments[i];
    point pp1 = c.points[s.i1];
    point pp2 = c.points[s.i2];
    // see if we matched both points (in either order)
    if ((p1 == pp1 && p2 == pp2) || (p1 == pp2 && p2 == pp1))
      return true;
  }
  
  // if we get here, the points are not connected
  return (false);
}

// make sure the creature has the right number of hearts
void fix_heart_count(creature c)
{
  int i;
  int index;
  
  int hearts_allowed = 1;
 
  // count number of hearts
  int heart_count = 0;
  for (i = 0; i < c.pnum; i++)
    if (c.points[i].is_heart)
      heart_count++;
      
  // if there are too many hearts, delete until we're done
  while (heart_count > hearts_allowed) {
    index = (int) random(c.pnum);
    if (c.points[index].is_heart) {
      c.points[index].is_heart = false;
      heart_count--;
    }
  }
  
  // if there are not enough hearts, add some
  while (heart_count < hearts_allowed) {
    index = (int) random(c.pnum);
    if (c.points[index].is_heart == false) {
      c.points[index].is_heart = true;
      heart_count++;
    }
  }
}

// make sure the creature has the right number of mouths
void fix_mouth_count(creature c)
{
  int i;
  int index;
  
//  int mouths_allowed = (c.pnum + 1) / 2;
  int mouths_allowed = 1;
  
  // count number of mouths
  int mouth_count = 0;
  for (i = 0; i < c.pnum; i++)
    if (c.points[i].is_mouth)
      mouth_count++;
      
  // if there are too many mouths, delete until we're done
  while (mouth_count > mouths_allowed) {
    index = (int) random(c.pnum);
    if (c.points[index].is_mouth) {
      c.points[index].is_mouth = false;
      mouth_count--;
    }
  }
  
  // if there are not enough mouths, add some
  while (mouth_count < mouths_allowed) {
    index = (int) random(c.pnum);
    if (c.points[index].is_mouth == false) {
      c.points[index].is_mouth = true;
      mouth_count++;
    }
  }
}

// change the position of the mouth
void mutate_mouth(creature c)
{
  int i;
  int old_mouth = 0;
  
  // find a mouth
  for (i = 0; i < c.pnum; i++)
    if (c.points[i].is_mouth) {
      old_mouth = i;
      break;
    }

  // pick a new mouth position that is different than the old one
  do {
    i = (int) random (0, c.pnum);
  } while (i == old_mouth);
  
  c.points[old_mouth].is_mouth = false;
  c.points[i].is_mouth = true;
}

// change the position of the heart
void mutate_heart(creature c)
{
  int i;
  int old_heart = 0;
  
  // find a heart
  for (i = 0; i < c.pnum; i++)
    if (c.points[i].is_heart) {
      old_heart = i;
      break;
    }

  // pick a new heart position that is different than the old one
  do {
    i = (int) random (0, c.pnum);
  } while (i == old_heart);
  
  c.points[old_heart].is_heart = false;
  c.points[i].is_heart = true;
}

// change the position of the mouth or heart
void mutate_mouth_heart(creature c)
{
  if (random(1) < 0.5)
    mutate_mouth (c);
  else
    mutate_heart (c);
}

// make all points masses into mouths and hearts
void all_mouths_and_hearts(creature c)
{
  int i;
  
  // count number of mouths
  for (i = 0; i < c.pnum; i++) {
    c.points[i].is_mouth = true;
    c.points[i].is_heart = true;
  }
}

// pick color based on group number
void pick_color_from_group(creature c, int group_id, boolean rand_color)
{
  // pick color for this creature
  
  int lo_min = 20;
  int lo_max = 100;
  int hi_min = 220;
  int hi_max = 255;
  
  int red,grn,blu;
  red = grn = blu = 255;
  
  // if we're not picking random colors, make this creatures color as bright as possible
  if (!rand_color) {
    lo_min = lo_max = 0;
    hi_min = hi_max = 255;
  }
  
  switch (group_id) {
    case 0:
      red = (int) random (hi_min, hi_max);
      grn = (int) random (lo_min, lo_max);
      blu = (int) random (lo_min, lo_max);
      break;
    case 1:
      red = (int) random (lo_min, lo_max);
      grn = (int) random (hi_min, hi_max);
      blu = (int) random (lo_min, lo_max);
      break;
    case 2:
      red = (int) random (lo_min, lo_max);
      grn = (int) random (lo_min, lo_max);
      blu = (int) random (hi_min, hi_max);
      break;
    case 3:
      red = (int) random (hi_min, hi_max);
      grn = (int) random (hi_min, hi_max);
      blu = (int) random (lo_min, lo_max);
      break;
    case 4:
      red = (int) random (hi_min, hi_max);
      grn = (int) random (lo_min, lo_max);
      blu = (int) random (hi_min, hi_max);
      break;
    case 5:
      red = (int) random (lo_min, lo_max);
      grn = (int) random (hi_min, hi_max);
      blu = (int) random (hi_min, hi_max);
      break;
    case 6:
      red = (int) random (hi_min, hi_max);
      grn = (int) random (hi_min, hi_max);
      blu = (int) random (hi_min, hi_max);
      break;
    case 7:
      red = (int) random (lo_min, lo_max);
      grn = (int) random (lo_min, lo_max);
      blu = (int) random (lo_min, lo_max);
      break;
    default:
      println ("bad group_id = " + c.group_id);
      break;
  }

  c.col = color (red, grn, blu);
}
//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: calculate sensor values for each creature

final int CONTROLLER_CONSTANT = 1;
final int CONTROLLER_SENSOR = 2;

final int SENSOR_HEART = 0;
final int SENSOR_MOUTH = 1;

// list of nearby creatures
int num_near = 0;
creature[] near_creatures = new creature[100];

// calculate the state of each sensor
void sensor_check()
{
  int i,j;
  
  // find heart and mouth positions for each creature
  for (j = 0; j < creatures.size(); j++) {
    creature c = (creature) creatures.get(j);
    float hx = 0;
    float hy = 0;
    float mx = 0;
    float my = 0;
    
    for (i = 0; i < c.pnum; i++) {
      if (c.points[i].is_heart) {
        hx = c.points[i].x;
        hy = c.points[i].y;
      }
      if (c.points[i].is_mouth) {
        mx = c.points[i].x;
        my = c.points[i].y;
      }
    }
    
    if (hx < 0) hx += world_width;
    if (hx >= world_width) hx -= world_width;
    
    if (hy < 0) hy += world_height;
    if (hy >= world_height) hy -= world_height;
    
    c.hx = hx;
    c.hy = hy;
    
    if (mx < 0) mx += world_width;
    if (mx >= world_width) mx -= world_width;
    
    if (my < 0) my += world_height;
    if (my >= world_height) my -= world_height;
    
    c.mx = mx;
    c.my = my;
    
    // store heart position in tail
    if (counter % tail_update_rate == 0) {
      c.xtail[c.tail_ptr] = hx;
      c.ytail[c.tail_ptr] = hy;
      c.tail_ptr++;
      if (c.tail_ptr >= c.tail_length)
        c.tail_ptr = 0;
    }
  }
  
  // place creatures in 2D grid twice, based on heart and mouth
  creature_grid.place_creatures_from_centers();
  
  // look at each creature and calculate sensor values
  for (j = 0; j < creatures.size(); j++) {
    creature c = (creature) creatures.get(j);
    for (i = 0; i < c.snum; i++) {
      segment s = c.segments[i];
      if (s.sensor_rad > 0) {
        calculate_sensor (s, c);
      }
      else
        s.sensor_value = 0;
    }
  }
    
  // calculate the controller values for each creature
  for (j = 0; j < creatures.size(); j++) {
    creature c = (creature) creatures.get(j);
    for (i = 0; i < c.snum; i++) {
      calculate_controllers (c.segments[i], c);
    }
  }
}

// calculate the reading of a sensor for a segment
void calculate_sensor (segment s, creature c)
{
  int i,j;

  // initialize sensor value at zero
  s.sensor_value = 0;
    
  // segment endpoints
  point p1 = c.points[s.i1];
  point p2 = c.points[s.i2];

  // calculate unit-length vector parallel to the segment
  float dx = p1.x - p2.x;
  float dy = p1.y - p2.y;
  float len = sqrt (dx*dx + dy*dy);
  if (len > 0) {
    dx /= len;
    dy /= len;
  }
  else {  // give no reading for zero-length segments
    return;
  }
  
  // calculate midpoint of the segment
  float midx = 0.5 * (p1.x + p2.x);
  float midy = 0.5 * (p1.y + p2.y);
  
  // rotate the vector (dx,dy) according to sensor orientation and
  // then scale by the sensor distance, and this gives us the sensor position
  float sx = midx + s.sensor_dist * (dx * s.sensor_cos - dy * s.sensor_sin);
  float sy = midy + s.sensor_dist * (dx * s.sensor_sin + dy * s.sensor_cos);
  
  float rad = s.sensor_rad;
  
  // create list of nearby creatures
  creature_grid.make_near_list (sx - rad, sx + rad, sy - rad, sy + rad);

  // examine nearby creatures to see if they are close to the sensor
  // (fast method, using grids)
  for (j = 0; j < num_near; j++) {
    creature c2 = near_creatures[j];
    // creature does not sense itself
    if (c == c2)
      continue;
    // find distance from sensor to the heart or mouth of creature c2
    if (s.sensor_type == SENSOR_HEART) {
      dx = c2.hx - sx;
      dy = c2.hy - sy;
    }
    else if (s.sensor_type == SENSOR_MOUTH) {
      dx = c2.mx - sx;
      dy = c2.my - sy;
    }
    len = sqrt(dx*dx + dy*dy);
    // if creature is within the sensor's radius, modify the sensor value
    if (len < rad) {
      s.sensor_value += 1;
    }
  }
}

// calculate controller values for a given segment
void calculate_controllers (segment s, creature c)
{
  int i;
  segment seg;
  
  // calculate the controller values
  for (i = 0; i < num_controllers; i++) {
    controller ct = s.controllers[i];
    switch (ct.type) {
      case CONTROLLER_CONSTANT:
        ct.value = ct.weight;
        break;
      case CONTROLLER_SENSOR:
        // determine which segment to get sensor value from
        if (ct.segment_num == -1)
          seg = s;
        else
          seg = c.segments[ct.segment_num];
        // grab sensor value from appropriate segment
        ct.value = ct.weight * seg.sensor_value;
        break;
      default:
        println ("Bad controller type = " + ct.type);
        exit();
        break;
    }
  }
  
}

// grid for fast spatial search for nearby creatures
class search_grid {
  
  int nx,ny;            // number of grid cells horizontally and vertically
  float xscale,yscale;  // scaling factor between (x,y) and grid cell indices
  ArrayList[][] cells;  // the grid of cells that point to creatures
  
  // create a search grid
  search_grid (int xnum, int ynum, float xs, float ys) {
    nx = xnum;
    ny = ynum;
    xscale = xs;
    yscale = ys;
    cells = new ArrayList[nx][ny];
    for (int i = 0; i < nx; i++)
      for (int j = 0; j < ny; j++)
        cells[i][j] = new ArrayList();
  }
  
  // place creatures in search grid based on heart and mouth
  void place_creatures_from_centers() {
    int i,j;
    
    // start out with all grid cells empty
    for (i = 0; i < nx; i++)
      for (j = 0; j < ny; j++)
        cells[i][j].clear();
    
    // place creatures in proper grid cells
    for (i = 0; i < creatures.size(); i++) {
      creature c = (creature) creatures.get(i);
      
      // heart position
      int ix = (int) (c.hx * xscale);
      int iy = (int) (c.hy * yscale);
      
      if (ix < 0) ix += nx;
      if (ix >= nx) ix -= nx;
      if (iy < 0) iy += ny;
      if (iy >= ny) iy -= ny;
      
      cells[ix][iy].add(c);
      
      // mouth position
      int ixx = (int) (c.mx * xscale);
      int iyy = (int) (c.my * yscale);

      if (ixx < 0) ixx += nx;
      if (ixx >= nx) ixx -= nx;
      if (iyy < 0) iyy += ny;
      if (iyy >= ny) iyy -= ny;
      
      // only add if at different place than heart
      if (ixx != ix || iyy != iy) {
        cells[ixx][iyy].add(c);
      }
      
    }
  }

  // place creatures in search grid based on bounding boxes
  void place_creatures_from_bounds() {
    int i,j;
    
    // start out with all grid cells empty
    for (i = 0; i < nx; i++)
      for (j = 0; j < ny; j++)
        cells[i][j].clear();
    
    // place creatures in proper grid cells
    for (i = 0; i < creatures.size(); i++) {
    
      creature c = (creature) creatures.get(i);


      // determine cell indices horizontally and vertically
      int i0 = (int) Math.floor(c.xmin * xscale);
      int i1 = (int) Math.floor(c.xmax * xscale);
      int j0 = (int) Math.floor(c.ymin * yscale);
      int j1 = (int) Math.floor(c.ymax * yscale);
      
      // examine all cells in the range and add any creatures in them to the list
      for (int a = i0; a <= i1; a++)  {
        int aa = a;
        if (aa < 0) aa += nx;
        if (aa >= nx) aa -= nx;
        for (int b = j0; b <= j1; b++) {
          int bb = b;
          if (bb < 0) bb += ny;
          if (bb >= ny) bb -= ny;
          cells[aa][bb].add(c);
        }
      }

    }
  }

  // create list of nearby creatures
  void make_near_list(float xmin, float xmax, float ymin, float ymax) {
    
    // first clear the flags of whether creatures are on the list
    for (int i = 0; i < num_near; i++)
      near_creatures[i].on_near_list = false;

    // start out with empty list of nearby creatures
    num_near = 0;

    // determine cell indices horizontally and vertically
    int i0 = (int) Math.floor(xmin * xscale);
    int i1 = (int) Math.floor(xmax * xscale);
    int j0 = (int) Math.floor(ymin * yscale);
    int j1 = (int) Math.floor(ymax * yscale);
    
    // examine all cells in the range and add any creatures in them to the list
    for (int a = i0; a <= i1; a++)  {
      int aa = a;
      if (aa < 0) aa += nx;
      if (aa >= nx) aa -= nx;
      for (int b = j0; b <= j1; b++) {
        int bb = b;
        if (bb < 0) bb += ny;
        if (bb >= ny) bb -= ny;
        // add all the creatures in this cell to the list of nearby creatures
        for (int k = 0; k < cells[aa][bb].size(); k++) {
          creature c = (creature) cells[aa][bb].get(k);
          // only add creature to the near list if it isn't already on it
          if (!c.on_near_list) {
            // store creature in cell
            near_creatures[num_near] = c;
            num_near++;
            // mark this creature as being on the near list
            c.on_near_list = true;
          }
        }
      }
    }
    
  }

}  // end of class "search_grid"
//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: keep track of species of creatures that arise from mutation

ArrayList species_list = new ArrayList();    // list of all species

boolean record_species_flag = false;   // whether to record species to file

class species {

  int creation_time;      // time the species was first created
  int extinction_time;    // when species became extinct (or -1 if still alive)
  int current_count;      // current count of individuals of this species
  int total_born;         // total number of this species born
  int max_individuals;    // maximum number of individuals alive at one time
  int kills;              // number of kills by all individuals of the species
  int parent;             // id of parent species
  int species_offspring;  // number of offspring species (mutations) of this one

  creature example_creature;

  // create a new species
  species (creature c) {
    
    // only record example creatures if we're writing out species
    if (record_species_flag == true) {
      example_creature = c;
    }
    
    creation_time = counter;
    extinction_time = -1;

    current_count = 0;
    total_born = 0;
    max_individuals = 0;
    kills = 0;
    
    parent = -1;
    species_offspring = 0;
  }

  // increment the count of a particular species
  void increment_count() {
    total_born++;
    current_count++;
    if (current_count > max_individuals) {
      max_individuals = current_count;
    }
  }

  // decrement the count of a particuclar species
  void decrement_count() {
  
    // sanity check
    if (current_count == 0) {
      println ("error: species counter already at zero");
      return;
    }
  
    current_count--;
    if (current_count == 0) {
      extinction_time = counter;
    }
  }

  // increment the offspring count of a species
  void increment_offspring() {
    species_offspring++;
  }

  // increment the kill count of a species
  void increment_kills() {
    kills++;
  }

}  // end class species

// increment the count of a species
void increment_species_count(creature c)
{
  int species_id = c.species_id;
  species s = (species) species_list.get(species_id);
  s.increment_count();
}

// decrement the count of a species
void decrement_species_count(creature c)
{
  int species_id = c.species_id;
  species s = (species) species_list.get(species_id);
  s.decrement_count();
}

// increment the offpring count of a species
void increment_offspring_count(creature c)
{
  int species_id = c.species_id;
  species s = (species) species_list.get(species_id);
  s.increment_offspring();
}

// increment the total kill count of a species
void increment_kill_count(creature c)
{
  int species_id = c.species_id;
  species s = (species) species_list.get(species_id);
  s.increment_kills();
}

// create a new species
void new_species(creature c, int parent_id)
{
  species s = new species(c);
  s.parent = parent_id;
  species_list.add(s);
}

// reconstruct species list based on creatures read in from a file
void reconstruct_species()
{
  int i;
  
  // first, clear out list of species
  for (i = species_list.size() - 1; i >= 0; i--) {
    species_list.remove(i);
  }
  
  // check creatures to see if we have to increase the species count
  for (i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    if (c.species_id > species_count) {
      species_count = c.species_id;
    }
  }
  
  // now create new list of species
  for (i = 0; i < species_count + 1; i++) {
    new_species(null, -1);
  }
  
  println ("species count = " + species_count);
  
  // set species counts based on living creatures
  for (i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    increment_species_count(c);
  }
}



