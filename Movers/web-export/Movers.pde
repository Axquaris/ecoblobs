import de.bezier.guido.*;

public int sHeight;
public int sWidth;
final static int DIVSIZE = 1000;
final static float NOMFACTOR = 1.2; //if (myMass > itsMass * NOMFACTOR) then its NOMABBLE
float metabolismRate, growthRate;

  
final float BORDERSIZE = sqrt(DIVSIZE/PI);
  
public ArrayList<Mover> movers = new ArrayList<Mover>();
public ArrayList<Plant> plants = new ArrayList<Plant>();

float g = 0.4;

//UI ELEMENTS
UiButton reset;
UiSlider moversCtrl;
UiSlider plantsCtrl;
UiSlider moversMCtrl;
UiSlider plantsMCtrl;
UiGrapherII graph;

void setup() {
  frameRate(30);
  size(1000,800);
  sHeight = 700;
  sWidth = width;
  ellipseMode(RADIUS);
  
  metabolismRate = 0.998;
  growthRate = 1.01;
  
  //Create Blobs
  movers = new ArrayList<Mover>();
  for (int i = 0; i < 30; i++) movers.add(new Mover(random(DIVSIZE/3,DIVSIZE*1.1),random(sWidth),random(sHeight)));
  plants = new ArrayList<Plant>();
  for (int i = 0; i < 5; i++) plants.add(new Plant(random(100, 500),random(width-BORDERSIZE*2)+BORDERSIZE,random(sHeight-BORDERSIZE*2)+BORDERSIZE));
  
  //UI
  Interactive.make( this );
  setupUi();
  
  //noLoop(); //Starts sketch paused for blog
}

void draw() {
  background(255);
  
  //Update Movers
  float mMass = 0;
  for (int i = 0; i < movers.size(); i++) {
    if(movers.get(i).update()) movers.remove(i);
    else mMass += movers.get(i).mass;
  }
  graph.plotA(mMass);
  
  //Update Plants
  float pMass = 0;
  for (int i = 0; i < plants.size(); i++) {
    if(plants.get(i).update()) {
      plants.remove(i);
      plants.add(new Plant(random(100, 500),random(width-BORDERSIZE*2)+BORDERSIZE,random(sHeight-BORDERSIZE*2)+BORDERSIZE));
    }
    else pMass += plants.get(i).mass;
  }
  graph.plotB(pMass);
  
  //Display blobs
  for (int i = 0; i < plants.size(); i++) plants.get(i).display();
  for (int i = 0; i < movers.size(); i++) movers.get(i).displayGhost();
  for (int i = 0; i < movers.size(); i++) movers.get(i).display();

  //GUI
  fill(57, 103, 144);
  rect(0, sHeight, 650, 100);

  graph.render();
}

void setupUi() {
  reset = new UiButton ( 10, sHeight+10, 120, 80, "RESET");
  moversCtrl = new UiSlider( 150, sHeight+10, 240, 35, 30/100, 100, 35 );
  moversCtrl.button = color(75);
  plantsCtrl = new UiSlider( 150, sHeight+55, 240, 35, 5/10, 10, 35 );
  plantsCtrl.button = color(93, 156, 51, 250);
  
  
  moversMCtrl = new UiSlider( 400, sHeight+10, 240, 35, 0.998, -1 , 70);
  moversMCtrl.button = color(75);
  moversMCtrl.buttonW = moversMCtrl.height*2;
  plantsMCtrl = new UiSlider( 400, sHeight+55, 240, 35, 1.01, -2, 70 );
  plantsMCtrl.button = color(93, 156, 51, 250);
  plantsMCtrl.buttonW = plantsMCtrl.height*2;
  
  graph = new UiGrapherII(650, height-150, 350, 150, "Blob Masses");
}

class Mover {
  //Property Vars
  PVector location;
  PVector velocity, noseEnd;
  PVector acceleration;
  float radius;
  float mass;
  
