
//This file is not in the original stickyfeet
//Contains things to implement plants/herbivores into the world
//by charles incorvia
// plants are represented by single point masses in the creature space
class plant{
  float plantx;
  float planty;
  float radius = .25;
  color col;
  plant(){
   int i;
   col = plantcol;
  }
  void drop_plant(float x, float y){
  this.plantx = x;
  this.planty = y;
  }
  
  void draw(){
   stroke(plantcol);
   fill(plantcol);
   circle_world(this.plantx,this.planty,radius);
    
  }
}
