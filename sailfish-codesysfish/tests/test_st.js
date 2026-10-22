// Unit tests for qml/js/st.js, the Structured Text compiler and runtime.
// Run: node tests/test_st.js
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const src = fs.readFileSync(path.join(__dirname, "../qml/js/st.js"), "utf8")
const ST = {}
vm.createContext(ST)
vm.runInContext(src.replace(/^\.pragma library\s*$/m, ""), ST)

let failed = 0, count = 0
function check(name, ok, detail) {
    count++
    console.log((ok ? "ok   - " : "FAIL - ") + name + (ok || detail === undefined ? "" : "  -> " + JSON.stringify(detail)))
    if (!ok) failed = 1
}

// Compiles; fails the test on errors.
function build(code) {
    const r = ST.compile(code)
    if (!r.ok) console.log("     compile errors: " + JSON.stringify(r.errors))
    return r
}
// A PROGRAM PLC_PRG with these variables and this body.
function prog(vars, body, extra) {
    return (extra || "") + "\nPROGRAM PLC_PRG\nVAR\n" + vars + "\nEND_VAR\n" + body + "\nEND_PROGRAM\n"
}
// Runs n cycles, dt ms apart; returns the runtime.
function run(code, n, dt) {
    const r = build(code)
    if (!r.ok) return null
    const plc = ST.createRuntime(r.app)
    for (let i = 0; i < (n || 1); i++) {
        const e = plc.cycle(i * (dt || 10))
        if (e) { plc.error = e; break }
    }
    return plc
}
function val(plc, name) { return plc ? plc.value("PLC_PRG." + name) : undefined }
// The first error's message, or "".
function errorOf(code) {
    const r = ST.compile(code)
    return r.errors.length ? r.errors[0] : null
}
function warningsOf(code) { return ST.compile(code).warnings }

// --- Lexing and literals ---
let p = run(prog("a, b, c, d, e, f : DINT; r : REAL; t : TIME; s : STRING; x : BOOL;",
    `a := 16#FF; b := 2#1010_1010; c := 8#17; d := 1_000_000; e := INT#-5; f := DINT#16#10;
     r := 1.5E3; t := T#1h2m3s4ms; s := 'it$'s $$5$N'; x := BOOL#1;`))
check("hex, binary, octal, underscores", val(p, "a") === 255 && val(p, "b") === 170 && val(p, "c") === 15 && val(p, "d") === 1000000)
check("typed literals", val(p, "e") === -5 && val(p, "f") === 16 && val(p, "x") === true)
check("real with exponent", val(p, "r") === 1500)
check("TIME literal", val(p, "t") === 3723004)
check("string escapes", val(p, "s") === "it's $5\n")
p = run(prog("t1, t2, t3 : TIME;", "t1 := TIME#1.5s; t2 := t#2d; t3 := T#500ms;"))
check("TIME forms", val(p, "t1") === 1500 && val(p, "t2") === 172800000 && val(p, "t3") === 500)
check("comments of all kinds", run(prog("a : INT;", "(* one (* nested *) *) a := 1; // line\n /* block */ a := a + 1;")) !== null)
check("keywords any case", run("program plc_prg var A : int; end_var if a = 0 then a := 7; end_if end_program").value("PLC_PRG.a") === 7)

// --- Arithmetic and types ---
p = run(prog("i : INT; j : INT; d : DINT; r : REAL; b : BYTE; u : UINT; m : INT; n : INT;",
    `i := 7 / 2; j := -7 / 2; d := 32767 + 1; r := 7 / 2; m := 7 MOD 3; n := -7 MOD 3;
     b := 255; b := b + 1; u := 0; u := u - 1;`))