  //AI Vars
  PVector target;
  float tDivisor;
  float closestThreat;
  
  //Torrific Vars
  int ghostX;
    // 0 = no change
    // 1 = ghost on right
    // -1 = ghost on left
  int ghostY;
    // 0 = no change
    // 1 = ghost on bottom
    // -1 = ghost on top
  
  Mover(float m, float x, float y) {
    //Property Vars
    location = new PVector(x, y);
    velocity = new PVector();
    noseEnd = new PVector();
    acceleration = new PVector();
    mass = m;
    radius = sqrt(m/PI);
    
    //AI Vars
    target = new PVector();
    tDivisor = 0;
    closestThreat = 1000;
    
    //Torrific Vars
    ghostX = 0;
    ghostY = 0;
  }
  
  Mover(float m, float x, float y, PVector velocity) {
    this(m, x, y);
    this.velocity = new PVector(velocity.x, velocity.y);
   }
  
  void addTarget(PVector aTarget, float strength) {
    target.add(aTarget);
    tDivisor += abs(strength);
  }

  boolean update() {
    //Reset vars
    target.mult(0);
    tDivisor = 0;
    acceleration.mult(0);

    if (mass < 20) return true; //Self destruct
    
    closestThreat = 1000;
    
    for (int j = 0; j < movers.size(); j++) {
      if (!this.equals(movers.get(j))) {
        consider(movers.get(j));
        slurp(movers.get(j));
      }
    }
    for (int j = 0; j < plants.size(); j++) {
      if (!this.equals(plants.get(j))) {
        if (mass <= DIVSIZE) considerP(plants.get(j));
        slurpP(plants.get(j));
      }
    }
    
    //Movement Calculations
    target.div(tDivisor);
    acceleration = target;
    acceleration.setMag((mass*200)/DIVSIZE);
    
    acceleration.div(mass);
    velocity.add(acceleration);
    velocity.limit(1+mass/DIVSIZE);
    noseEnd = new PVector(velocity.x*radius, velocity.y*radius);
    location.add(velocity);
    
    //Torification :)
    //if (location.x + BORDERSIZE <= 0) location.x += sWidth + BORDERSIZE*2;
    //else if (location.x - BORDERSIZE >= sWidth) location.x -= sWidth + BORDERSIZE*2;
    //if (location.y + BORDERSIZE <= 0) location.y += sHeight + BORDERSIZE*2;
    //else if (location.y - BORDERSIZE >= sHeight) location.y -= sHeight + BORDERSIZE*2;
    torify();
    
    //Division test
    if (mass > DIVSIZE && closestThreat > 100) {
      divide();
    }
    
    //Consider Metabolism
    mass *= metabolismRate;
    radius = sqrt(mass/PI);
    
    return false;
  }

  void display() {
    radius = sqrt(mass/PI);
    stroke(0);
    strokeWeight(2);
    fill(150 - 100*(mass/DIVSIZE), 200);
    ellipse(location.x, location.y, radius, radius);
    line(location.x, location.y, location.x+noseEnd.x, location.y+noseEnd.y);
  }
  
  void consider(Mover m) {
    PVector pointer = torusPointer(m.location, location);
    float distance = pointer.mag();
    distance = constrain(distance, 5.0, 3000.0);
    float strength;
    
    //AI decisions
    if (mass <= DIVSIZE) {
      if (mass > m.mass * NOMFACTOR) strength = m.mass/pow(distance, 2);
      else if (m.mass > mass * NOMFACTOR * .95) {
        strength = -m.mass* 200/distance/distance/distance;
        if (m.mass > mass * 0.45 && distance < closestThreat) closestThreat = distance;
      }
      else if (distance < 3*(radius + m.radius)) strength = -10000/distance/distance/distance;
      else strength = 0;
      
      if (distance < closestThreat) closestThreat = distance;
    }
    else {
      if (m.mass > mass * 0.45) {
        strength = -m.mass/distance/distance;
        if (distance < closestThreat) closestThreat = distance;
      }
      else if (distance < 3*(radius + m.radius) && distance >= closestThreat) strength = -10000/distance/distance/distance;
      else strength = 0;
    }
    
    //Set importance of target
    pointer.setMag(strength);
    //Add new desired location
    if (strength != 0) addTarget(pointer, strength);
  }
  
