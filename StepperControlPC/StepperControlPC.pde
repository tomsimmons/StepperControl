/* Stepper motor control
 *  Control program for the Arduino driver
 *  Sends commands via serial
 *
 *  Coded by Thomas Simmons
 *  Modified 2015-04
 */


import processing.serial.*;  // for serial input, from the Arduino
import controlP5.*;          // for GUI stuff

// Serial object, represents the serial port
Serial myPort;
// Boolean switch to indicate connection all good
boolean conn = false;
// millis timer to determine error text flash frequency, along with error markers
//  [flash millis, dist err, reps err, delay err]
int[] errors = {0,0,0,0};
// The interface object
ControlP5 cp5;
// Color value to indicate direction
color counterColor = color(0,0,0);
// Boolean to determine clockwise-ness
boolean antiCW = false;
// Para debuguir
int counter = 0;

void setup() {
  size(600, 320); // square canvas + space for color indication rectangle
  smooth();       // nicer drawing (less jagged)
  
  // ControlP5 GUI object
  cp5 = new ControlP5(this);
  
  // Distance textbox
  cp5.addTextfield("distEntry")
     .setPosition(95,50)
     .setSize(200,40)
     .setFont(createFont("arial",20))
     .setCaptionLabel("")
     .setText("0")
     .setAutoClear(false)
     ;
  // Distance units dropdown
  DropdownList ddl = 
  cp5.addDropdownList("distUnits")
     .setPosition(300,85)
     .setSize(100,75)
     .setItemHeight(25)
     .setBarHeight(25)
     .setLabel("in")
     ;
  // Add unit items
  ddl.addItem("in",0);
  ddl.addItem("cm",1);
  ddl.setWidth(50);
  // Repetitions textbox
  cp5.addTextfield("repsEntry")
     .setPosition(95,110)
     .setSize(200,40)
     .setFont(createFont("arial",20))
     .setCaptionLabel("")
     .setText("0")
     .setAutoClear(false)
     ;
  // Delay textbox
  cp5.addTextfield("delayEntry")
     .setPosition(95,170)
     .setSize(200,40)
     .setFont(createFont("arial",20))
     .setCaptionLabel("")
     .setText("0")
     .setAutoClear(false)
     ;
  // Clockwise toggle
  cp5.addToggle("clockwise")
     .setPosition(100,260)
     .setSize(50,20)
     .setValue(false)
     .setMode(ControlP5.SWITCH)
     .setValueLabel("")
     ;
  // Submit button
  cp5.addBang("send")
     .setPosition(420,110)
     .setSize(80,40)
     .getCaptionLabel().align(ControlP5.CENTER, ControlP5.CENTER)
     ;
  // Halt button
  cp5.addBang("halt")
     .setPosition(420,170)
     .setSize(80,40)
     .getCaptionLabel().align(ControlP5.CENTER, ControlP5.CENTER)
     ;
  
  
  // open the serial port from the Arduino
  // NOTE: this assumes it is the first entry in the list of ports
  if (Serial.list().length < 1)
  {
    println("Error!  No serial ports detected!");
    exit();
    return; // exit() doesn't actually exit until setup() returns
  }
  println(Serial.list());  // list all ports, for debugging
  try
  {
    String portName = Serial.list()[1];
    myPort = new Serial(this, portName, 9600);  // connect at 9600 baud
    println("Using serial port: " + portName);  // debugging
    conn = true;
  }
  catch (IndexOutOfBoundsException e)
  {
    println("Arduino not found");
  }
}


// equivalent to loop() in Arduino code
void draw() {
  background(0);
  drawText(conn);
  
  if (!conn)
  {
    if (Serial.list().length > 1)
    {
      try
      {
        String portName = Serial.list()[1];
        myPort = new Serial(this, portName, 9600);  // connect at 9600 baud
        println("Using serial port: " + portName);  // debugging
        conn = true;
      }
      catch (IndexOutOfBoundsException e)
      {
        println("Arduino not found");
      }
    }
  }
  else if (conn && myPort.available() > 0)
  {
    // See 'Duino response
    String response = myPort.readString();
    println(response);
  }
  
}