check("integer division truncates", val(p, "i") === 3 && val(p, "j") === -3)
check("literals add up in 32 bits", val(p, "d") === 32768)
check("7 / 2 is integer division even into REAL", val(p, "r") === 3)
check("MOD keeps the dividend's sign", val(p, "m") === 1 && val(p, "n") === -1)
check("BYTE wraps 255 + 1 to 0", val(p, "b") === 0)
check("UINT wraps 0 - 1 to 65535", val(p, "u") === 65535)
p = run(prog("i : INT := 32767; k : INT; s : SINT := -128; d : DINT := 2147483647; e : DINT; big : DINT;",
    "k := i + 1; s := s - 1; e := d + 1; big := 100000 * 100000;"))
check("INT 32767 + 1 wraps to -32768", val(p, "k") === -32768)
check("SINT -128 - 1 wraps to 127", val(p, "s") === 127)
check("DINT overflow wraps", val(p, "e") === -2147483648)
check("32-bit multiplication wraps exactly", val(p, "big") === 1410065408)
p = run(prog("a : INT := 30000; b : INT := 30000; c : INT;", "c := (a + b) / 2;"))
check("INT intermediates don't overflow (32-bit registers)", val(p, "c") === 30000)
p = run(prog("r : REAL; l : LREAL; i : INT; x : REAL;", "r := 1 / 3.0; l := 2 ** 10; i := 5; x := i / 2; x := x + i;"))
check("REAL division", Math.abs(val(p, "r") - 1 / 3) < 1e-9)
check("** gives a real", val(p, "l") === 1024)
check("INT / literal in REAL context is integer division", val(p, "x") === 7)
check("-2 ** 2 is 4 (negation binds first)", run(prog("r : REAL;", "r := -2 ** 2;")).value("PLC_PRG.r") === 4)
p = run(prog("w : WORD := 16#F0F0; a : WORD; o : WORD; x : WORD; n : WORD; b : BOOL;",
    "a := w AND 16#FF00; o := w OR 16#000F; x := w XOR 16#FFFF; n := NOT w; b := NOT TRUE OR FALSE;"))
check("bitwise AND OR XOR NOT on WORD", val(p, "a") === 0xF000 && val(p, "o") === 0xF0FF && val(p, "x") === 0x0F0F && val(p, "n") === 0x0F0F)
check("boolean NOT and OR", val(p, "b") === false)
p = run(prog("a, b, c, d, e, f : BOOL;", "a := 3 > 2; b := 2 >= 3; c := 'abc' < 'abd'; d := T#1s = T#1000ms; e := 1 <> 1.5; f := TRUE XOR TRUE;"))
check("comparisons", val(p, "a") && !val(p, "b") && val(p, "c") && val(p, "d") && val(p, "e") && !val(p, "f"))
p = run(prog("t : TIME; u : TIME; v : TIME;", "t := T#1s + T#500ms; u := t * 2; v := u / 4;"))
check("TIME arithmetic", val(p, "t") === 1500 && val(p, "u") === 3000 && val(p, "v") === 750)
p = run(prog("x : BOOL; y : BOOL;", "x S= TRUE; y := TRUE; y R= 1 > 0;"))
check("S= and R=", val(p, "x") === true && val(p, "y") === false)
p = run(prog("a : INT := 1; b : BOOL;", "b := a = 1 AND_THEN 10 / a = 10;"))
check("AND_THEN", val(p, "b") === true)

// --- Control flow ---
p = run(prog("i, sum, odd : INT; x : INT := 5; s : STRING;",
    `FOR i := 1 TO 10 DO sum := sum + i; END_FOR
     FOR i := 9 TO 1 BY -2 DO odd := odd + 1; END_FOR
     IF x < 3 THEN s := 'small'; ELSIF x < 10 THEN s := 'medium'; ELSE s := 'big'; END_IF`))
check("FOR sums 1..10", val(p, "sum") === 55)
check("FOR with negative BY", val(p, "odd") === 5)
check("FOR leaves the variable one step past", val(p, "i") === -1)
check("IF ELSIF ELSE", val(p, "s") === "medium")
p = run(prog("i, n, w, r, c : INT;",
    `FOR i := 1 TO 100 DO IF i = 5 THEN EXIT; END_IF n := n + 1; END_FOR
     WHILE w < 10 DO w := w + 3; END_WHILE
     REPEAT r := r + 1; UNTIL r >= 4 END_REPEAT
     FOR i := 1 TO 10 DO IF i MOD 2 = 0 THEN CONTINUE; END_IF c := c + 1; END_FOR`))
