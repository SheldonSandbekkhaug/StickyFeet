import java.util.Scanner;

boolean draw_plant_types = false;

/* Clas to represent the data at a particular timestep */
class GraphStep
{
  int time; // The timestep
  int herbivores; // Number of herbivores alive
  int carnivores; // Number of carnivores alive
  int plants; // Number of plants alive
  int[] plant_types; // Number of each type of plant alive
  
  GraphStep()
  {
    plant_types = new int[NUM_PLANT_TYPES];
  }
}

int NUM_PLANT_TYPES = 4;
int windowWidth = 1320;
int graphWidth = windowWidth - 50;
int windowHeight = 400;
int graphHeight = windowHeight - 50;
color BLACK = color(0,0,0);
color BLUE = color(0,0,255);
color RED = color(255,0,0);
color PLANT_GREEN = color(153,255,51);
color[] plant_type_colors;

int xMax;
int yMax;

void setup() {
  size(windowWidth, windowHeight);
  background(255);
  stroke(0);
  
  // Read the data file
  ArrayList<GraphStep> graphData = readGraphData("graphData.txt");
  
  // Set plant type colors
  int num_plant_types = graphData.get(0).plant_types.length;
  int color_fraction = 255 / num_plant_types;
  plant_type_colors = new int[num_plant_types];
  for (int i = 0; i < num_plant_types; i++)
  {
    plant_type_colors[i] = color(0, color_fraction * i, 0);
  }
  // Draw the graph
  draw(graphData);
}

void draw(ArrayList<GraphStep> graphData) {
  // Get the maximum sizes of each axis for the graph
  xMax = graphData.get(graphData.size() - 1).time;
  yMax = getHighestGraphValue(graphData);
  
  fill(BLACK);
  line(0, graphHeight, graphWidth, graphHeight);
  
  // Graph each type of creature
  int[] prevHerbivorePt = {0,0};
  int[] prevCarnivorePt = {0,0};
  int[] prevPlantPt = {0,160}; // TODO: remove hardcoded default plant value
  int[][] prevPlantTypesPts = {{0, 0}, {0, 0}, {0, 0}, {0, 0}};
  for (int i = 0; i < graphData.size(); i++)
  {
    int time = graphData.get(i).time;
    // Draw the herbivore line
    prevHerbivorePt = drawNextLineSegment(prevHerbivorePt,
      time, graphData.get(i).herbivores, BLUE);
    
    // Draw line for carnivores
    prevCarnivorePt = drawNextLineSegment(prevCarnivorePt,
      time, graphData.get(i).carnivores, RED);  
    
    // Draw the plant line
    prevPlantPt = drawNextLineSegment(prevPlantPt,
      time, graphData.get(i).plants, PLANT_GREEN);
      
    if (draw_plant_types == true)
    {
      // Draw plant type lines
      for (int j = 0; j < graphData.get(i).plant_types.length; j++)
      {
        prevPlantTypesPts[j] = drawNextLineSegment(prevPlantTypesPts[j],
          //time, graphData.get(i).plant_types[j], BLACK);
          time, graphData.get(i).plant_types[j], plant_type_colors[j]); // TODO
      }
    }
    
    // Label the graph and draw some tick marks
    if (i % (graphData.size() / 10) == 0)
    {
        PFont f;
        f = createFont("ArialNarrow-20.vlw",16,true);
        textFont(f, 10);
        fill(BLACK);
        
        int x = mapXValue(graphData.get(i).time, graphWidth, xMax);
        
        // x-axis label
        text("" + graphData.get(i).time / 1000 + "k", x, graphHeight + 11);
        
        // Tick marks for the x-axis
        stroke(BLACK);
        line(x, graphHeight, x, graphHeight + 5);
    }
  }
}

// Draw the next line segment
int[] drawNextLineSegment(int oldPt[], int newX, int newY, color c)
{
    int x = mapXValue(newX, graphWidth, xMax);
    int y = mapYValue(newY, graphHeight, yMax);
    
    if (oldPt[0] != 0)
    {
      stroke(c);
      line(oldPt[0], oldPt[1], x, y);
    }
    
    oldPt[0] = x;
    oldPt[1] = y;
    return oldPt;
}

// Read graph data from a file and store it
ArrayList<GraphStep> readGraphData(String filename)
{
  String[] lines = loadStrings(filename);
  ArrayList<GraphStep> graphData = new ArrayList<GraphStep>();
  int maxHerbivores = 0;
  int maxCarnivores = 0;
  
  for (int i = 0; i < lines.length; i += 5)
  {
    GraphStep g = new GraphStep();
    
    // Get the time step
    String timeString = lines[i].substring(lines[i].indexOf(": ")+ 2);
    g.time = Integer.parseInt(timeString);
    
    // Get the number of herbivores
    String hString = lines[i+1].substring(lines[i+1].indexOf(": ")+ 2);
    g.herbivores = Integer.parseInt(hString);
    
    // Get the number of carnivores
    String cString = lines[i+2].substring(lines[i+2].indexOf(": ")+ 2);
    g.carnivores = Integer.parseInt(cString);
    
    // Get the number of plants
    String pString = lines[i+3].substring(lines[i+3].indexOf(": ")+ 2);
    g.plants = Integer.parseInt(pString);
    
    // Get the number of each plant type
    String plant_types = lines[i+4];
    Scanner line_scanner = new Scanner(plant_types);
    int j = 0;
    while (line_scanner.hasNext())
    {
      g.plant_types[j] = line_scanner.nextInt();
      j++;
    }
    
    println("Time: " + g.time + ": H: " + g.herbivores + "; C: " + g.carnivores + 
      "; P: " + g.plants);
    
    graphData.add(g);
  }
  
  return graphData;
}

/* Return the highest number of carnivores, herbivores, or plants at a single timestep. */
int getHighestGraphValue(ArrayList<GraphStep> graphData)
{
  int maxValue = 0;
  for (int i = 0; i < graphData.size(); i++)
  {
    GraphStep g = graphData.get(i);
    maxValue = Math.max(maxValue, g.carnivores);
    maxValue = Math.max(maxValue, g.herbivores);
    maxValue = Math.max(maxValue, g.plants);
  }
  
  return maxValue;
}

/* Get the y-coordinate in the window for where this y-value corresponds to
   screenHeight - ((x / maxX) * graphHeight)
*/
int mapYValue(int y, int max, int scale)
{
  return max - (int)(((float)y/(float)scale) * max);
}

/* Get the x-coordinate in the window for where this x-value corresponds to */
int mapXValue(int x, int max, int scale)
{
  return (int)(((float)x/(float)scale) * max);
}
