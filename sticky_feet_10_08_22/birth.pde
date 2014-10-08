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
  //Record the time the creature was born so we know when it will starve
  child.hunger_time = counter;  
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