check("EXIT", val(p, "n") === 4)
check("WHILE", val(p, "w") === 12)
check("REPEAT runs, then checks", val(p, "r") === 4)
check("CONTINUE", val(p, "c") === 5)
p = run(prog("k : INT; a, b, c, d : STRING;",
    `FOR k := 1 TO 4 DO
        CASE k OF
            1: a := 'one';
            2, 3: b := CONCAT(b, 'x');
        ELSE
            d := 'other';
        END_CASE
     END_FOR
     CASE 7 OF 1..5: c := 'low'; 6..10: c := 'high'; END_CASE`))
check("CASE single values and lists", val(p, "a") === "one" && val(p, "b") === "xx")
check("CASE ELSE", val(p, "d") === "other")
check("CASE ranges", val(p, "c") === "high")
p = run(prog("x : INT;", "x := 1; RETURN; x := 2;"))
check("RETURN ends the program's cycle", val(p, "x") === 1)

// --- Arrays, structs, enums ---
const types = `TYPE
    Point : STRUCT x : REAL; y : REAL := 2.5; END_STRUCT
    Color : (Red, Green := 5, Blue);
    Speed : INT;
END_TYPE`
p = run(prog(`a : ARRAY[1..5] OF INT := [10, 20, 3(7)]; m : ARRAY[0..1, 0..2] OF INT := [1, 2, 3, 4, 5, 6];
    pt : Point; q : Point := (x := 1.0); pts : ARRAY[1..2] OF Point; c : Color := Color.Blue; k : Color;
    i, n : INT; sp : Speed := 3; v : INT; e : BOOL;`,
    `n := 0; FOR i := 1 TO 5 DO n := n + a[i]; END_FOR
     pt.x := 3.0; pts[2] := q; pts[2].y := 9.0; v := m[1, 2]; k := Green; e := c = Blue;`, types))
check("array init with repeats", val(p, "a[3]") === 7 && val(p, "a[5]") === 7 && val(p, "n") === 51)
check("2-D array in row order", val(p, "v") === 6 && val(p, "m[0][1]") === 2)
check("struct defaults and init", val(p, "pt.y") === 2.5 && val(p, "q.x") === 1 && val(p, "pt.x") === 3)
check("struct assignment copies", val(p, "pts[2].y") === 9 && val(p, "q.y") === 2.5)
check("enum values", val(p, "c") === 6 && val(p, "k") === 5 && val(p, "e") === true)
check("type alias", val(p, "sp") === 3)
check("enum shown by name", p.display("PLC_PRG.c") === "Blue")
p = run(prog("st : State; t : INT;",
    `CASE st OF
        Idle: st := Running;
        Running: t := t + 1; IF t >= 3 THEN st := Done; END_IF
        Done: ;
     END_CASE`, "TYPE State : (Idle, Running, Done); END_TYPE"), 10)
check("state machine with an enum CASE", val(p, "t") === 3 && p.display("PLC_PRG.st") === "Done")

