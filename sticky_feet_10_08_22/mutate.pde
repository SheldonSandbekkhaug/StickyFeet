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

float mutate_orientation = 0.05;
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
  
  /*if (num_groups == 1) {  // pick entirely random color if there is just one group
    int red = (int) random (lo_min, hi_max);
    int grn = (int) random (lo_min, hi_max);
    int blu = (int) random (lo_min, hi_max);
    c.col = color (red, grn, blu);
  }
  else {
    // pick a new random color for this creature based on group id
    pick_color_from_group (c, c.group_id, true);
  }*/
  if(random(1)<0.25)
  {
    if(c.carnivore)
    {
      c.carnivore = false;
    }
    else
    {
      c.carnivore = true;
    }
  }
  if(c.carnivore)
  {
    c.col = carnivore_color;
  }
  else
  {
    c.col = herbivore_color;
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
    c.add_segment (p_index, p_index2, s.length, s.amp, s.freq, s.phase, s.foot_amp,c.carnivore);
  else
    c.add_segment (p_index2, p_index, s.length, s.amp, s.freq, s.phase, s.foot_amp, c.carnivore);
  
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
    c.add_segment (index1, index2, s.length, s.amp, s.freq, s.phase, s.foot_amp, c.carnivore);
  else
    c.add_segment (index2, index1, s.length, s.amp, s.freq, s.phase, s.foot_amp, c.carnivore);
  
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
    c.add_segment (p_index, s.i1, new_length, s.amp, s.freq, s.phase, s.foot_amp, c.carnivore);
    c.add_segment (p_index, s.i2, new_length, s.amp, s.freq, s.phase, s.foot_amp, c.carnivore);
  }
  else {
    c.add_segment (s.i1, p_index, new_length, s.amp, s.freq, s.phase, s.foot_amp, c.carnivore);
    c.add_segment (s.i2, p_index, new_length, s.amp, s.freq, s.phase, s.foot_amp, c.carnivore);
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