  void slurp(Mover m) {
    float distance = torusPointer(m.location, location).mag();
    if (distance <= radius + m.radius && mass > m.mass * NOMFACTOR) {
      float slurp = 0;
      
      if (m.mass <= mass/25) slurp = m.mass;
      else slurp = mass/25;
      if (mass + slurp > DIVSIZE*1.5) slurp = DIVSIZE*1.5 - mass + 1;
      
      m.mass -= slurp;
      mass += slurp;
      m.radius = sqrt(m.mass/PI);
    }
  }
  
  void considerP(Plant m) {
    PVector pointer = torusPointer(m.location, location);
    float distance = pointer.mag();
    distance = constrain(distance, 5.0, 3000.0);
    
    //AI decision
    float strength = m.mass/pow(distance, 2)/4;
    
    //Set importance of target
    pointer.setMag(strength);
    //Add new desired location
    if (strength != 0) addTarget(pointer, strength);
  }
  
  void slurpP(Plant m) {
    float distance = torusPointer(m.location, location).mag();
    if (distance <= radius + m.radius) {
      float slurp = 0;
      
      if (m.mass <= mass/30) slurp = m.mass;
      else slurp = mass/30;
      if (mass + slurp > DIVSIZE*1.5) slurp = DIVSIZE*1.5 - mass + 1;
      
      m.mass -= slurp;
      mass += slurp*0.3;
      m.radius = sqrt(m.mass/PI);
    }
  }
  
  void divide() {
    PVector split = new PVector(velocity.y, -velocity.x);
    split.mult(1);
    
    movers.add(new Mover(mass*0.5, location.x, location.y, PVector.add(velocity, split)));
    
    split.mult(-1);
    velocity.add(split);
    mass *= 0.5;
    radius = sqrt(mass/PI);
  }
  
  //Find the shortest path between 2 objects on torus
  PVector torusPointer(PVector p1, PVector p2) {
    float x, y;
    
    //Determine x
    if (p1.x - p2.x <= (sWidth) - abs(p1.x - p2.x)) {
      x = p1.x - p2.x;
    }
    else {
      x = (sWidth) - abs(p1.x - p2.x);
      if (p1.x - p2.x > 0) x *= -1;
    }
    
    //Determine y
    if (p1.y - p2.y <= (sHeight) - abs(p1.y - p2.y)) {
      y = p1.y - p2.y;
    }
    else {
      y = (sHeight) - abs(p1.y - p2.y);
      if (p1.y - p2.y > 0) y *= -1;
    }
    
    return new PVector(x, y);
  }
  
  //Display toriod ghost if applicable
  void displayGhost() {
    if (ghostX != 0 || ghostY != 0) {
      int xShift = ghostX * sWidth;
      int yShift = ghostY * sHeight;
      
      radius = sqrt(mass/PI);
      stroke(0);
      strokeWeight(2);
      fill(150 - 100*(mass/DIVSIZE), 200);
      ellipse(location.x+xShift, location.y+yShift, radius, radius);
      line(location.x+xShift, location.y+yShift, location.x+xShift+noseEnd.x, location.y+yShift+noseEnd.y);
    }
  }
  
  //Makes sketch even more torrific than before :D
  void torify() {
    if (location.x <= BORDERSIZE) {
      ghostX = 1;
      if (location.x <= 0) {
        location.x += sWidth;
        ghostX = -1;
      }
    }
    else if (location.x >= sWidth - BORDERSIZE) {
      ghostX = -1;
      if (location.x >= sWidth) {
        location.x -= sWidth;
        ghostX = 1;
      }
    }
    else ghostX = 0;
    
    if (location.y <= BORDERSIZE) {
      ghostY = 1;
      if (location.y <= 0) {
        location.y += sHeight;
        ghostY = -1;
      }
    }
    else if (location.y >= sHeight - BORDERSIZE) {
      ghostY = -1;
      if (location.y >= sHeight) {
        location.y -= sHeight;
        ghostY = 1;
      }
    }
    else ghostY = 0;
  }
}
class Plant {

