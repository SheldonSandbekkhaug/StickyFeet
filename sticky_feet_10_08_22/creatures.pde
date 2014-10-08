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
  int sensor_type;     // sensitive to heart or mouth?  (SENSOR_HEART or SENSOR_MOUTH or SENSOR_PLANT)
  float sensor_value;  // value returned by the sensor
  
  // controllers for various parameters
  controller[] controllers;
  
  segment(int i, int j, float len, boolean meat) {
    i1 = i;
    i2 = j;
    length = len;
    create_helper(meat);
  }
  
  segment(int i, int j, float len, float a, float f, float p, float b, boolean meat) {
    i1 = i;
    i2 = j;
    length = len;
    create_helper(meat);
    
    amp = a;
    freq = f;
    phase = p;
    foot_amp = b;
  }
  
  void create_helper(boolean meat) {
    k_spring = default_k_spring;
    k_damp = default_k_damp;
    
    amp = 0;
    freq = default_freq;
    phase = 0;
    foot_amp = 0;
    if(meat==true)
    {
      sensor_set (0, 0, 0, SENSOR_HEART);
    }
    else
    {
      sensor_set (0, 0, 0, SENSOR_PLANT);
    }
    
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
    sensor_type = stype;  // SENSOR_HEART or SENSOR_MOUTH or SENSOR_PLANT
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
  int hunger_time;
  int starvation = 75000;
  
  
  int pnum,pmax;
  point[] points;    // point masses of creature
  
  int snum,smax;
  segment[] segments;   // segments that connect the points
  
  int hunger = 2;      // only relevant to herbivores (NOTE: carnivores have hunger too)
  
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
  boolean carnivore;     // can this creature eat plants?

  
  // tail (for drawing where creature has been recently)
  int tail_length = tail_length_global;
  int tail_ptr = 0;
  float[] xtail;
  float[] ytail;
  
  // whether user has selected this creature with mouse
  boolean select_flag;
  
  // create a new creature
  creature(boolean meateater) {
    int i;
    carnivore = meateater;
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
  
  void add_segment (int i1, int i2, float len, boolean meat) {
    segment s = new segment (i1, i2, len, meat);
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
  
  void add_segment (int i1, int i2, float len, float amp, float freq, float phase, float foot_amp, boolean meat) {
    segment s = new segment (i1, i2, len, amp, freq, phase, foot_amp, meat);
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
    creature c = new creature(true);
    creatures.add(c);
    c.col = col;
    c.phase = phase;
    c.select_flag = false;
    c.carnivore = carnivore;
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
      c.add_segment (s.i1, s.i2, s.length, s.amp, s.freq, s.phase, s.foot_amp,carnivore);
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
