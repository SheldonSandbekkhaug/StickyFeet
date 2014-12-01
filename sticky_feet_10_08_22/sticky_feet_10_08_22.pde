//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: simulation set-up and various helper routines

import processing.opengl.*;

boolean headless = false; // True if you want to run without rendering
boolean fast_flag = true; // NOTE: originally was false
//these options are purely asthetic.  Enlarged for clarity in the more densely popultated food web simultaion
float sx = 1500; // Option: 800
float sy = 775; // Option: 600

int target_creature_count = 100;
int num_groups = 1;
creature[] group_representative = new creature[num_groups];
//world width doubled for foood web.
float world_width = 140; // width of the world in creature units. Often-used alternative is 155
float world_height = world_width * sy / sx;
int stroke_width = 1;         // width of drawn line segments

float mutation_rate = 0.1;        // probability of mutating when a new creature is created
float mutate_again  = 0.4;// if mutation, probability of mutating more than 

float competition_noise = 0.0;    // amount of noise in declaring winner, in [0,1]
int max_segments = 15;            // maximum number of segments in a creature

float heart_radius = 0.5;
int tail_length_global = 60;
int tail_update_rate = 40;

ArrayList creatures = new ArrayList();    // list of creatures
ArrayList plants = new ArrayList();

int counter = 0; 
int plantcounter = 0;
//plant respawn timer halved for food-web
int plant_respawn_timer = 100; // counts number of time-steps between plant respawns
int species_count = 0;           // unique id for new creatures
int birth_count = 0;             // number of total births in simulation
float time = 0;                  // global clock
boolean auto_write_flag = true;  // whether to automatically write out state files
int auto_write_count = 200000;   // number of timesteps between automatic file writing
int world_seed = 0;              // random number seed for the world
//startplants and maxplants doubled for food web, as there are less ediblee things for each creature
int startplants = 200; //was 100
int maxPlants = 200; //was 100

float dt = 0.1;                 // simulation time-step
int steps_per_draw = 10;        // how many simulation steps to take before drawing
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
color plantcol1 = color(0, 0, 0);
color plantcol2 = color(254,0,0);
color plantcol3 = color(0, 0, 254);
color plantcol4 = color(0,254,0);
color carnivore_color = red;
color herbivore_color = color(0, 0, 255); // Blue

search_grid creature_grid;       // grid for fast spatial search for creatures

PFont font;    // font for drawing letters in window

