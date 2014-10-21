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
ArrayList herbivore_births = new ArrayList();

// creature status (alive or dead)
final int ALIVE = 1;
final int DEAD  = 2;

// how many frames to show kill
int show_kill_frames = 10;
int birthtoggle = 1;
float distance = 450;
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
    
    if(counter - c1.hunger_time > c1.starvation)
      {
        //println("Creature death due to starvation"); // NOTE: commented
        creatures.remove(i);
        
        // Uncomment this section if you want a plant to spawn when a creature dies
        /*plant p = new plant();
        p.drop_plant(random (world_width), random (world_height));
        plants.add(p);
        
        if(c1.hunger == 0)
        {
          p = new plant();
          p.drop_plant(random (world_width), random (world_height));
          plants.add(p);
        }*/
      }
    
    if(c1.carnivore == true)
    {
    
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
        
        // create list of nearby creatures
        creature_grid.make_near_list (xmin, xmax, ymin, ymax);

        // examine each nearby creature to see if mouth eats it
        for (k = 0; k < num_near; k++) {
          creature c2 = near_creatures[k];
          if (c1 == c2)
            continue;
          //cross_event eats12 = creature_mouth_eats_other (c1, c2, mouth);
          cross_event eats12 = creature_mouth_eats_heart (c1, c2, mouth);
          if (eats12 != null) {
            add_cross_event (eats12);
          }
        }
      }
    }
    else if (c1.carnivore == false){
      point mouth = null;
      for (j = 0; j < c1.pnum; j++)
      {
        if (c1.points[j].is_mouth) 
         { mouth = c1.points[j];}
      }//loop through plants to find intersections with plants
      for( j = 0; j < plants.size(); j++)
      {
       plant p = new plant();
       p = (plant) plants.get(j);
       distance = sqrt(pow((mouth.x-p.plantx),2) + pow((mouth.y - p.planty),2));
       if(distance <= 1)
       {  
         c1.hunger_time = counter;
         
         if(c1.hunger>=0)
         {
           c1.hunger--;
           plants.remove(j);
         }
         else
         {
           plants.remove(j);
           if(true)//creatures.size()<=105)
           {
             c1.hunger = c1.maxHerbivoreHunger;
           
             //println("added to the list of herbivore births");
             herbivore_births.add(c1);
           }
         }
       }
      }
   }
  }
    
  // nothing more to do here if there were no crossing events
  if (cross_list.size() == 0 && herbivore_births.size()==0)
    return;
  
  // mark all creatures as being alive
  for (i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    c.status = ALIVE;
  }
  
  // process the list of cross events
  // SHOULD SORT THE LIST BY TIME !!!!
  
  birth_queue = new ArrayList();  // initialize the birth queue as empty
  
  for(i = 0; i <herbivore_births.size(); i ++)
  {
    birth_queue.add(herbivore_births.get(i));
    //println("herbivore birth addded to birth queue"); // NOTE: commented out
  }
  // clear it once it's done
  herbivore_births = new ArrayList();
  
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
      if(!fast_flag)
      kill_list.add(e);            // add this event to the list of kills
      
      /*
      if(plants.size()<=101)
      {
      plant p = new plant(); // a plant is added upon creature death to balance the amount of energy in the environment
       p.drop_plant(random (world_width), random (world_height));
       plants.add(p);   
      }
      */
      
      // note that c1 is now the birth representative for its group
      group_representative[e.c1.group_id] = e.c1;
      
      // add a creature to the birth queue once evevery two times a creature dies.
      e.c1.hunger_time = counter;
      
      // NOTE: original was hunger == 0
      if (e.c1.hunger >= 0)
      {
        if(true)//creatures.size()<=101)
        {
          e.c1.hunger--;
          if(e.c2.hunger == 0)
          {
            //println("predator birth added to queue"); // NOTE: commented out
            if (e.c1.group_id == e.c2.group_id)
              birth_queue.add (e.c1);                    // add c1 to birth queue if c1 and c2 are in same group
            else
              birth_queue.add (group_representative[e.c2.group_id]);
          }
        }
      }   // add representative of c2's group if not from same group
      else
      {
        e.c1.hunger = e.c1.maxCarnivoreHunger; // NOTE: original was 0
      }
      
    }
  }

  // Remove the dead creatures from the world.
  // Note that we count down from the end of the list to do this.
  for (i = creatures.size() - 1; i >= 0; i--) {
    creature c = (creature) creatures.get(i);
    if (c.status == DEAD) {
      decrement_species_count(c);    // decrement the count of individuals of a species
      creatures.remove(i);
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

