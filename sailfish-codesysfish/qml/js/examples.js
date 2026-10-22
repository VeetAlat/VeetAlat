.pragma library

// The example projects CodeSysFish starts with, and the new-project
// template. Each compiles without errors or warnings (tests/test_examples.js).

var TEMPLATE = "PROGRAM PLC_PRG\n" +
    "VAR\n" +
    "    count : INT;\n" +
    "END_VAR\n" +
    "\n" +
    "count := count + 1;\n" +
    "\n" +
    "END_PROGRAM\n"

var projects = [
    { name: "Blinker",
      description: "A lamp that blinks every half second, with a TON timer",
      source:
"(* Blinker: the classic first PLC program.\n" +
"   A TON timer restarts itself every 500 ms and the lamp toggles.\n" +
"   Run it and watch lamp and blinks in the online view. *)\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    pulse : TON;           // the timer\n" +
"    lamp : BOOL;           // the output\n" +
"    blinks : INT;          // how many times it has toggled\n" +
"    period : TIME := T#500MS;\n" +
"END_VAR\n" +
"\n" +
"pulse(IN := NOT pulse.Q, PT := period);\n" +
"\n" +
"IF pulse.Q THEN\n" +
"    lamp := NOT lamp;\n" +
"    blinks := blinks + 1;\n" +
"END_IF\n" +
"\n" +
"END_PROGRAM\n" },

    { name: "Traffic light",
      description: "A state machine with an enum, CASE and timers; press the button",
      source:
"(* Traffic light: a state machine.\n" +
"   Each state lasts its own time. Set button to TRUE in the online\n" +
"   view, like a pedestrian pressing it: green ends early. *)\n" +
"TYPE\n" +
"    Phase : (Red, RedYellow, Green, Yellow);\n" +
"END_TYPE\n" +
"\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    phase : Phase := Red;\n" +
"    timer : TON;\n" +
"    button : BOOL;        // set it in the online view\n" +
"    redLamp, yellowLamp, greenLamp : BOOL;\n" +
"    cycles : INT;\n" +
"END_VAR\n" +
"VAR CONSTANT\n" +
"    RED_TIME : TIME := T#4S;\n" +
"    CHANGE_TIME : TIME := T#1S;\n" +
"    GREEN_TIME : TIME := T#6S;\n" +
"END_VAR\n" +
"\n" +
"CASE phase OF\n" +
"    Red:\n" +
"        timer(IN := TRUE, PT := RED_TIME);\n" +
"        IF timer.Q THEN\n" +
"            phase := RedYellow;\n" +
"            timer(IN := FALSE);\n" +
"        END_IF\n" +
"\n" +
"    RedYellow:\n" +
"        timer(IN := TRUE, PT := CHANGE_TIME);\n" +
"        IF timer.Q THEN\n" +
"            phase := Green;\n" +
"            timer(IN := FALSE);\n" +
"        END_IF\n" +
"\n" +
"    Green:\n" +
"        timer(IN := TRUE, PT := GREEN_TIME);\n" +
"        IF timer.Q OR (button AND timer.ET > T#2S) THEN\n" +
"            phase := Yellow;\n" +
"            button := FALSE;\n" +
"            timer(IN := FALSE);\n" +
"        END_IF\n" +
"\n" +
"    Yellow:\n" +
"        timer(IN := TRUE, PT := CHANGE_TIME);\n" +
"        IF timer.Q THEN\n" +
"            phase := Red;\n" +
"            cycles := cycles + 1;\n" +
"            timer(IN := FALSE);\n" +
"        END_IF\n" +
"END_CASE\n" +
"\n" +
"redLamp := phase = Red OR phase = RedYellow;\n" +
"yellowLamp := phase = RedYellow OR phase = Yellow;\n" +
"greenLamp := phase = Green;\n" +
"\n" +
"END_PROGRAM\n" },

    { name: "Tank level",
      description: "A simulated tank with a pump, hysteresis and an alarm, in a FUNCTION_BLOCK",
      source:
"(* Tank level control.\n" +
"   The Tank function block simulates the water: the pump fills it,\n" +
"   the outlet drains it. The program keeps the level between 20 and\n" +
"   80 % (hysteresis). Open the outlet wider (outletOpen, 0..100) or\n" +
"   turn auto off and on in the online view. *)\n" +
"FUNCTION_BLOCK Tank\n" +
"VAR_INPUT\n" +
"    pumpOn : BOOL;\n" +
"    outletOpen : REAL;     // 0..100 %\n" +
"    cycleTime : TIME;\n" +
"END_VAR\n" +
"VAR_OUTPUT\n" +
"    level : REAL := 50.0;  // 0..100 %\n" +
"END_VAR\n" +
"VAR\n" +
"    seconds : REAL;\n" +
"END_VAR\n" +
"\n" +
"seconds := TIME_TO_REAL(cycleTime) / 1000.0;\n" +
"IF pumpOn THEN\n" +
"    level := level + 8.0 * seconds;\n" +
"END_IF\n" +
"level := level - 0.06 * outletOpen * seconds;\n" +
"level := LIMIT(0.0, level, 100.0);\n" +
"\n" +
"END_FUNCTION_BLOCK\n" +
"\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    tank : Tank;\n" +
"    auto : BOOL := TRUE;\n" +
"    pump : BOOL;\n" +
"    outletOpen : REAL := 50.0;\n" +
"    low : REAL := 20.0;\n" +
"    high : REAL := 80.0;\n" +
"    alarmDelay : TON;\n" +
"    alarm : BOOL;\n" +
"    pumpStarts : CTU;\n" +
"    lastCall : TIME;\n" +
"    now : TIME;\n" +
"END_VAR\n" +
"\n" +
"now := TIME();\n" +
"\n" +
"IF auto THEN\n" +
"    IF tank.level <= low THEN\n" +
"        pump := TRUE;\n" +
"    ELSIF tank.level >= high THEN\n" +
"        pump := FALSE;\n" +
"    END_IF\n" +
"ELSE\n" +
"    pump := FALSE;\n" +
"END_IF\n" +
"\n" +
"tank(pumpOn := pump, outletOpen := outletOpen, cycleTime := now - lastCall);\n" +
"lastCall := now;\n" +
"\n" +
"pumpStarts(CU := pump, RESET := NOT auto, PV := 1000);\n" +
"\n" +
"// Alarm when the tank stays nearly empty for 5 seconds.\n" +
"alarmDelay(IN := tank.level < 5.0, PT := T#5S);\n" +
"alarm := alarmDelay.Q;\n" +
"\n" +
"END_PROGRAM\n" },

    { name: "Box counter",
      description: "Counts boxes on a conveyor with R_TRIG and CTU, and packs them",
      source:
"(* Box counter.\n" +
"   A light barrier (sensor) sees a box pass every 700 ms. R_TRIG turns\n" +
"   each pass into one count, CTU counts a batch of 6, then the batch is\n" +
"   packed and counting starts again. *)\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    sensorClock : TON;\n" +
"    sensor : BOOL;\n" +
"    edge : R_TRIG;\n" +
"    counter : CTU;\n" +
"    batchSize : INT := 6;\n" +
"    batches : INT;\n" +
"    totalBoxes : DINT;\n" +
"    message : STRING;\n" +
"END_VAR\n" +
"\n" +
"// Simulate the sensor: a short pulse every 700 ms.\n" +
"sensorClock(IN := NOT sensorClock.Q, PT := T#700MS);\n" +
"sensor := sensorClock.ET < T#100MS;\n" +
"\n" +
"edge(CLK := sensor);\n" +
"IF edge.Q THEN\n" +
"    totalBoxes := totalBoxes + 1;\n" +
"END_IF\n" +
"\n" +
"counter(CU := edge.Q, RESET := counter.Q, PV := batchSize);\n" +
"IF counter.Q THEN\n" +
"    batches := batches + 1;\n" +
"END_IF\n" +
"\n" +
"message := CONCAT('Batch ', INT_TO_STRING(batches + 1), ': ',\n" +
"                  INT_TO_STRING(counter.CV), '/', INT_TO_STRING(batchSize));\n" +
"\n" +
"END_PROGRAM\n" },

    { name: "Arrays and functions",
      description: "Samples a signal into an array, sorts it and finds the average",
      source:
"(* Arrays and functions.\n" +
"   Every cycle a sine wave is sampled into a ring buffer of 10 values.\n" +
"   A FUNCTION works out the average, a FUNCTION_BLOCK sorts a copy\n" +
"   with bubble sort and gives the median. *)\n" +
"TYPE\n" +
"    Samples : ARRAY[1..10] OF REAL;\n" +
"END_TYPE\n" +
"\n" +
"FUNCTION Average : REAL\n" +
"VAR_IN_OUT\n" +
"    values : Samples;\n" +
"END_VAR\n" +
"VAR\n" +
"    i : INT;\n" +
"    sum : REAL;\n" +
"END_VAR\n" +
"\n" +
"FOR i := 1 TO 10 DO\n" +
"    sum := sum + values[i];\n" +
"END_FOR\n" +
"Average := sum / 10.0;\n" +
"\n" +
"END_FUNCTION\n" +
"\n" +
"FUNCTION_BLOCK Sorter\n" +
"VAR_INPUT\n" +
"    input : Samples;\n" +
"END_VAR\n" +
"VAR_OUTPUT\n" +
"    sorted : Samples;\n" +
"    median : REAL;\n" +
"END_VAR\n" +
"VAR\n" +
"    i, j : INT;\n" +
"    swap : REAL;\n" +
"END_VAR\n" +
"\n" +
"sorted := input;\n" +
"FOR i := 1 TO 9 DO\n" +
"    FOR j := 1 TO 10 - i DO\n" +
"        IF sorted[j] > sorted[j + 1] THEN\n" +
"            swap := sorted[j];\n" +
"            sorted[j] := sorted[j + 1];\n" +
"            sorted[j + 1] := swap;\n" +
"        END_IF\n" +
"    END_FOR\n" +
"END_FOR\n" +
"median := (sorted[5] + sorted[6]) / 2.0;\n" +
"\n" +
"END_FUNCTION_BLOCK\n" +
"\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    buffer : Samples;\n" +
"    next : INT := 1;\n" +
"    seconds : REAL;\n" +
"    mean : REAL;\n" +
"    sorter : Sorter;\n" +
"    median : REAL;\n" +
"END_VAR\n" +
"\n" +
"seconds := TIME_TO_REAL(TIME()) / 1000.0;\n" +
"buffer[next] := 10.0 * SIN(seconds) + 0.5 * INT_TO_REAL(next);\n" +
"next := next MOD 10 + 1;\n" +
"\n" +
"mean := Average(buffer);\n" +
"sorter(input := buffer);\n" +
"median := sorter.median;\n" +
"\n" +
"END_PROGRAM\n" }
]
