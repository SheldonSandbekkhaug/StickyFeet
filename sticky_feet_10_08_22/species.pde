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