// --- POUs ---
const pous = `
FUNCTION Square : DINT
VAR_INPUT x : DINT; END_VAR
Square := x * x;
END_FUNCTION

FUNCTION Clamp : REAL
VAR_INPUT v : REAL; lo : REAL := 0.0; hi : REAL := 100.0; END_VAR
Clamp := LIMIT(lo, v, hi);
END_FUNCTION

FUNCTION Swap : BOOL
VAR_IN_OUT a, b : INT; END_VAR
VAR t : INT; END_VAR
t := a; a := b; b := t; Swap := TRUE;
END_FUNCTION

FUNCTION Divide : INT
VAR_INPUT a, b : INT; END_VAR
VAR_OUTPUT rest : INT; END_VAR
Divide := a / b; rest := a MOD b;
END_FUNCTION

FUNCTION_BLOCK Counter
VAR_INPUT step : INT := 1; END_VAR
VAR_OUTPUT total : INT; END_VAR
VAR calls : INT; END_VAR
calls := calls + 1;
total := total + step;
END_FUNCTION_BLOCK

FUNCTION_BLOCK Acc
VAR_IN_OUT target : INT; END_VAR
target := target + 10;
END_FUNCTION_BLOCK

PROGRAM Other
VAR n : INT; END_VAR
n := n + 1;
END_PROGRAM
`
p = run(prog(`s : DINT; c1, c2 : Counter; r : REAL; x : INT := 1; y : INT := 2; ok : BOOL;
    q, rem : INT; got : INT; acc : Acc; seen : INT;`,
    `s := Square(12); c1(); c2(step := 5); c2(step := 5, total => got);
     r := Clamp(150.0); x := x; ok := Swap(x, y); q := Divide(17, 5, rest => rem);
     acc(target := seen); Other(); seen := seen + Other.n;`, pous), 2)
check("FUNCTION call", val(p, "s") === 144)
check("FUNCTION_BLOCK instances keep their state", val(p, "c1.total") === 2 && val(p, "c2.total") === 20)
check("FB output with =>", val(p, "got") === 20)
check("FUNCTION default inputs", val(p, "r") === 100)
check("VAR_IN_OUT swaps", val(p, "x") === 1 && val(p, "y") === 2) // swapped twice in two cycles
check("FUNCTION VAR_OUTPUT with =>", val(p, "q") === 3 && val(p, "rem") === 2)
// Each cycle: acc adds 10 to seen, Other counts n up, seen adds n:
// cycle 1 -> 10 + 1 = 11, cycle 2 -> 21 + 2 = 23.
check("FB VAR_IN_OUT and calling a PROGRAM", val(p, "seen") === 23, val(p, "seen"))
check("other PROGRAM's variable from outside", p.value("Other.n") === 2)

// --- Globals and constants ---
p = run(`VAR_GLOBAL
    gCount : INT;
    MAX_N : INT := 3;
END_VAR
VAR_GLOBAL CONSTANT
    LIMIT_N : INT := 4;
END_VAR
` + prog("a : ARRAY[1..LIMIT_N] OF INT; i : INT;", "gCount := gCount + 1; FOR i := 1 TO LIMIT_N DO a[i] := i * MAX_N; END_FOR"), 3)
check("global variables", p.value("GVL.gCount") === 3)
check("constant as an array bound", val(p, "a[4]") === 12)

// --- Standard functions ---
p = run(prog(`a : INT; b : REAL; c : DINT; d : INT; e : INT; f : REAL; g : DINT; h : WORD; k : BYTE; l : BYTE;
    s1, s2, s3, s4, s5, s6 : STRING; n, m : INT; t : TIME; bt : BOOL; r2 : INT; u : UINT; st : STRING;`,
    `a := ABS(-5); b := SQRT(16.0); c := MAX(3, 9, 4); d := MIN(3, 9, 4); e := LIMIT(0, 150, 100);
     f := EXPT(2.0, 3.0); g := TRUNC(-3.7); h := SHL(WORD#16#00FF, 4); k := ROL(BYTE#2#1000_0001, 1); l := SHR(BYTE#16#F0, 4);
     s1 := CONCAT('PLC', '-', 'fish'); s2 := LEFT('abcdef', 2); s3 := RIGHT('abcdef', 3); s4 := MID('abcdef', 2, 3);
     n := LEN('hello'); m := FIND('hello', 'll'); s5 := INSERT('ac', 'b', 1); s6 := DELETE('abcdef', 2, 2);
     t := SEL(TRUE, T#1s, T#2s); r2 := MUX(2, 10, 20, 30); bt := INT_TO_BOOL(5); u := REAL_TO_UINT(2.5);
     st := REPLACE('abcdef', 'XY', 2, 3);`))