// Event controller for the direction toggle switch
public void clockwise(boolean cw)
{
  // On clockwise toggle, notify user
  if (!cw)
  {
    counterColor = color(0,0,0); // Hide "counter-"
    antiCW = false;
  }
  else
  {
    counterColor = color(255,255,255); // Show "counter-"
    antiCW = true;
  } 
}

// Event controller for the wise guy that presses "enter" in the text field
public void distEntry(String theText)
{
  send();
}

// Event controller for the send button
public void send()
{
  // Gather all values entered so far
  // Distance
  float distance;
  try
  {
    distance = Float.parseFloat(cp5.get(Textfield.class,"distEntry").getText());
    errors[1] = 0;
  }
  catch (NumberFormatException e)
  {
    errors[0] = millis();
    errors[1] = 1;
    println("Invalid distance entered");
    distance = 0.0;
  }
  // Cast units to int: 0=in, 1=cm
  int distUnits = (int) cp5.get(DropdownList.class,"distUnits").getValue();
  
  // Calculate the number of steps to take
  // First, if working in metric, convert to inches
  if (distUnits == 1) distance = distance / 2.54;
  // Assume 360 degrees per 1/20 of an inch. 1 step = 1 degree
  int steps = (int)(distance * 20.0 * 360.0 / 1.8);
  
  // Repetitions
  int repetitions;
  try
  {
    repetitions = Integer.parseInt(cp5.get(Textfield.class,"repsEntry").getText());
    errors[2] = 0;
  }
  catch (NumberFormatException e)
  {
    errors[0] = millis();
    errors[2] = 1;
    println("Invalid repetitions entered");
    repetitions = 0;
  }
  
  // Delay
  int delay;
  try
  {
    delay = (int) (Float.parseFloat(cp5.get(Textfield.class,"delayEntry").getText()) * 1000);
    errors[3] = 0;
  }
  catch (NumberFormatException e)
  {
    errors[0] = millis();
    errors[3] = 1;
    println("Invalid delay entered");
    delay = 0;
  }
  
  
  // Debugging output
  println("The distance was " + distance + "in, which is " + steps + " steps");
  println("You requested " + repetitions + " repetitions");
  println("with a delay of " + delay + " ms");
  println("in a " + (antiCW ? "counter-" : "") + "clockwise direction");
  
  // Now we get to the actual sending part, if no errors
  if ((errors[1] | errors[2] | errors[3]) == 0)
  {
    //println("Fire away");
    // Send rotation direction
    myPort.write(antiCW ? "ca$" : "cc$");
    // Send the movement amount
    myPort.write("m$"); myPort.write(Integer.toString(steps));
    // Send the number of repetitions to take
    myPort.write("r$"); myPort.write(Integer.toString(repetitions));
    // Send the delay between 
    myPort.write("d$"); myPort.write(Integer.toString(delay));
  }
}

// Halt function to stop any stepper movement
public void halt()
{
  // Send the halt signal to the Arduino
  myPort.write("h");
}

// Draw the non-CP5 GUI elements
void drawText(boolean connStatus)
{
  // Move label
  fill(0xffffffff);
  textSize(32);
  text("Move",20,35);
  rect(20,40,275,5);
  
  // Draw connection status box
  fill( (connStatus ? color(0,255,0) : color(255,0,0)) );
  noStroke();
  rect(440,27,15,15);
  
  fill(0xffffff00);
  textSize(20);
  // Connection status label
  text("Connection:",320,40);
  textSize(24);
  // Text box labels, flash red if incorrect value
  boolean flash = ((millis()-errors[0]) % 1000) < 500; // Flash at 2Hz 
  fill((errors[1] == 1 && flash) ? 0xffff0000 : 0xffffff00);
    text("Dist:",20,80);
  fill((errors[2] == 1 && flash) ? 0xffff0000 : 0xffffff00);
    text("Reps:",20,137);
  fill((errors[3] == 1 && flash) ? 0xffff0000 : 0xffffff00);
    text("Delay:",20,200);
  fill(0xffffff00); text("s",300,200);
  
  
  // (counter-)clockwise indicator
  fill(counterColor);
  text("counter-",20,250);
  fill(0xffffffff);
  text("clockwise",125,250);
}

