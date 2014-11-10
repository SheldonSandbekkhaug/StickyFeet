
//This file is not in the original stickyfeet
//Contains things to implement plants/herbivores into the world
//by charles incorvia
// plants are represented by single point masses in the creature space
class plant{
  float plantx;
  float planty;
  float radius = .25;
  color col;
  int type; // Used in the food web
  
  plant(){
   int i;
   
  }
  void drop_plant(float x, float y){
  this.plantx = x;
  this.planty = y;
  }
  
  void draw(){
   stroke(this.col);
   fill(this.col);
   circle_world(this.plantx,this.planty,radius);
    
  }
}