// initialize various things
void setup()
{
  int i;
  creature c;
  creature h;
  creature h2;
  
  world_seed = (int) random(10000);
  randomSeed(world_seed);
  println ("random number seed = " + world_seed);

  // set the window size
  size ((int) sx, (int) sy);
//  hint(ENABLE_OPENGL_4X_SMOOTh);
//  hint(DISABLE_OPENGL_2X_SMOOTh);  // use this on laptop to stop flickering
  
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
  
  frameRate(60);

  println ("See README.txt for keyboard commands");
  
  write_graph_data(); // NOTE: added by Sheldon
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
// also initializes plants
void init_creatures()
{
  int i;
  creature c;
  creature h;
  creature h2;
  plant p;
  // first, delete all creatures
  delete_all_creatures();
  
  // re-set various counts and flags
  counter = 0;
  birth_count = 0;
  species_count = 0;
  time = 0;
  
  // sessile creature
  /*
  c = new creature(true);
  birth_by_hand(c);
  c.add_point(7, 6, false);
  c.add_point(6, 6, false);
  c.add_segment (0, 1, 1, 0, 0, 0, 0, true);
  c.points[0].is_heart = true;
  c.segments[0].sensor_dist = 0;
  c.translate(random (world_width), random (world_height));
  creatures.add(c);
  */
  
  
  //intializes plants at the beginning of the simulation
  for(i= 0; i < startplants; i++) {
  p = new plant();
    p.drop_plant(random (world_width), random (world_height));
    p.type = i % 4;
    if(p.type == 1)
    {  
      p.col = plantcol1;
    }
    else if(p.type == 2)
    {
      p.col = plantcol2;
    }
    else if(p.type == 3)
    {
      p.col = plantcol3;
    }
    else
    {
      p.col = plantcol4;
    }
    plants.add(p);
  }
  /*
  // create duplicates creatures and place them randomly
  int num = target_creature_count - num_groups - 1;
  for (i = 0; i < num - 97; i++) {
    c = (creature) creatures.get(0);
    boolean birth_successful = birth (c, 10, false);
    c = (creature) creatures.get(creatures.size()-1);
    c.group_id = i % num_groups;
  }
  */
  
  
  // one-segment creature (carnivore)
  /*
  c = new creature(true);
  birth_by_hand(c);
  c.add_point(7, 5.5, false);
  c.add_point(6, 5.5, false);
  c.add_segment (0, 1, 1.0, 0.2, default_freq * 2, 0, 1.0,true);
  c.points[1].is_mouth = true;
  c.points[0].is_heart = true;
  c.segments[0].sensor_set (140, 3, 1.7, SENSOR_HEART);
  c.segments[0].controller_set (CONTROL_FOOT_AMP, CONTROLLER_CONSTANT, 0.0, -1);
  creatures.add(c);
  c.translate(0.5 * world_width, 0.5 * world_height);
  c.rotate(0.3);
  //c.col = red; // NOTE: commented out by Sheldon
  c.col = carnivore_color;
  */
  
  // Create two herbivores
  h = new creature(false);
  birth_by_hand(h);
  h.add_point(7, 5.5, false);
  h.add_point(6, 5.5, false);
  h.add_segment (0, 1, 1.0, 0.2, default_freq * 2, 0, 1.0,false);
  h.points[1].is_mouth = true;
  h.points[0].is_heart = true;
  h.segments[0].sensor_set (140, 3, 1.7, SENSOR_PLANT);
  h.segments[0].controller_set (CONTROL_FOOT_AMP, CONTROLLER_CONSTANT, 0.0, -1);
  creatures.add(h);
  h.translate(0.75 * world_width, 0.5 * world_height);
  h.rotate(1);
  h.col = herbivore_color;
  h.edible_plants[0] = 0;
  h.edible_plants[1] = 1;
  //irrelevant until someone mutates into a carnivore
  h.edible_creatures[0][0] = 0;
  h.edible_creatures[1][0] = 0;
  h.edible_creatures[2][0] = 0;
  h.edible_creatures[0][1] = 1;
  h.edible_creatures[1][1] = 3;
  h.edible_creatures[2][1]=  2;
  
  h2 = new creature(false);
  birth_by_hand(h2);
  h2.add_point(7, 5.5, false);
  h2.add_point(6, 5.5, false);
  h2.add_segment (0, 1, 1.0, 0.2, default_freq * 2, 0, 1.0,false);
  h2.points[1].is_mouth = true;
  h2.points[0].is_heart = true;
  h2.segments[0].sensor_set (140, 3, 1.7, SENSOR_PLANT  );
  h2.segments[0].controller_set (CONTROL_FOOT_AMP, CONTROLLER_CONSTANT, 0.0, -1);
  creatures.add(h2);
  h2.translate(0.25 * world_width, 0.5 * world_height);
  h2.rotate(3.1);
  h2.col = herbivore_color;
  h2.edible_plants[0] = 2;
  h2.edible_plants[1] = 3;
  //irrelevant until someone mutates into a carnivore
  h2.edible_creatures[0][0] = 2;
  h2.edible_creatures[1][0] = 1;
  h2.edible_creatures[2][0] = 1;
  h2.edible_creatures[0][1] = 3;
  h2.edible_creatures[1][1] = 2;
  h2.edible_creatures[2][1] = 3;
  
  // maybe create multiple groups
  if (num_groups > 1) {
    // duplicate the last creature made, so there are num_group copies in total
    for (i = 0; i < num_groups-1; i++) {
      //birth (c, 10, false); // NOTE: original
      birth(h, 10, false);
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
    if(fast_flag)
      while(counter%(steps_per_draw*100)!=0) 
        one_timestep();
    
  }
  
  float x = world_width * mouseX / sx;
  float y = world_width * (sy - mouseY) / sx;

  // draw everything, but maybe not every time-step
  if ((counter % steps_per_draw == 0) && (headless==false)) {
    draw_all();
  }
  
  if (counter % 10000 == 0)
  {
    println("At timestep " + counter + "; writing graph data");
    write_graph_data();
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
  draw_all_plants();
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
  //println("Computing timestep " + counter); // TODO: remove
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
    write_graph_data();
    // re-seed the random number generator
    randomSeed(world_seed);
  }
  if(plantcounter>=plant_respawn_timer)
  {
    if(plants.size()<=maxPlants)
    {
      plant p = new plant();
      int type = (int)random(100) % 3;
      if(type == 1)
      {
        p.col = plantcol1;
      }
      else if(type == 2)
      {
        p.col = plantcol2;
      }
      else if (type == 0)
      {
        p.col = plantcol3;
      }
      p.drop_plant(random (world_width), random (world_height));
      plants.add(p);
      plantcounter=0;
    }
  }
  
  // advance the clock
  time += dt;  
  time = time % 1000000; // Prevent precision errors
  
  plantcounter++;
  counter++;
  
  if(creatures.size()<=0)
  {
    println("Creature extinction, ending simulation");
    exit();
  }
}

// draw all of the creatures
void draw_all_creatures() {
  int i;
  for (i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    c.draw();
  }  
}

void draw_all_plants() {
  int i;
  for(i = 0; i < plants.size(); i ++) {
    plant p = (plant) plants.get(i);
    p.draw();
    
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
     write_graph_data();
  }
  else if(key == 'x' || key == 'X') {
     sensor_show_flag = !sensor_show_flag;
     if (sensor_show_flag)
       println ("showing sensors");
     else
       println ("not showning sensors");
     draw_all();
  }
  else if(key == 'f' || key == 'F') 
    fast_flag=!fast_flag;
  else if(key == 'q' || key == 'Q') {
     exit();
  }
}


