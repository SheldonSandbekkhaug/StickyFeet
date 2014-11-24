//  Permission is granted to use and modify this code for non-commercial
//  purposes, provided that this header information is retained.  This
//  program is described in the following paper:
//
//  "Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
//  Greg Turk
//  Artificial Life XII, August 19-23, 2010, Odense, Denmark

//  This file: creatures file I/O

import javax.swing.JFileChooser;
import java.io.BufferedWriter; // Used by write_graph_data
import java.io.FileWriter; // Used by write_graph_data

String run_dir = "";
boolean advanced = false; // True indicates reading/writing food types

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
  out.println ("carnivore " + c.carnivore);
  
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
  //Prevents all creatures from starving to death immediatly
  for ( i = 0; i < creatures.size(); i++)
  {
    creature c = (creature) creatures.get(i);
    c.hunger_time = counter;
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
    c = new creature(true);
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
  else if (w.equals ("carnivore")) {
    boolean meat = boolean(words[1]);
    c = (creature) creatures.get(creatures.size() - 1);
    c.carnivore = meat;
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
    c.add_segment (i1, i2, len, amp, freq, phase, bias,c.carnivore);
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
    dir = new File(dataPath(run_dir));
    if (!dir.exists()) { done = true; }
  } while (!done);
  
  println ("creating directory " + file);
  dir.mkdir();
}

/* Write data to a text file that can be used to graph numbers of carnivores
and herbivores. */
void write_graph_data()
{
  String filename = "graphData.txt";
  
  // see which directory number to write into
  if (run_dir.equals(""))
    find_directory_count();

  filename = run_dir + "/" + filename;

  // Count carnivores and herbivores as well as their types.
  int num_carnivores = 0;
  int num_herbivores = 0;
  int[] num_herbivore_types = new int[4*3*2];
  for (int i = 0; i < creatures.size(); i++) {
    creature c = (creature) creatures.get(i);
    if (c.carnivore == true)
    {
      num_carnivores++;
      
      // TODO: differentiate carnivore types
      
    }
    else
    {
      num_herbivores++;
      
      // Sort edible plants
      if (c.edible_plants[0] > c.edible_plants[1])
      {
        int temp = c.edible_plants[0];
        c.edible_plants[0] = c.edible_plants[1];
        c.edible_plants[1] = temp;
      }
      int type = (c.edible_plants[0] * 4) + c.edible_plants[1];
      num_herbivore_types[type]++;
    }
  }
  
  // Count plant types
  int[] plant_types = {0, 0, 0, 0};
  for (int i = 0; i < plants.size(); i++)
  {
    plant p = (plant)plants.get(i);
    int plant_type = p.type;
    plant_types[plant_type]++;
  }
  
  String graph_data = "time: " + counter + 
    "\nherbivores: " + num_herbivores + "\n";

  // Output numbers of herbivore types
  for (int i = 0; i < num_herbivore_types.length; i++)
  {
    graph_data += num_herbivore_types[i] + " ";
  }
  
  graph_data +=
    "\ncarnivores: " + num_carnivores +
    "\nplants: " + plants.size() +
    "\n";
    
  // Output plant type counts
  for (int i = 0; i < plant_types.length; i++)
  {
    graph_data += plant_types[i] + " ";
  }
  
  append_text_to_file(filename, graph_data);
}

/**
 * This function was taken from StackOverflow
 * Appends text to the end of a text file located in the data directory, 
 * creates the file if it does not exist.
 * Can be used for big files with lots of rows, 
 * existing lines will not be rewritten
 */
void append_text_to_file(String filename, String text){
  File f = new File(dataPath(filename));
  if(!f.exists()){
    createFile(f);
  }
  try {
    PrintWriter out = new PrintWriter(new BufferedWriter(new FileWriter(f, true)));
    out.println(text);
    out.close();
  }catch (IOException e){
      e.printStackTrace();
  }
}

/** This function was taken from StackOverflow
 * Creates a new file including all subfolders
 */
void createFile(File f){
  File parentDir = f.getParentFile();
  try{
    parentDir.mkdirs(); 
    f.createNewFile();
  }catch(Exception e){
    e.printStackTrace();
  }
}