  PVector location;
  float radius;
  float mass;
  
  Plant(float m, float x, float y) {
    mass = m;
    radius = sqrt(m/PI);
    location = new PVector(x, y);
  }
  
  boolean update() {
    if (mass < 20) return true; //Self-destruct
    
    //Growth limitation
    if (mass < DIVSIZE*2) mass *= growthRate;
    else {
      float g = map(mass, DIVSIZE*2, 10000, 0, growthRate-1);
      mass *= growthRate - g;
    }
  
    radius = sqrt(mass/PI);
    return false;
  }

  void display() {
    radius = sqrt(mass/PI);
    stroke(43, 71, 20);
    strokeWeight(2);
    fill(93, 156, 51, 240);
    ellipse(location.x, location.y, radius, radius);
  }
}
public class UiButton {
  float x, y, width, height;
  String s;
  boolean pressed;
  
  public UiButton ( float xx, float yy, float w, float h, String s ) {
    x = xx; y = yy; width = w; height = h; this.s = s; pressed = false;
    Interactive.add( this );
  }
  
  
  public void mousePressed ( float mx, float my ) {
    //Resets simulation when button is pressed
    movers = new ArrayList<Mover>();
    for (int i = 0; i < moversCtrl.value*100; i++) movers.add(new Mover(random(DIVSIZE/3,DIVSIZE*1.1),random(sWidth),random(sHeight)));
    plants = new ArrayList<Plant>();
    for (int i = 0; i < plantsCtrl.value*10; i++) plants.add(new Plant(random(100, 500),random(width-BORDERSIZE*2)+BORDERSIZE,random(sHeight-BORDERSIZE*2)+BORDERSIZE));
    metabolismRate = moversMCtrl.value;
    growthRate = plantsMCtrl.value;
    graph.reset();
    
    pressed = true;
  }

  void draw () {
    if ( !mousePressed ) pressed = false;
    
    if ( !pressed ) fill( 128 );
    else fill( 80 );
    
    rect( x, y, width, height, (width+height)/2/10 );
    fill( 0 );
    textSize( 30 );
    textAlign( CENTER, CENTER );
    if ( pressed ) text( s, x+width/2, y+height/2);
    else text( s, x+width/2, y+height/2);
  }
}
public class UiGrapherII{
  int x, y, w, h;
  String title;
  
  float[] pointsA, pointsB;
  int pNA, pNB; //Number of points ready for plotting
  float max, min;
  
  //Layout Vars
  int edge = 25;
  int titleEdge = 30;
  int numberEdge = 30;
  
  UiGrapherII(int x, int y, int w, int h, String title) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.title = title;
    
