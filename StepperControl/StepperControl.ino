/* Linear stage driver
 *  An Arduino control program for a stepper motor
 *  Takes input via serial from PC
 *
 *  Coded by Thomas Simmons
 *  Modified 2015-04
 */


// TODO: figure max control seq, change this to ByteBuffer
// Input buffer
String controlBytes;
// Movement boolean
boolean moving;
// Direction boolean
boolean antiCW;
// Distance in steps, number of steps taken
unsigned long distance, steps;
// Number of repetitions
unsigned long repetitions;
// Amount of delay between repetitions
unsigned long delayAmt;

void setup() {
  Serial.begin(9600);
  
  // Start in a stopped state
  moving = true;
  // Current distance to move is 0
  distance = steps = 0;
  // No reps, no gainz
  repetitions = 0;
  // Delay amount is nada
  delayAmt = 0;
  
  // Clock pin, High/Low transition steps
  pinMode(12, OUTPUT);
  // Clockwise pin, HIGH CW, LOW antiCW
  pinMode(13, OUTPUT);
  // Default to clockwise, HIGH on CW+ pin
  antiCW = false;
}

void loop() {
  // Set the direction
  digitalWrite(13, antiCW ? LOW : HIGH);
  // Take some steps
  if (moving)
  {
    if (steps < distance)
    {
      // Take one step, pulse the clock
      digitalWrite(12, HIGH);
      delay(25);
      digitalWrite(12, LOW);
      // We've taken a step, let it be so
      steps++;
      
    }
    else
    {
      if (repetitions > 0 || repetitions == -1)
      {
        // Incur delay if we are between reps at the origin
        if (repetitions+1 % 2 == 0) delay(delayAmt);
        antiCW = !antiCW; // Reverse direction
        steps = 0;        // Reset distance travelled
        repetitions--;    // We've reversed one more time
      }
      else moving = false;
    }
  }
  
  while (Serial.available() > 0)
  {
    controlBytes = Serial.readStringUntil('$');
    
    switch (controlBytes[0])
    {
    case 'h':
      // Stop any movement
      moving = false;
      break;
    case 'c':
      // If low on rot. dir. pin, counterclockwise
      antiCW = (controlBytes[1] == 'a') ? true : false;
      Serial.write((antiCW) ? 'T' : 'F'); // Debugging ACKs
      break;
    case 'm':
      // We are moving now
      moving = true;
      // How far though?
      distance = Serial.parseInt();
      steps = 0;
      break;
    case 'r':
      // Number of reps
      repetitions = Serial.parseInt();
      // The repetition code in the main loop counts each rep as one movement,
      //  so to count cycles we double the # of reps (if not on repeat)
      if (repetitions != -1) reptitions = (repetitions * 2) - 1;
      break;
    case 'd':
      // The delay amount, in ms
      delayAmt = Serial.parseInt();
      break;
    default:
      // Let the user know we had an error
      Serial.write('E');
    }
    //Serial.print("Here");
  }
  
  
}
