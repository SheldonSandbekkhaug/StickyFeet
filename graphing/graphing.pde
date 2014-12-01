/* Clas to represent the data at a particular timestep */
class GraphStep
{
  int time; // The timestep
  int herbivores; // Number of herbivores alive
  int carnivores; // Number of carnivores alive
  int plants; // Number of plants alive
  
  GraphStep()
  {
  }
}

int X_BUFFER = 50; // Gap between window edge and graph edge
int Y_BUFFER = 50;
int windowWidth = 1320;
int graphWidth = windowWidth - X_BUFFER * 2;
int windowHeight = 400;
int graphHeight = windowHeight - Y_BUFFER;
color BLACK = color(0,0,0);
color BLUE = color(0,0,255);
color RED = color(255,0,0);
color PLANT_GREEN = color(153,255,51);

int xMax;
int yMax;

void setup() {
  size(windowWidth, windowHeight);
  background(255);
  stroke(0);
  
  // Read the data file
  ArrayList<GraphStep> graphData = readGraphData("graphData.txt");
  
  // Draw the graph
  draw(graphData);
}

void draw(ArrayList<GraphStep> graphData) {
  // Get the maximum sizes of each axis for the graph
  xMax = graphData.get(graphData.size() - 1).time;
  yMax = getHighestGraphValue(graphData);
  
  // Draw x-axis
  fill(BLACK);
  line(X_BUFFER, graphHeight, graphWidth, graphHeight);

  // Draw y-axis
  line(X_BUFFER, Y_BUFFER, X_BUFFER, graphHeight);    
  
  // Graph each type of creature
  int[] prevHerbivorePt = {0,0};
  int[] prevCarnivorePt = {0,0};
  int[] prevPlantPt = {0,160}; // TODO: remove hardcoded default plant value
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
  
  // Draw y-axis tick marks
  for (int i = 0; i < 11; i++)
  {
    stroke(BLACK);
    int y_tick = mapYValue(yMax / 10 * i, graphHeight, yMax);
    line(X_BUFFER, y_tick, X_BUFFER + 5, y_tick);
    text("" + (yMax / 10 * i), X_BUFFER - 20, y_tick);
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
  
  for (int i = 0; i < lines.length; i += 4)
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
    
    String pString = lines[i+3].substring(lines[i+3].indexOf(": ")+ 2);
    g.plants = Integer.parseInt(pString);
    
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
  return max - (int)(((float)y/(float)scale) * (max - Y_BUFFER));
}

/* Get the x-coordinate in the window for where this x-value corresponds to */
int mapXValue(int x, int max, int scale)
{
  return (int)(((float)x/(float)scale) * max) + X_BUFFER;
}
