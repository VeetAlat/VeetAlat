.pragma library

// The ST reference shown in the app: what CodeSysFish understands. Every
// code sample is a whole program that compiles (tests/test_examples.js).

var sections = [
    { title: "A program",
      text: "Code lives in POUs (program organisation units). The PLC runs PLC_PRG (or, if there's none, " +
            "the first PROGRAM) over and over, once every cycle. Variables keep their values from one " +
            "cycle to the next. Names ignore case: Count and COUNT are the same.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    counter : INT;        // starts at 0\n" +
"    running : BOOL := TRUE;\n" +
"END_VAR\n" +
"\n" +
"IF running THEN\n" +
"    counter := counter + 1;\n" +
"END_IF\n" +
"END_PROGRAM" },

    { title: "Types",
      text: "BOOL (TRUE/FALSE). Whole numbers: SINT, INT, DINT, LINT (signed, 8/16/32/64 bits), " +
            "USINT, UINT, UDINT, ULINT (unsigned), BYTE, WORD, DWORD, LWORD (bit strings). " +
            "They wrap around like on a PLC: an INT goes from -32768 to 32767. " +
            "REAL and LREAL (decimals), TIME (milliseconds), STRING (up to 80 characters, or STRING(n)). " +
            "Arrays: ARRAY[1..10] OF INT, also ARRAY[0..2, 0..3] OF REAL.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    small : SINT := -100;\n" +
"    flags : BYTE := 2#1010_0101;\n" +
"    speed : REAL := 12.5;\n" +
"    delay : TIME := T#1S500MS;\n" +
"    name : STRING(20) := 'Pump 1';\n" +
"    levels : ARRAY[1..5] OF INT := [10, 20, 3(0)];\n" +
"    grid : ARRAY[0..1, 0..2] OF INT;\n" +
"END_VAR\n" +
"VAR CONSTANT\n" +
"    MAX_SPEED : REAL := 100.0;\n" +
"END_VAR\n" +
"\n" +
"grid[1, 2] := levels[2];\n" +
"speed := MIN(speed, MAX_SPEED);\n" +
"END_PROGRAM" },

    { title: "Values",
      text: "Numbers: 42, -7, 1_000_000, 16#FF (hex), 2#1010 (binary), 8#17 (octal), 1.5, 2.5E3. " +
            "Typed: INT#5, REAL#1.5. Times: T#1s, T#250ms, T#1h30m, T#1.5s, TIME#2m. " +
            "Strings in single quotes: 'text', with $' for a quote, $$ for a dollar and $N for a new line.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    mask : WORD;\n" +
"    t : TIME;\n" +
"    s : STRING;\n" +
"END_VAR\n" +
"\n" +
"mask := 16#00FF;\n" +
"t := T#1M30S;\n" +
"s := 'It$'s 5 $$';\n" +
"END_PROGRAM" },

    { title: "Operators",
      text: "From the strongest: ( ), function calls, - and NOT, ** (power), * / MOD, + -, " +
            "< > <= >=, = <>, AND (or &), XOR, OR. AND_THEN and OR_ELSE skip the right side when " +
            "the left decides. Whole numbers divide whole: 7 / 2 is 3. Assign with :=; " +
            "x S= cond sets x when cond is TRUE, x R= cond resets it.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    a : INT := 7;\n" +
"    b : INT := 2;\n" +
"    q, r : INT;\n" +
"    x : REAL;\n" +
"    alarm, ack : BOOL;\n" +
"END_VAR\n" +
"\n" +
"q := a / b;              // 3\n" +
"r := a MOD b;            // 1\n" +
"x := INT_TO_REAL(a) / 2.0;   // 3.5\n" +
"alarm S= a > 5;\n" +
"alarm R= ack;\n" +
"END_PROGRAM" },

    { title: "IF and CASE",
      text: "IF ... THEN ... ELSIF ... THEN ... ELSE ... END_IF. CASE picks by a whole number or " +
            "an enum, with single values, lists (1, 2) and ranges (3..5), and ELSE for the rest.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    temperature : REAL := 21.0;\n" +
"    heating : BOOL;\n" +
"    step : INT := 1;\n" +
"    text : STRING;\n" +
"END_VAR\n" +
"\n" +
"IF temperature < 19.0 THEN\n" +
"    heating := TRUE;\n" +
"ELSIF temperature > 22.0 THEN\n" +
"    heating := FALSE;\n" +
"END_IF\n" +
"\n" +
"CASE step OF\n" +
"    0: text := 'idle';\n" +
"    1, 2: text := 'starting';\n" +
"    3..9: text := 'running';\n" +
"ELSE\n" +
"    text := 'unknown';\n" +
"END_CASE\n" +
"END_PROGRAM" },

    { title: "Loops",
      text: "FOR i := a TO b BY step DO ... END_FOR, WHILE cond DO ... END_WHILE, " +
            "REPEAT ... UNTIL cond END_REPEAT. EXIT leaves a loop, CONTINUE goes to its next round. " +
            "A whole cycle must end: an endless loop is stopped by the watchdog after a second.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    values : ARRAY[1..10] OF INT;\n" +
"    i, sum, found : INT;\n" +
"END_VAR\n" +
"\n" +
"sum := 0;\n" +
"FOR i := 1 TO 10 DO\n" +
"    values[i] := i * i;\n" +
"    sum := sum + values[i];\n" +
"END_FOR\n" +
"\n" +
"i := 1;\n" +
"WHILE i <= 10 DO\n" +
"    IF values[i] > 20 THEN\n" +
"        found := i;\n" +
"        EXIT;\n" +
"    END_IF\n" +
"    i := i + 1;\n" +
"END_WHILE\n" +
"END_PROGRAM" },

    { title: "Functions and function blocks",
      text: "A FUNCTION gives one value and keeps nothing between calls. A FUNCTION_BLOCK is a type: " +
            "each instance keeps its own variables. Call one on its own line with its inputs " +
            "(name := value), then read its outputs (instance.output), or take them with =>. " +
            "VAR_IN_OUT passes a variable itself, so the POU can change it.",
      code:
"FUNCTION Scale : REAL\n" +
"VAR_INPUT\n" +
"    raw : INT;\n" +
"    max : REAL := 100.0;\n" +
"END_VAR\n" +
"Scale := INT_TO_REAL(raw) / 32767.0 * max;\n" +
"END_FUNCTION\n" +
"\n" +
"FUNCTION_BLOCK Hysteresis\n" +
"VAR_INPUT\n" +
"    value, low, high : REAL;\n" +
"END_VAR\n" +
"VAR_OUTPUT\n" +
"    on : BOOL;\n" +
"END_VAR\n" +
"IF value < low THEN\n" +
"    on := TRUE;\n" +
"ELSIF value > high THEN\n" +
"    on := FALSE;\n" +
"END_IF\n" +
"END_FUNCTION_BLOCK\n" +
"\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    sensor : INT := 16000;\n" +
"    level : REAL;\n" +
"    pump : Hysteresis;\n" +
"    pumpOn : BOOL;\n" +
"END_VAR\n" +
"\n" +
"level := Scale(raw := sensor);\n" +
"pump(value := level, low := 20.0, high := 80.0, on => pumpOn);\n" +
"END_PROGRAM" },

    { title: "Timers, edges and counters",
      text: "TON: Q turns TRUE when IN has been TRUE for PT. TOF: Q stays TRUE for PT after IN drops. " +
            "TP: a pulse of PT when IN rises. ET is the elapsed time. R_TRIG and F_TRIG: Q is TRUE " +
            "for one cycle when CLK rises or falls. CTU, CTD and CTUD count edges up to PV (CV is " +
            "the count). SR and RS are set/reset flip-flops (SR: set wins, RS: reset wins).",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    button : BOOL;\n" +
"    delayOn : TON;\n" +
"    pressed : R_TRIG;\n" +
"    presses : CTU;\n" +
"    latch : RS;\n" +
"    light : BOOL;\n" +
"END_VAR\n" +
"\n" +
"delayOn(IN := button, PT := T#2S);\n" +
"pressed(CLK := button);\n" +
"presses(CU := pressed.Q, RESET := FALSE, PV := 5);\n" +
"latch(SET := delayOn.Q, RESET1 := presses.Q);\n" +
"light := latch.Q1;\n" +
"END_PROGRAM" },

    { title: "Standard functions",
      text: "Numbers: ABS, SQRT, LN, LOG, EXP, EXPT, SIN, COS, TAN, ASIN, ACOS, ATAN, TRUNC, " +
            "MIN, MAX, LIMIT(min, value, max), SEL(choice, if FALSE, if TRUE), MUX(k, v0, v1, ...). " +
            "Bits: SHL, SHR, ROL, ROR. Strings: LEN, LEFT, RIGHT, MID(s, length, position), " +
            "CONCAT, INSERT, DELETE, REPLACE, FIND (positions start at 1). TIME() is the PLC's time.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    angle : REAL := 0.5;\n" +
"    y : REAL;\n" +
"    limited : INT;\n" +
"    word1 : WORD := 16#0F0F;\n" +
"    text : STRING;\n" +
"    where : INT;\n" +
"END_VAR\n" +
"\n" +
"y := SIN(angle) * 10.0;\n" +
"limited := LIMIT(0, 150, 100);\n" +
"word1 := SHL(word1, 4);\n" +
"text := CONCAT('Level ', INT_TO_STRING(limited));\n" +
"where := FIND(text, '100');\n" +
"END_PROGRAM" },

    { title: "Conversions",
      text: "X_TO_Y for any two of BOOL, the whole number types, REAL, LREAL, TIME and STRING, " +
            "or just TO_Y. REAL to a whole number rounds (half away from zero); TRUNC cuts. " +
            "Assigning a bigger type to a smaller one, or REAL to a whole number, works but warns.",
      code:
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    r : REAL := 2.5;\n" +
"    i : INT;\n" +
"    d : DINT;\n" +
"    s : STRING;\n" +
"    t : TIME;\n" +
"END_VAR\n" +
"\n" +
"i := REAL_TO_INT(r);      // 3\n" +
"d := TRUNC(r);            // 2\n" +
"s := REAL_TO_STRING(r);   // '2.5'\n" +
"t := DINT_TO_TIME(1500);  // T#1s500ms\n" +
"i := TO_INT('42');\n" +
"END_PROGRAM" },

    { title: "Types of your own",
      text: "In a TYPE ... END_TYPE block: STRUCTs, enums (a list of names, numbered from 0 unless " +
            "given) and new names for types. Use an enum's values plainly (Green) or with its name " +
            "(Light.Green), which is clearer and avoids clashes with variables of the same name.",
      code:
"TYPE\n" +
"    Light : (Red, Yellow, Green);\n" +
"    Motor : STRUCT\n" +
"        speed : REAL;\n" +
"        running : BOOL;\n" +
"        name : STRING := 'M1';\n" +
"    END_STRUCT\n" +
"END_TYPE\n" +
"\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    state : Light := Light.Red;\n" +
"    motors : ARRAY[1..2] OF Motor;\n" +
"END_VAR\n" +
"\n" +
"IF state = Light.Green THEN\n" +
"    motors[1].running := TRUE;\n" +
"    motors[1].speed := 50.0;\n" +
"END_IF\n" +
"END_PROGRAM" },

    { title: "Global variables",
      text: "VAR_GLOBAL ... END_VAR, outside the POUs, makes variables every POU can use. " +
            "VAR_GLOBAL CONSTANT for constants shared by all.",
      code:
"VAR_GLOBAL\n" +
"    emergencyStop : BOOL;\n" +
"END_VAR\n" +
"VAR_GLOBAL CONSTANT\n" +
"    MOTORS : INT := 4;\n" +
"END_VAR\n" +
"\n" +
"PROGRAM PLC_PRG\n" +
"VAR\n" +
"    enabled : ARRAY[1..MOTORS] OF BOOL;\n" +
"    i : INT;\n" +
"END_VAR\n" +
"\n" +
"FOR i := 1 TO MOTORS DO\n" +
"    enabled[i] := NOT emergencyStop;\n" +
"END_FOR\n" +
"END_PROGRAM" },

    { title: "The online view",
      text: "Run shows every variable live. Tap a BOOL (or its switch) to flip it, any other value to " +
            "write a new one, and a function block, struct or array to open it. Start and Stop run " +
            "and pause the PLC (its time stands still while stopped), Step runs one cycle, Reset " +
            "puts every variable back to its initial value. Errors while running (division by zero, " +
            "an index out of range, the watchdog) stop the PLC: tap the message to see the line.",
      code: "" },

    { title: "Not in CodeSysFish (yet)",
      text: "Object-oriented ST (METHOD, PROPERTY, INTERFACE, EXTENDS, IMPLEMENTS), POINTER and " +
            "REFERENCE, ACTIONs, JMP, AT addresses (%IX0.0, there's no real I/O), bit access like x.0, " +
            "DATE, TIME_OF_DAY, DATE_AND_TIME, LTIME and WSTRING. REALs are worked out with LREAL " +
            "precision, and 64-bit whole numbers are exact up to 2^53. CodeSysFish runs ST " +
            "on the phone: it doesn't open CODESYS projects or connect to PLCs.",
      code: "" }
]