check("ABS SQRT MAX MIN LIMIT", val(p, "a") === 5 && val(p, "b") === 4 && val(p, "c") === 9 && val(p, "d") === 3 && val(p, "e") === 100)
check("EXPT and TRUNC", val(p, "f") === 8 && val(p, "g") === -3)
check("SHL ROL SHR", val(p, "h") === 0x0FF0 && val(p, "k") === 3 && val(p, "l") === 0x0F)
check("CONCAT LEFT RIGHT MID", val(p, "s1") === "PLC-fish" && val(p, "s2") === "ab" && val(p, "s3") === "def" && val(p, "s4") === "cd")
check("LEN FIND INSERT DELETE REPLACE", val(p, "n") === 5 && val(p, "m") === 3 && val(p, "s5") === "abc" && val(p, "s6") === "adef" && val(p, "st") === "abXYef")
check("SEL MUX", val(p, "t") === 2000 && val(p, "r2") === 30)
check("conversions", val(p, "bt") === true && val(p, "u") === 3)
p = run(prog("a : STRING; b : STRING; c : STRING; d : INT; e : REAL; f : TIME; g : DINT; h : INT; k : BOOL; tm : TIME; x : INT;",
    `a := INT_TO_STRING(-42); b := REAL_TO_STRING(1.5); c := TIME_TO_STRING(T#1m30s); d := STRING_TO_INT('123');
     e := STRING_TO_REAL('2.25'); f := STRING_TO_TIME('T#2s'); g := TIME_TO_DINT(T#3s); h := TO_INT(3.5);
     k := STRING_TO_BOOL('TRUE'); x := REAL_TO_INT(-2.5); tm := DINT_TO_TIME(250);`))
check("to STRING", val(p, "a") === "-42" && val(p, "b") === "1.5" && val(p, "c") === "T#1m30s")
check("from STRING", val(p, "d") === 123 && val(p, "e") === 2.25 && val(p, "f") === 2000 && val(p, "k") === true)
check("TIME <-> numbers, TO_INT, rounding half away from zero", val(p, "g") === 3000 && val(p, "h") === 4 && val(p, "x") === -3 && val(p, "tm") === 250)

// --- Standard function blocks, on the PLC's clock ---
p = run(prog("t : TON; go : BOOL; done : BOOL; et : TIME;", "t(IN := go, PT := T#100ms); done := t.Q; et := t.ET;"), 1)
p.write("PLC_PRG.go", "TRUE")
for (let ms = 0; ms <= 90; ms += 10) p.cycle(1000 + ms)
check("TON not yet after 90 ms", val(p, "done") === false && val(p, "et") === 90)
p.cycle(1100)
check("TON after 100 ms", val(p, "done") === true && val(p, "et") === 100)
p.write("PLC_PRG.go", "FALSE"); p.cycle(1110)
check("TON resets when IN drops", val(p, "done") === false && val(p, "et") === 0)
p = run(prog("t : TOF; go : BOOL := TRUE; q : BOOL;", "t(IN := go, PT := T#50ms); q := t.Q;"), 1)
p.write("PLC_PRG.go", "FALSE"); p.cycle(20); p.cycle(40)
check("TOF holds Q", val(p, "q") === true)
p.cycle(80)
check("TOF drops Q after PT", val(p, "q") === false)
p = run(prog("t : TP; go : BOOL; q : BOOL;", "t(IN := go, PT := T#30ms); q := t.Q;"), 1)
p.write("PLC_PRG.go", "TRUE"); p.cycle(10)
check("TP starts a pulse", val(p, "q") === true)
p.write("PLC_PRG.go", "FALSE"); p.cycle(20)
check("TP keeps the pulse when IN drops", val(p, "q") === true)
p.cycle(50)
check("TP ends the pulse after PT", val(p, "q") === false)
p = run(prog("r : R_TRIG; f : F_TRIG; c : CTU; d : CTD; ud : CTUD; sr : SR; rs : RS; x : BOOL; rises, falls : INT;",
    `r(CLK := x); f(CLK := x); IF r.Q THEN rises := rises + 1; END_IF IF f.Q THEN falls := falls + 1; END_IF
     c(CU := x, PV := 3); d(CD := x, LOAD := FALSE, PV := 5); ud(CU := x, PV := 2);
     sr(SET1 := x, RESET := TRUE); rs(SET := x, RESET1 := TRUE);`), 1)
