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
final int SENSOR_PLANT = 2;

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
  if (s.sensor_type==SENSOR_PLANT){
    for (j =0; j < plants.size(); j++)
    {
      plant subject = (plant) plants.get(j);
      dx = subject.plantx - sx;
      dy = subject.planty - sy;
      
      len = sqrt(dx*dx + dy*dy);
      
      if (len < rad) {
      s.sensor_value += 1;
      }
      
    }
    
  }
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
