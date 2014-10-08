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