for (let i = 0; i < 4; i++) { p.write("PLC_PRG.x", "TRUE"); p.cycle(100 + i * 20); p.write("PLC_PRG.x", "FALSE"); p.cycle(110 + i * 20) }
check("R_TRIG and F_TRIG count edges", val(p, "rises") === 4 && val(p, "falls") === 4)
check("CTU counts up and sets Q at PV", val(p, "c.CV") === 4 && val(p, "c.Q") === true)
check("CTD counts down", val(p, "d.CV") === -4 && val(p, "d.Q") === true)
check("CTUD", val(p, "ud.CV") === 4 && val(p, "ud.QU") === true)
check("SR: set wins, RS: reset wins", val(p, "sr.Q1") === false && val(p, "rs.Q1") === false)
p = run(prog("t : TON := (PT := T#2s);", "t(IN := TRUE);"), 1)
check("FB instance with initial inputs", val(p, "t.PT") === 2000)
p = run(prog("now : TIME;", "now := TIME();"), 3, 25)
check("TIME() is the PLC's time", val(p, "now") === 50)

// --- Runtime errors ---
p = run(prog("a : INT; z : INT;", "a := 1;\nz := a / z;"))
check("division by zero stops with its line", p.error && /Division by zero/.test(p.error.message) && p.error.line === 7, p.error)
p = run(prog("a : ARRAY[1..3] OF INT; i : INT := 4;", "a[i] := 1;"))
check("index out of range", p.error && /Index 4 is outside the array's 1..3/.test(p.error.message), p.error)
let r = build(prog("i : INT;", "WHILE TRUE DO i := i + 1; END_WHILE"))
let plc = ST.createRuntime(r.app, { watchdogMs: 50 })
let t0 = Date.now(), e = plc.cycle(0)
check("watchdog stops an endless loop", e && /Watchdog/.test(e.message) && Date.now() - t0 < 2000, e)
r = build(prog("i : INT;", "FOR i := 0 TO 32767 DO END_FOR"))
plc = ST.createRuntime(r.app, { watchdogMs: 50 })
check("FOR 0 TO 32767 with an INT never ends, as on a PLC", /Watchdog/.test((plc.cycle(0) || {}).message))
r = build("FUNCTION F : INT VAR_INPUT n : INT; END_VAR F := F(n + 1); END_FUNCTION\n" + prog("x : INT;", "x := F(1);"))
check("endless recursion is caught", /nested calls/.test((ST.createRuntime(r.app).cycle(0) || {}).message))
p = run(prog("x : INT;", "x := x + 1;"), 3)
check("a program keeps running after reset", (p.reset(), p.cycle(0), val(p, "x")) === 1)

// --- Compile errors, with their lines ---
function errCheck(name, code, re, line) {
    const e = errorOf(code)
    check(name, e && re.test(e.message) && (line === undefined || e.line === line), e)
}
errCheck("missing semicolon", "PROGRAM PLC_PRG\nVAR a : INT; END_VAR\na := 1\na := 2;\nEND_PROGRAM", /Expected ';' after the assignment/, 4)
errCheck("unknown variable", prog("a : INT;", "a := b;"), /Unknown name 'b'/, 6)
errCheck("= instead of :=", prog("a : INT;", "a = 1;"), /Use := to assign/)
errCheck("BOOL into INT", prog("a : INT;", "a := TRUE;"), /Can't assign BOOL to INT: use BOOL_TO_INT/)
errCheck("number into TIME", prog("t : TIME;", "t := 1000;"), /write a TIME like T#1s/)
errCheck("strings with +", prog("s : STRING;", "s := 'a' + 'b';"), /use CONCAT/)
errCheck("IF needs BOOL", prog("a : INT;", "IF a THEN a := 1; END_IF"), /IF's condition must be BOOL/)
errCheck("missing END_IF", prog("a : INT;", "IF TRUE THEN a := 1;"), /Expected ELSIF or ELSE or END_IF before END_PROGRAM/)
errCheck("constant can't be assigned", prog("a : INT;", "a := 1;").replace("VAR\n", "VAR CONSTANT\n").replace("a : INT;", "a : INT := 5;"), /'a' is a CONSTANT/)
errCheck("FB output can't be written", prog("t : TON;", "t.Q := TRUE;"), /output: only its function block sets it/)
errCheck("FB internals are private", "FUNCTION_BLOCK F VAR x : INT; END_VAR END_FUNCTION_BLOCK\n" + prog("f : F; a : INT;", "a := f.x;"), /internal to F/)
errCheck("FB call in an expression", prog("t : TON; b : BOOL;", "b := t(IN := TRUE);"), /function block call gives no value/)
errCheck("EXIT outside a loop", prog("a : INT;", "EXIT;"), /EXIT only works inside/)
errCheck("unknown type", prog("a : FLOAT;", ""), /Unknown type 'FLOAT'/)
errCheck("constant index out of range", prog("a : ARRAY[1..3] OF INT;", "a[5] := 1;"), /Index 5 is outside/)
errCheck("division by a constant zero", prog("a : INT;", "a := 1 / 0;"), /Division by zero/)
errCheck("unterminated string", prog("s : STRING;", "s := 'abc;"), /never ends/)
errCheck("no PROGRAM", "FUNCTION F : INT F := 1; END_FUNCTION", /no PROGRAM to run/)
errCheck("METHODs are named as unsupported", "FUNCTION_BLOCK F\nMETHOD M\nEND_FUNCTION_BLOCK\n" + prog("a : INT;", ""), /METHODs aren't supported/)
errCheck("pointers are named as unsupported", prog("p : POINTER TO INT;", ""), /POINTERs aren't supported/)
check("a variable named dt is fine (really)", errorOf(prog("dt : REAL;", "dt := 0.1;")) === null)
errCheck("duplicate variable", prog("a : INT; a : REAL;", ""), /declared twice/)
errCheck("wrong argument name", prog("t : TON;", "t(INN := TRUE);"), /TON has no input 'INN'/)
errCheck("a variable hiding an enum value is explained",
    prog("c : Col; blue : BOOL;", "c := Blue;", "TYPE Col : (Red, Blue); END_TYPE"), /'Blue' is a variable here, which hides Col.Blue/)
errCheck("a variable hiding a function is explained",
    "FUNCTION Avg : REAL Avg := 1.0; END_FUNCTION\n" + prog("avg : REAL;", "avg := Avg();"), /hides the FUNCTION Avg/)
check("CASE on an enum finds its values past a same-named variable",
    run(prog("c : Col := Col.Blue; blue : BOOL; hit : INT;", "CASE c OF Red: hit := 1; Blue: hit := 2; END_CASE", "TYPE Col : (Red, Blue); END_TYPE")).value("PLC_PRG.hit") === 2)
errCheck("CASE value twice", prog("a : INT;", "CASE a OF 1: a := 1; 1: a := 2; END_CASE"), /in this CASE twice/)
const many = ST.compile(prog("a : INT;", "a := b;\na := TRUE;\nc := 1;"))
check("several errors reported at once, in order", many.errors.length === 3 && many.errors[0].line === 6 && many.errors[2].line === 8, many.errors)
check("narrowing gives a warning", warningsOf(prog("i : INT; d : DINT;", "i := d;")).some(w => /may lose data/.test(w.message)))
check("REAL to INT gives a warning", warningsOf(prog("i : INT; r : REAL;", "i := r;")).some(w => /rounded/.test(w.message)))
check("literal too big gives a warning", warningsOf(prog("b : BYTE;", "b := 300;")).some(w => /doesn't fit in BYTE/.test(w.message)))
check("clean code has no warnings", warningsOf(prog("i : INT; r : REAL;", "i := 5; r := i;")).length === 0)

// --- The online view ---
p = run(prog("on : BOOL; n : INT; r : REAL := 1.25; t : TON; s : STRING(10); arr : ARRAY[1..3] OF INT; k : INT := 3;", "n := n + k;", ""), 2)
let rows = p.rows({})
check("rows: the program's variables in order", rows.map(x => x.name).join() === "on,n,r,t,s,arr,k", rows.map(x => x.name))
check("rows: values formatted", rows[1].value === "6" && rows[2].value === "1.25" && rows[4].value === "''" && rows[0].value === "FALSE")
check("rows: kinds and writability", rows[0].kind === "bool" && rows[3].kind === "node" && rows[1].writable && !rows[3].writable)
rows = p.rows({ "PLC_PRG.t": true, "PLC_PRG.arr": true })
check("rows: expanded FB and array", rows.filter(x => x.depth === 1).map(x => x.name).join() === "IN,PT,Q,ET,[1],[2],[3]")
check("rows: paths", rows.some(x => x.path === "PLC_PRG.t.ET") && rows.some(x => x.path === "PLC_PRG.arr[2]"))
check("write BOOL", p.write("PLC_PRG.on", "true") === "" && val(p, "on") === true)
check("write INT, hex too", p.write("PLC_PRG.k", "16#10") === "" && val(p, "k") === 16)
check("write rejects out of range", /INT goes from -32768 to 32767/.test(p.write("PLC_PRG.k", "40000")))
check("write REAL", p.write("PLC_PRG.r", "2.5") === "" && val(p, "r") === 2.5)
check("write TIME", p.write("PLC_PRG.t.PT", "T#3s") === "" && val(p, "t.PT") === 3000 && p.write("PLC_PRG.t.PT", "250") === "" && val(p, "t.PT") === 250)
check("write STRING, cut to its length", p.write("PLC_PRG.s", "'hello world, long'") === "" && val(p, "s") === "hello worl")
check("write array element", p.write("PLC_PRG.arr[2]", "7") === "" && val(p, "arr[2]") === 7)
check("write rejects nonsense", p.write("PLC_PRG.on", "maybe") !== "" && p.write("PLC_PRG.nope", "1") !== "")
p.cycle(1000)
check("the program sees written values", val(p, "n") === 6 + 16)
check("TIME shown as T#", p.display("PLC_PRG.t.PT") === "T#250ms")
p = run(`VAR_GLOBAL g : INT := 4; END_VAR\nPROGRAM Sub VAR x : INT; END_VAR x := 1; END_PROGRAM\n` + prog("a : INT;", "Sub();"))
rows = p.rows({ "Sub": true, "GVL": true })
check("rows: other programs and globals as groups", rows.map(x => x.path).join() === "PLC_PRG.a,Sub,Sub.x,GVL,GVL.g", rows.map(x => x.path))

// --- Main program choice ---
r = build("PROGRAM First VAR a : INT; END_VAR a := 1; END_PROGRAM\nPROGRAM Second VAR b : INT; END_VAR b := 1; END_PROGRAM")
check("without PLC_PRG, the first PROGRAM runs", r.app.main.name === "First")

// --- Highlighting words ---
const words = ST.highlightWords()
check("highlight words", words.keywords.indexOf("END_IF") >= 0 && words.types.indexOf("LREAL") >= 0 && words.functions.indexOf("TON") >= 0)

// --- Plain ES5 for Qt 5.6 ---
check("ES5 only (no let/const/arrow/template)", !/\b(let|const)\s|=>\s*[{(\w]|`/.test(src.replace(/"[^"\n]*"/g, "\"\"")))

console.log("\n" + count + " checks, " + (failed ? "some FAILED" : "all ok"))
process.exit(failed)