    pointsA = new float[w - edge - numberEdge];
    pNA = 0;
    pointsB = new float[w - edge - numberEdge];
    pNB = 0;
    max = 0;
    min = 0;
  }
  
  void plotA (float p){
    for (int i = pointsA.length-1; i > 0; i--) {
      pointsA[i] = pointsA[i-1];
    }
    pointsA[0] = p;
    if (p > max) max = p;
    if (p < min) min = p;
    
    if (pNA < pointsA.length){
      pNA++;
    }
  }
  
  void plotB (float p){
    for (int i = pointsB.length-1; i > 0; i--) {
      pointsB[i] = pointsB[i-1];
    }
    pointsB[0] = p;
    if (p > max) max = p;
    if (p < min) min = p;
    
    if (pNB < pointsB.length){
      pNB++;
    }
  }
  
  void render(){
    fill(173, 117, 77);
    rect(x, y, w, h);
    stroke(0);
    strokeWeight(3);
    //Draws graphs
    for (int i = 0; i < pNA-1; i++) {
      line(x+numberEdge+i, getPosA(i), x+numberEdge+(i+1), getPosA(i+1));
    }
    stroke(66, 110, 36);
    for (int i = 0; i < pNB-1; i++) {
      line(x+numberEdge+i, getPosB(i), x+numberEdge+(i+1), getPosB(i+1));
    }
    stroke(0);
    strokeWeight(1);
    line(x+numberEdge, y+titleEdge, x+numberEdge, y+h-edge);
    line(x+numberEdge, y+h-edge, x+w-edge, y+h-edge);
    
    
    fill(0);
    textSize( 20 );
    textAlign( CENTER, CENTER );
    text(title, x+w/2, y+titleEdge/2);
    textSize( 15 );
    text(round(max), x+numberEdge, y+titleEdge/2);
    text(round(min), x+numberEdge, y+h-edge/2);
  }
    
  int getPosA(int i) {
      float n = map(pointsA[i], min, max, 0, h-edge-titleEdge);
      n *= -1;
      n += x + h - edge;
      
      return round(n);
  }
    
  int getPosB(int i) {
    float n = map(pointsB[i], min, max, 0, h-edge-titleEdge);
    n *= -1;
    n += x + h - edge;
    
    return round(n);
  }
  
  void reset() {
    pointsA = new float[w - edge - numberEdge];
    pNA = 0;
    pointsB = new float[w - edge - numberEdge];
    pNB = 0;
    max = 0;
    min = 0; 
  }
}
public class UiSlider
{
  float x, y, width, height;
  float valueX = 0, value, mult;
  color bar;
  color button;
  float buttonW;
  
  public UiSlider ( float xx, float yy, float ww, float hh, float value, float mult, float buttonW) 
  {
    x = xx; 
    y = yy; 
    width = ww; 
    height = hh;
    
    this.mult = mult;
    this.value = value;
    if (mult > 0) {
      valueX  = map( value, 0, 1, x, x+width-buttonW );
      
    }
    else if (mult == -1){
      valueX = map( value, .95, 1, x, x+width-buttonW );
    }
    else {
      valueX = map( value, 1, 1.05, x, x+width-buttonW );
    }
    
    // register it
    Interactive.add( this );
    
    bar = color(128);
    button = color(190);
    this.buttonW = buttonW;
  }
  
  // called from manager
  void mouseDragged ( float mx, float my ) { update(mx, my); }
  void mousePressed ( float mx, float my ) { update(mx, my); }
  
  //Called when mouse clicked or dragged
  void update ( float mx, float my ) {
    valueX = mx - buttonW/2;
    
    if ( valueX < x ) valueX = x;
    if ( valueX > x+width-buttonW ) valueX = x+width-buttonW;
    
    if (mult > 0)
      value = map( valueX, x, x+width-buttonW, 0, 1 );
    else if(mult == -1)
      value = getMR();
    else
      value = getGR();
  }

  public void draw () 
  {
    float f = 0.75; //How much smaller rail bar is
    stroke(0);
    fill( bar );
    rect(x, y + (1-f)*height/2, width, height*f );
    
    stroke(0);
    fill( button );
    rect( valueX, y, buttonW , height );
    
    textSize( 20 );
    textAlign( CENTER, CENTER );
    fill(0);
    if (mult > 0)
      text( round(value*mult), valueX+buttonW/2, y+height/2);
    else if (mult == -1)
      text( getMR(), valueX+buttonW/2, y+height/2);
    else
      text( getGR(), valueX+buttonW/2, y+height/2);
  }
  
  //Specific cases
  float getMR() {
    return 0.95+round(map( valueX, x, x+width-buttonW, 0, 50 )) * .001;
  }
  
  float getGR() {
    return 1+round(map( valueX, x, x+width-buttonW, 0, 50 )) * .001;
  }
}

