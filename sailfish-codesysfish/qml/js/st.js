.pragma library

// CodeSysFish's Structured Text engine: compiles IEC 61131-3 Structured
// Text, as CODESYS writes it, and runs it like a PLC, one cycle at a time.
//
//   var result = compile(source)         // { ok, errors, warnings, app }
//   var plc = createRuntime(result.app)  // runs PLC_PRG, or the first PROGRAM
//   plc.cycle(nowMs)                     // one PLC cycle: null, or the error
//   plc.rows(expanded)                   // the variables, for the online view
//   plc.write(path, text)                // writes a value: "" or why not
//
// Plain ES5 with no imports, so it runs in Sailfish's Qt 5.6 JavaScript
// engine and in Node for the tests.
//
// The code is compiled to JavaScript closures: each expression becomes a
// function(f, rt) that returns its value, each statement one that runs it,
// where f is the frame (the program's, function block's or function's
// variables) and rt the runtime. Statements return how they ended: NEXT,
// or EXIT, CONTINUE or RETURN on their way out of a loop or the POU.

var NEXT = 0, EXIT = 1, CONTINUE = 2, RETURN = 3

// --- Errors -----------------------------------------------------------------

// A mistake in the code, found while compiling.
function StError(message, line, col) {
    this.message = message
    this.line = line || 0
    this.col = col || 0
}

// A failure while running: division by zero, an index out of range, the
// watchdog.
function RunError(message, line) {
    this.message = message
    this.line = line || 0
}

function fail(message, at) {
    throw new StError(message, at ? at.line : 0, at ? at.col : 0)
}

// --- Types --------------------------------------------------------------------

function intType(name, bits, signed, bitstr) {
    return { kind: "int", name: name, bits: bits, signed: signed, bitstr: !!bitstr }
}

var TYPES = {
    BOOL: { kind: "bool", name: "BOOL" },
    SINT: intType("SINT", 8, true), INT: intType("INT", 16, true),
    DINT: intType("DINT", 32, true), LINT: intType("LINT", 64, true),
    USINT: intType("USINT", 8, false), UINT: intType("UINT", 16, false),
    UDINT: intType("UDINT", 32, false), ULINT: intType("ULINT", 64, false),
    BYTE: intType("BYTE", 8, false, true), WORD: intType("WORD", 16, false, true),
    DWORD: intType("DWORD", 32, false, true), LWORD: intType("LWORD", 64, false, true),
    REAL: { kind: "real", name: "REAL", digits: 7 },
    LREAL: { kind: "real", name: "LREAL", digits: 15 },
    TIME: { kind: "time", name: "TIME" }
}
// An integer or real literal takes the type of whatever it's used with.
var ANY_INT = { kind: "int", name: "ANY_INT", bits: 64, signed: true, lit: true }
var ANY_REAL = { kind: "real", name: "ANY_REAL", digits: 15, lit: true }
var VOID = { kind: "void", name: "VOID" }

function stringType(len) {
    return { kind: "string", name: len === 80 ? "STRING" : "STRING(" + len + ")", len: len }
}
var STRING = stringType(80)

// The elementary types, for typed literals (INT#5) and conversions.
function elementary(name) {
    if (TYPES.hasOwnProperty(name)) return TYPES[name]
    if (name === "STRING") return STRING
    return null
}

function typeName(t) {
    if (t.kind === "array") {
        return "ARRAY[" + t.dims.map(function(d) { return d.lo + ".." + d.hi }).join(", ") + "] OF " + typeName(t.of)
    }
    return t.name
}

function isNum(t) { return t.kind === "int" || t.kind === "real" }

// --- Values -------------------------------------------------------------------

var TWO32 = 4294967296

function trunc(v) { return v < 0 ? Math.ceil(v) : Math.floor(v) }

// v as an integer of type t: wrapped around like the PLC's registers.
// 64-bit types are kept as JavaScript numbers, exact up to 2^53.
function wrap(v, t) {
    if (v !== v) return 0 // NaN
    v = trunc(v)
    if (t.bits >= 64) {
        if (!t.signed && v < 0) v = 0
        return v
    }
    var m = Math.pow(2, t.bits)
    if (v >= 0 && v < m / (t.signed ? 2 : 1)) return v
    v = v - Math.floor(v / m) * m
    if (t.signed && v >= m / 2) v -= m
    return v
}

// The low 32 bits of a * b, without losing precision (Math.imul is ES6).
function imul(a, b) {
    var ah = (a >>> 16) & 0xffff, al = a & 0xffff
    var bh = (b >>> 16) & 0xffff, bl = b & 0xffff
    return ((al * bl) + (((ah * bl + al * bh) << 16) >>> 0)) | 0
}

// Rounds half away from zero, as REAL_TO_INT does.
function roundHalfAway(v) {
    return v < 0 ? -Math.floor(-v + 0.5) : Math.floor(v + 0.5)
}

function defaultScalar(t) {
    switch (t.kind) {
    case "bool": return false
    case "string": return ""
    case "enum": return t.values.length > 0 ? t.values[0].value : 0
    default: return 0
    }
}

// A copy, for value semantics: assigning a struct or array copies it.
function copyValue(v, t) {
    if (t.kind === "array") {
        var out = []
        for (var i = 0; i < v.length; i++) out.push(copyValue(v[i], t.sub))
        return out
    }
    if (t.kind === "struct") {
        var o = {}
        for (var j = 0; j < t.fields.length; j++) {
            var f = t.fields[j]
            o[f.key] = copyValue(v[f.key], f.type)
        }
        return o
    }
    return v
}

// --- Formatting -----------------------------------------------------------------

function formatTime(ms) {
    ms = Math.round(ms)
    if (ms === 0) return "T#0ms"
    var out = "T#", neg = ms < 0
    if (neg) { out += "-"; ms = -ms }
    var parts = [[86400000, "d"], [3600000, "h"], [60000, "m"], [1000, "s"], [1, "ms"]]
    for (var i = 0; i < parts.length; i++) {
        var n = Math.floor(ms / parts[i][0])
        if (n > 0) { out += n + parts[i][1]; ms -= n * parts[i][0] }
    }
    return out
}

function formatReal(v, digits) {
    if (v !== v) return "NAN"
    if (v === Infinity) return "INF"
    if (v === -Infinity) return "-INF"
    var s = String(Number(v.toPrecision(digits)))
    return s.replace("e+", "E+").replace("e-", "E-")
}

function formatValue(v, t) {
    switch (t.kind) {
    case "bool": return v ? "TRUE" : "FALSE"
    case "int": return String(v)
    case "real": return formatReal(v, t.digits)
    case "time": return formatTime(v)
    case "string": return "'" + v + "'"
    case "enum":
        return t.byValue.hasOwnProperty(v) ? t.byValue[v] : String(v)
    case "array": return ""
    default: return ""
    }
}

// A value as STRING, for the X_TO_STRING conversions.
function toStringValue(v, t) {
    if (t.kind === "string") return v
    if (t.kind === "enum") return t.byValue.hasOwnProperty(v) ? t.byValue[v] : String(v)
    return formatValue(v, t)
}

// --- Lexer ------------------------------------------------------------------------

var KEYWORDS = {}
;("PROGRAM END_PROGRAM FUNCTION_BLOCK END_FUNCTION_BLOCK FUNCTION END_FUNCTION " +
  "VAR VAR_INPUT VAR_OUTPUT VAR_IN_OUT VAR_TEMP VAR_GLOBAL VAR_STAT END_VAR CONSTANT RETAIN PERSISTENT " +
  "TYPE END_TYPE STRUCT END_STRUCT ARRAY OF " +
  "IF THEN ELSIF ELSE END_IF CASE END_CASE FOR TO BY DO END_FOR WHILE END_WHILE " +
  "REPEAT UNTIL END_REPEAT EXIT CONTINUE RETURN " +
  "AND OR XOR NOT MOD AND_THEN OR_ELSE TRUE FALSE").split(" ").forEach(function(k) { KEYWORDS[k] = true })

// Things CODESYS has that CodeSysFish doesn't (yet), with a clear message.
var UNSUPPORTED = {
    METHOD: "METHODs", PROPERTY: "PROPERTYs", INTERFACE: "INTERFACEs", EXTENDS: "EXTENDS",
    IMPLEMENTS: "IMPLEMENTS", POINTER: "POINTERs", REFERENCE: "REFERENCEs", ACTION: "ACTIONs",
    JMP: "JMP", AT: "AT addresses (%IX...)", UNION: "UNIONs", VAR_EXTERNAL: "VAR_EXTERNAL",
    VAR_CONFIG: "VAR_CONFIG", LTIME: "LTIME", WSTRING: "WSTRING",
    TOD: "TIME_OF_DAY", TIME_OF_DAY: "TIME_OF_DAY", DATE: "DATE", DT: "DATE_AND_TIME",
    DATE_AND_TIME: "DATE_AND_TIME", D: "DATE"
}

function parseDuration(text) {
    var s = text.toLowerCase().replace(/_/g, "")
    var m = /^(-)?(?:(\d+(?:\.\d+)?)d)?(?:(\d+(?:\.\d+)?)h)?(?:(\d+(?:\.\d+)?)m(?!s))?(?:(\d+(?:\.\d+)?)s)?(?:(\d+(?:\.\d+)?)ms)?$/.exec(s)
    if (!m || s === "" || s === "-") return null
    var units = [86400000, 3600000, 60000, 1000, 1], ms = 0, any = false
    for (var i = 0; i < 5; i++) {
        if (m[i + 2] !== undefined) { ms += parseFloat(m[i + 2]) * units[i]; any = true }
    }
    if (!any) return null
    return (m[1] ? -1 : 1) * Math.round(ms)
}

function lex(src) {
    var toks = [], i = 0, line = 1, lineStart = 0, n = src.length
    function at() { return { line: line, col: i - lineStart + 1 } }
    function skipTo(j) {
        for (; i < j; i++) {
            if (src.charAt(i) === "\n") { line++; lineStart = i + 1 }
        }
    }
    function tok(t, v, start, extra) {
        var o = { t: t, v: v, line: start.line, col: start.col }
        if (extra) for (var k in extra) o[k] = extra[k]
        toks.push(o)
        return o
    }
    while (i < n) {
        var c = src.charAt(i), c2 = src.substr(i, 2)
        if (c === " " || c === "\t" || c === "\r" || c === "\n" || c === "\f") { skipTo(i + 1); continue }
        var start = at()
        if (c2 === "(*") {
            // Comments nest, as CODESYS lets them.
            var depth = 0, j = i
            while (j < n) {
                if (src.substr(j, 2) === "(*") { depth++; j += 2 }
                else if (src.substr(j, 2) === "*)") { depth--; j += 2; if (depth === 0) break }
                else j++
            }
            if (depth > 0) fail("This comment never ends: (* needs a matching *)", start)
            skipTo(j)
            continue
        }
        if (c2 === "/*") {
            var e = src.indexOf("*/", i + 2)
            if (e < 0) fail("This comment never ends: /* needs a matching */", start)
            skipTo(e + 2)
            continue
        }
        if (c2 === "//") {
            var nl = src.indexOf("\n", i)
            skipTo(nl < 0 ? n : nl)
            continue
        }
        if (/[0-9]/.test(c)) {
            var num = /^[0-9][0-9_]*/.exec(src.substr(i))[0]
            var after = i + num.length
            if (src.charAt(after) === "#") {
                var base = parseInt(num.replace(/_/g, ""), 10)
                var digits = /^[0-9A-Fa-f_]*/.exec(src.substr(after + 1))[0]
                if (base !== 2 && base !== 8 && base !== 16 && base !== 10) fail("Numbers can be written in base 2, 8, 10 or 16, not " + base, start)
                var clean = digits.replace(/_/g, "")
                var valid = { 2: /^[01]+$/, 8: /^[0-7]+$/, 10: /^[0-9]+$/, 16: /^[0-9A-Fa-f]+$/ }[base]
                if (!valid.test(clean)) fail("'" + num + "#" + digits + "' isn't a base " + base + " number", start)
                skipTo(after + 1 + digits.length)
                tok("int", parseInt(clean, base), start, { based: true })
                continue
            }
            var real = /^[0-9][0-9_]*(\.[0-9][0-9_]*)?([eE][+-]?[0-9]+)?/.exec(src.substr(i))[0]
            if (real.length > num.length) {
                skipTo(i + real.length)
                tok("real", parseFloat(real.replace(/_/g, "")), start)
            } else {
                skipTo(after)
                tok("int", parseInt(num.replace(/_/g, ""), 10), start)
            }
            continue
        }
        if (/[A-Za-z_]/.test(c)) {
            var word = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.substr(i))[0]
            var up = word.toUpperCase()
            var hashAt = i + word.length
            if (src.charAt(hashAt) === "#") {
                if (up === "T" || up === "TIME") {
                    var d = /^-?[0-9A-Za-z_.]*/.exec(src.substr(hashAt + 1))[0]
                    var ms = parseDuration(d)
                    if (ms === null) fail("'" + word + "#" + d + "' isn't a time: write it like T#1s500ms, T#2m or T#1.5s", start)
                    if (ms < 0) fail("TIME can't be negative", start)
                    skipTo(hashAt + 1 + d.length)
                    tok("time", ms, start)
                    continue
                }
                if (UNSUPPORTED.hasOwnProperty(up)) fail(UNSUPPORTED[up] + " aren't supported in CodeSysFish", start)
                skipTo(hashAt + 1)
                tok("tprefix", up, start, { text: word })
                continue
            }
            skipTo(hashAt)
            tok(KEYWORDS.hasOwnProperty(up) ? "kw" : "id", up, start, { text: word })
            continue
        }
        if (c === "'" || c === "\"") {
            var s = "", j2 = i + 1, closed = false
            while (j2 < n) {
                var ch = src.charAt(j2)
                if (ch === c) { closed = true; j2++; break }
                if (ch === "\n") break
                if (ch === "$") {
                    var esc = src.charAt(j2 + 1), escU = esc.toUpperCase()
                    if (escU === "L" || escU === "N") s += "\n"
                    else if (escU === "R") s += "\r"
                    else if (escU === "T") s += "\t"
                    else if (escU === "P") s += "\f"
                    else if (esc === "$" || esc === "'" || esc === "\"") s += esc
                    else if (/[0-9A-Fa-f]{2}/.test(src.substr(j2 + 1, 2))) {
                        s += String.fromCharCode(parseInt(src.substr(j2 + 1, 2), 16))
                        j2 += 3
                        continue
                    } else fail("Unknown escape '$" + esc + "' in a string: use $$ for a dollar sign", start)
                    j2 += 2
                    continue
                }
                s += ch
                j2++
            }
            if (!closed) fail("This string never ends: it needs a closing " + c, start)
            skipTo(j2)
            tok("str", s, start)
            continue
        }
        var two = ["**", ":=", "=>", "<=", ">=", "<>", ".."]
        if (two.indexOf(c2) >= 0) {
            skipTo(i + 2)
            tok("op", c2, start)
            continue
        }
        if ("+-*/()[],;:.=<>&^#".indexOf(c) >= 0) {
            if (c === "^") fail("POINTERs aren't supported in CodeSysFish", start)
            skipTo(i + 1)
            tok("op", c, start)
            continue
        }
        fail("Unexpected character '" + c + "'", start)
    }
    tok("eof", null, at())
    return toks
}

// --- Parser ---------------------------------------------------------------------

function Parser(toks) {
    this.toks = toks
    this.i = 0
}

Parser.prototype = {
    peek: function(k) { return this.toks[Math.min(this.i + (k || 0), this.toks.length - 1)] },
    next: function() { return this.toks[this.i < this.toks.length - 1 ? this.i++ : this.i] },
    isKw: function(k, t) { t = t || this.peek(); return t.t === "kw" && t.v === k },
    isOp: function(o, t) { t = t || this.peek(); return t.t === "op" && t.v === o },
    describe: function(t) {
        if (t.t === "eof") return "the end of the code"
        if (t.t === "str") return "'" + t.v + "'"
        if (t.t === "time") return "a TIME"
        if (t.t === "id" || t.t === "kw" || t.t === "tprefix") return "'" + (t.text || t.v) + "'"
        return "'" + t.v + "'"
    },
    expectKw: function(k, why) {
        var t = this.peek()
        if (!this.isKw(k, t)) fail("Expected " + k + (why ? " " + why : "") + ", found " + this.describe(t), t)
        return this.next()
    },
    expectOp: function(o, why) {
        var t = this.peek()
        if (!this.isOp(o, t)) fail("Expected '" + o + "'" + (why ? " " + why : "") + ", found " + this.describe(t), t)
        return this.next()
    },
    ident: function(what) {
        var t = this.peek()
        if (t.t !== "id") {
            if (t.t === "kw") fail("'" + t.text + "' is a keyword and can't be used as " + (what || "a name"), t)
            fail("Expected " + (what || "a name") + ", found " + this.describe(t), t)
        }
        return this.next()
    },
    // ';' after END_IF and friends is optional, as CODESYS takes it.
    optSemi: function() { if (this.isOp(";")) this.next() },

    unit: function() {
        var unit = { pous: [], types: [], globals: [] }
        while (this.peek().t !== "eof") {
            var t = this.peek()
            if (this.isKw("PROGRAM") || this.isKw("FUNCTION_BLOCK") || this.isKw("FUNCTION")) unit.pous.push(this.pou())
            else if (this.isKw("TYPE")) unit.types = unit.types.concat(this.typeBlock())
            else if (this.isKw("VAR_GLOBAL")) unit.globals.push(this.varSection())
            else if (t.t === "id" && UNSUPPORTED.hasOwnProperty(t.v)) fail(UNSUPPORTED[t.v] + " aren't supported in CodeSysFish", t)
            else fail("Expected PROGRAM, FUNCTION_BLOCK, FUNCTION, TYPE or VAR_GLOBAL, found " + this.describe(t), t)
        }
        return unit
    },

    pou: function() {
        var kwTok = this.next(), kind = kwTok.v
        var nameTok = this.ident("the " + kind + "'s name")
        var pou = { kind: kind, name: nameTok.text, key: nameTok.v, line: kwTok.line, col: kwTok.col,
                    nameAt: nameTok, retSpec: null, sections: [], body: [] }
        if (kind === "FUNCTION") {
            if (this.isOp(":")) {
                this.next()
                pou.retSpec = this.typeSpec()
            } else {
                fail("A FUNCTION needs its return type: FUNCTION " + pou.name + " : INT", this.peek())
            }
        }
        var t = this.peek()
        if (t.t === "id" && (t.v === "EXTENDS" || t.v === "IMPLEMENTS")) fail(UNSUPPORTED[t.v] + " aren't supported in CodeSysFish", t)
        while (this.peek().t === "kw" && /^VAR/.test(this.peek().v)) pou.sections.push(this.varSection())
        var end = "END_" + kind
        pou.body = this.statements([end])
        pou.endLine = this.expectKw(end, "to end " + kind + " " + pou.name).line
        this.optSemi()
        return pou
    },

    varSection: function() {
        var kwTok = this.next()
        if (kwTok.t !== "kw" || !/^VAR/.test(kwTok.v)) fail("Expected VAR", kwTok)
        var section = { kind: kwTok.v === "VAR_STAT" ? "VAR" : kwTok.v, constant: false, vars: [], line: kwTok.line }
        while (this.isKw("CONSTANT") || this.isKw("RETAIN") || this.isKw("PERSISTENT")) {
            if (this.next().v === "CONSTANT") section.constant = true
        }
        while (!this.isKw("END_VAR")) {
            var t = this.peek()
            if (t.t === "eof" || (t.t === "kw" && t.v !== "END_VAR")) {
                fail("Expected a variable or END_VAR, found " + this.describe(t), t)
            }
            var names = [this.ident("a variable name")]
            while (this.isOp(",")) {
                this.next()
                names.push(this.ident("a variable name"))
            }
            if (this.peek().t === "id" && this.peek().v === "AT") fail("AT addresses (%IX...) aren't supported in CodeSysFish", this.peek())
            this.expectOp(":", "and the variable's type")
            var spec = this.typeSpec()
            var init = null
            if (this.isOp(":=")) {
                this.next()
                init = this.initValue()
            }
            this.expectOp(";", "after the declaration of " + names[names.length - 1].text)
            for (var k = 0; k < names.length; k++) {
                section.vars.push({ name: names[k].text, key: names[k].v, spec: spec, init: init,
                                    line: names[k].line, col: names[k].col })
            }
            if (section.constant && !init) fail(names[0].text + " is a CONSTANT, so it needs a value: " + names[0].text + " : ... := ...;", names[0])
        }
        this.next()
        return section
    },

    typeSpec: function() {
        var t = this.peek()
        if (this.isKw("ARRAY")) {
            this.next()
            this.expectOp("[", "after ARRAY")
            var dims = []
            do {
                if (dims.length > 0) this.next()
                var lo = this.expr()
                this.expectOp("..", "between the array's first and last index")
                var hi = this.expr()
                dims.push({ lo: lo, hi: hi })
            } while (this.isOp(","))
            this.expectOp("]", "after the array's indexes")
            this.expectKw("OF", "after ARRAY[...]")
            return { k: "array", dims: dims, of: this.typeSpec(), line: t.line, col: t.col }
        }
        if (this.isKw("STRUCT")) {
            this.next()
            var fields = []
            while (!this.isKw("END_STRUCT")) {
                var ft = this.peek()
                if (ft.t === "eof" || ft.t === "kw") fail("Expected a field or END_STRUCT, found " + this.describe(ft), ft)
                var names = [this.ident("a field name")]
                while (this.isOp(",")) { this.next(); names.push(this.ident("a field name")) }
                this.expectOp(":", "and the field's type")
                var spec = this.typeSpec()
                var init = null
                if (this.isOp(":=")) { this.next(); init = this.initValue() }
                this.expectOp(";", "after the field " + names[0].text)
                for (var k = 0; k < names.length; k++) {
                    fields.push({ name: names[k].text, key: names[k].v, spec: spec, init: init, line: names[k].line, col: names[k].col })
                }
            }
            this.next()
            return { k: "struct", fields: fields, line: t.line, col: t.col }
        }
        if (this.isOp("(")) {
            this.next()
            var values = []
            do {
                if (values.length > 0) this.next()
                var vt = this.ident("an enum value")
                var v = null
                if (this.isOp(":=")) { this.next(); v = this.expr() }
                values.push({ name: vt.text, key: vt.v, value: v, line: vt.line, col: vt.col })
            } while (this.isOp(","))
            this.expectOp(")", "after the enum's values")
            if (this.peek().t === "id" && elementary(this.peek().v)) this.next() // its base type: ignored
            return { k: "enum", values: values, line: t.line, col: t.col }
        }
        var nameTok = this.ident("a type")
        if (nameTok.v === "POINTER" || nameTok.v === "REFERENCE") fail(UNSUPPORTED[nameTok.v] + " aren't supported in CodeSysFish", nameTok)
        if (nameTok.v === "STRING") {
            if (this.isOp("(") || this.isOp("[")) {
                var close = this.next().v === "(" ? ")" : "]"
                var len = this.expr()
                this.expectOp(close, "after the STRING's length")
                return { k: "string", len: len, line: t.line, col: t.col }
            }
        }
        return { k: "named", name: nameTok.text, key: nameTok.v, line: t.line, col: t.col }
    },

    typeBlock: function() {
        this.next()
        var types = []
        do {
            var nameTok = this.ident("the type's name")
            this.expectOp(":", "after the type's name")
            var spec = this.typeSpec()
            var init = null
            if (this.isOp(":=")) { this.next(); init = this.initValue() }
            this.optSemi()
            types.push({ name: nameTok.text, key: nameTok.v, spec: spec, init: init, line: nameTok.line, col: nameTok.col })
        } while (!this.isKw("END_TYPE") && this.peek().t !== "eof")
        this.expectKw("END_TYPE")
        this.optSemi()
        return types
    },

    // An initial value: an expression, [1, 2, 3(0)] for arrays, or
    // (x := 1, y := 2) for structs.
    initValue: function() {
        var t = this.peek()
        if (this.isOp("[")) {
            this.next()
            var items = []
            if (!this.isOp("]")) {
                do {
                    if (items.length > 0) this.next()
                    // n(value) repeats a value n times.
                    if (this.peek().t === "int" && this.isOp("(", this.peek(1))) {
                        var count = this.next().v
                        this.next()
                        var rv = this.initValue()
                        this.expectOp(")", "after the repeated value")
                        items.push({ count: count, value: rv })
                    } else {
                        items.push({ count: 1, value: this.initValue() })
                    }
                } while (this.isOp(","))
            }
            this.expectOp("]", "after the array's values")
            return { e: "arrinit", items: items, line: t.line, col: t.col }
        }
        if (this.isOp("(") && this.peek(1).t === "id" && this.isOp(":=", this.peek(2))) {
            this.next()
            var fields = []
            do {
                if (fields.length > 0) this.next()
                var ft = this.ident("a field name")
                this.expectOp(":=", "after the field's name")
                fields.push({ name: ft.text, key: ft.v, value: this.initValue(), line: ft.line, col: ft.col })
            } while (this.isOp(","))
            this.expectOp(")", "after the struct's values")
            return { e: "structinit", fields: fields, line: t.line, col: t.col }
        }
        return this.expr()
    },

    // Statements up to (not including) one of the end keywords.
    statements: function(ends, caseLabels) {
        var out = []
        for (;;) {
            var t = this.peek()
            if (t.t === "eof") fail("Expected " + ends.join(" or ") + " before the end of the code", t)
            if (t.t === "kw" && ends.indexOf(t.v) >= 0) return out
            if (t.t === "kw" && /^(END_|ELSIF$|ELSE$|UNTIL$|THEN$|DO$|OF$)/.test(t.v)) {
                fail("Expected " + ends.join(" or ") + " before " + t.v, t)
            }
            if (caseLabels && this.caseLabelAhead()) return out
            out.push(this.statement())
        }
    },

    caseLabelAhead: function() {
        var t = this.peek()
        if (t.t === "int" || t.t === "tprefix" || this.isOp("-")) return true
        if (t.t !== "id") return false
        var k = 1
        while (this.isOp(".", this.peek(k)) && this.peek(k + 1).t === "id") k += 2
        var after = this.peek(k)
        return this.isOp(":", after) || this.isOp(",", after) || this.isOp("..", after)
    },

    statement: function() {
        var t = this.peek()
        if (this.isOp(";")) { this.next(); return { s: "empty", line: t.line } }
        if (t.t === "kw") {
            switch (t.v) {
            case "IF": return this.ifStatement()
            case "CASE": return this.caseStatement()
            case "FOR": return this.forStatement()
            case "WHILE":
                this.next()
                var wc = this.expr()
                this.expectKw("DO", "after WHILE's condition")
                var wb = this.statements(["END_WHILE"])
                this.next()
                this.optSemi()
                return { s: "while", cond: wc, body: wb, line: t.line, col: t.col }
            case "REPEAT":
                this.next()
                var rb = this.statements(["UNTIL"])
                this.next()
                var rc = this.expr()
                this.expectKw("END_REPEAT", "after UNTIL's condition")
                this.optSemi()
                return { s: "repeat", cond: rc, body: rb, line: t.line, col: t.col }
            case "EXIT": case "CONTINUE": case "RETURN":
                this.next()
                this.expectOp(";", "after " + t.v)
                return { s: t.v.toLowerCase(), line: t.line, col: t.col }
            }
            fail("A statement can't start with " + this.describe(t), t)
        }
        if (t.t !== "id") fail("A statement can't start with " + this.describe(t), t)
        if (/^(JMP|METHOD|PROPERTY|ACTION|INTERFACE|VAR_EXTERNAL|VAR_CONFIG)$/.test(t.v)) {
            fail(UNSUPPORTED[t.v] + " aren't supported in CodeSysFish", t)
        }
        var target = this.postfix()
        if (target.e === "call" && this.isOp(";")) {
            this.next()
            return { s: "call", call: target, line: t.line, col: t.col }
        }
        var op = this.peek()
        if (this.isOp(":=")) {
            this.next()
            var value = this.expr()
            this.expectOp(";", "after the assignment")
            return { s: "assign", target: target, value: value, line: t.line, col: t.col, at: op }
        }
        // x S= cond; and x R= cond; set or reset x when cond is TRUE.
        if (op.t === "id" && (op.v === "S" || op.v === "R") && this.isOp("=", this.peek(1))) {
            this.next()
            this.next()
            var cond = this.expr()
            this.expectOp(";", "after the assignment")
            return { s: op.v === "S" ? "set" : "reset", target: target, value: cond, line: t.line, col: t.col }
        }
        if (this.isOp("=")) fail("Use := to assign a value (= compares)", op)
        if (target.e === "call") fail("Expected ';' after the call, found " + this.describe(op), op)
        fail("Expected := after " + this.exprText(target) + ", found " + this.describe(op), op)
    },

    exprText: function(e) {
        if (e.e === "name") return e.name
        if (e.e === "member") return this.exprText(e.obj) + "." + e.name
        if (e.e === "index") return this.exprText(e.obj) + "[...]"
        return "it"
    },

    ifStatement: function() {
        var t = this.next()
        var branches = []
        var cond = this.expr()
        this.expectKw("THEN", "after IF's condition")
        branches.push({ cond: cond, body: this.statements(["ELSIF", "ELSE", "END_IF"]) })
        var otherwise = null
        while (this.isKw("ELSIF")) {
            this.next()
            var c = this.expr()
            this.expectKw("THEN", "after ELSIF's condition")
            branches.push({ cond: c, body: this.statements(["ELSIF", "ELSE", "END_IF"]) })
        }
        if (this.isKw("ELSE")) {
            this.next()
            otherwise = this.statements(["END_IF"])
        }
        this.expectKw("END_IF", "to end the IF")
        this.optSemi()
        return { s: "if", branches: branches, otherwise: otherwise, line: t.line, col: t.col }
    },

    caseStatement: function() {
        var t = this.next()
        var selector = this.expr()
        this.expectKw("OF", "after CASE's value")
        var cases = [], otherwise = null
        while (!this.isKw("END_CASE") && !this.isKw("ELSE")) {
            var lt = this.peek()
            if (lt.t === "eof") fail("Expected END_CASE before the end of the code", lt)
            var labels = []
            do {
                if (labels.length > 0) this.next()
                var lo = this.expr()
                var hi = null
                if (this.isOp("..")) { this.next(); hi = this.expr() }
                labels.push({ lo: lo, hi: hi })
            } while (this.isOp(","))
            this.expectOp(":", "after the CASE's value")
            cases.push({ labels: labels, body: this.statements(["END_CASE", "ELSE"], true), line: lt.line })
        }
        if (this.isKw("ELSE")) {
            this.next()
            otherwise = this.statements(["END_CASE"])
        }
        this.expectKw("END_CASE", "to end the CASE")
        this.optSemi()
        return { s: "case", selector: selector, cases: cases, otherwise: otherwise, line: t.line, col: t.col }
    },

    forStatement: function() {
        var t = this.next()
        var v = this.ident("the FOR loop's variable")
        this.expectOp(":=", "after the FOR loop's variable")
        var from = this.expr()
        this.expectKw("TO", "in the FOR loop")
        var to = this.expr()
        var by = null
        if (this.isKw("BY")) { this.next(); by = this.expr() }
        this.expectKw("DO", "in the FOR loop")
        var body = this.statements(["END_FOR"])
        this.next()
        this.optSemi()
        return { s: "for", v: { e: "name", name: v.text, key: v.v, line: v.line, col: v.col },
                 from: from, to: to, by: by, body: body, line: t.line, col: t.col }
    },

    // Expressions, lowest precedence first.
    expr: function() { return this.orExpr() },
    binary: function(next, ops) {
        var a = next.call(this)
        for (;;) {
            var t = this.peek(), op = null
            for (var i = 0; i < ops.length; i++) {
                if ((t.t === "op" || t.t === "kw") && t.v === ops[i]) op = ops[i]
            }
            if (!op) return a
            this.next()
            a = { e: "bin", op: op === "&" ? "AND" : op, a: a, b: next.call(this), line: t.line, col: t.col }
        }
    },
    orExpr: function() { return this.binary(this.xorExpr, ["OR", "OR_ELSE"]) },
    xorExpr: function() { return this.binary(this.andExpr, ["XOR"]) },
    andExpr: function() { return this.binary(this.eqExpr, ["AND", "&", "AND_THEN"]) },
    eqExpr: function() { return this.binary(this.cmpExpr, ["=", "<>"]) },
    cmpExpr: function() { return this.binary(this.addExpr, ["<", ">", "<=", ">="]) },
    addExpr: function() { return this.binary(this.mulExpr, ["+", "-"]) },
    mulExpr: function() { return this.binary(this.powExpr, ["*", "/", "MOD"]) },
    powExpr: function() { return this.binary(this.unary, ["**"]) },
    unary: function() {
        var t = this.peek()
        if (this.isOp("-")) { this.next(); return { e: "un", op: "-", x: this.unary(), line: t.line, col: t.col } }
        if (this.isOp("+")) { this.next(); return this.unary() }
        if (this.isKw("NOT")) { this.next(); return { e: "un", op: "NOT", x: this.unary(), line: t.line, col: t.col } }
        return this.postfix()
    },
    postfix: function() {
        var e = this.primary()
        for (;;) {
            var t = this.peek()
            if (this.isOp(".")) {
                this.next()
                var m = this.peek()
                if (m.t === "int") {
                    fail("Bit access (x.0) isn't supported in CodeSysFish: use (x AND 1) or SHR", m)
                }
                var nameTok = this.ident("a member's name")
                e = { e: "member", obj: e, name: nameTok.text, key: nameTok.v, line: nameTok.line, col: nameTok.col }
            } else if (this.isOp("[")) {
                this.next()
                var idx = [this.expr()]
                while (this.isOp(",")) { this.next(); idx.push(this.expr()) }
                this.expectOp("]", "after the index")
                e = { e: "index", obj: e, index: idx, line: t.line, col: t.col }
            } else if (this.isOp("(") && (e.e === "name" || e.e === "member" || e.e === "index")) {
                this.next()
                var args = []
                if (!this.isOp(")")) {
                    do {
                        if (args.length > 0) this.next()
                        var at = this.peek()
                        if (at.t === "id" && this.isOp(":=", this.peek(1))) {
                            this.next(); this.next()
                            args.push({ name: at.text, key: at.v, value: this.expr(), line: at.line, col: at.col })
                        } else if (at.t === "id" && this.isOp("=>", this.peek(1))) {
                            this.next(); this.next()
                            args.push({ name: at.text, key: at.v, out: this.postfix(), line: at.line, col: at.col })
                        } else {
                            args.push({ value: this.expr(), line: at.line, col: at.col })
                        }
                    } while (this.isOp(","))
                }
                this.expectOp(")", "after the call's values")
                e = { e: "call", callee: e, args: args, line: e.line, col: e.col }
            } else {
                return e
            }
        }
    },
    primary: function() {
        var t = this.peek()
        switch (t.t) {
        case "int": this.next(); return { e: "lit", type: ANY_INT, value: t.v, line: t.line, col: t.col }
        case "real": this.next(); return { e: "lit", type: ANY_REAL, value: t.v, line: t.line, col: t.col }
        case "time": this.next(); return { e: "lit", type: TYPES.TIME, value: t.v, line: t.line, col: t.col }
        case "str": this.next(); return { e: "lit", type: stringType(Math.max(1, t.v.length)), value: t.v, line: t.line, col: t.col, str: true }
        case "tprefix":
            this.next()
            var lit = this.peek()
            var neg = false
            if (this.isOp("-")) { neg = true; this.next(); lit = this.peek() }
            if (lit.t === "id") {
                // EnumType#Value
                this.next()
                return { e: "member", obj: { e: "name", name: t.text, key: t.v, line: t.line, col: t.col },
                         name: lit.text, key: lit.v, line: lit.line, col: lit.col }
            }
            if (lit.t !== "int" && lit.t !== "real" && !this.isKw("TRUE", lit) && !this.isKw("FALSE", lit) && lit.t !== "str") {
                fail("Expected a value after " + t.text + "#", lit)
            }
            this.next()
            var value = lit.t === "kw" ? lit.v === "TRUE" : lit.v
            if (neg) value = -value
            return { e: "lit", typed: t.v, value: value, line: t.line, col: t.col, litKind: lit.t }
        case "kw":
            if (t.v === "TRUE" || t.v === "FALSE") {
                this.next()
                return { e: "lit", type: TYPES.BOOL, value: t.v === "TRUE", line: t.line, col: t.col }
            }
            break
        case "id":
            this.next()
            return { e: "name", name: t.text, key: t.v, line: t.line, col: t.col }
        case "op":
            if (t.v === "(") {
                this.next()
                var inner = this.expr()
                this.expectOp(")", "to close the '('")
                return inner
            }
            break
        }
        fail("Expected a value, found " + this.describe(t), t)
    }
}

function parse(source) {
    return new Parser(lex(source)).unit()
}

// --- Standard function blocks -------------------------------------------------------

function fbVar(name, type, section) {
    return { name: name, key: name, type: type, section: section }
}

var BUILTIN_FBS = {}

function builtinFb(name, inputs, outputs, run) {
    var vars = [], i
    for (i = 0; i < inputs.length; i++) vars.push(fbVar(inputs[i][0], inputs[i][1], "VAR_INPUT"))
    for (i = 0; i < outputs.length; i++) vars.push(fbVar(outputs[i][0], outputs[i][1], "VAR_OUTPUT"))
    var pou = { kind: "FUNCTION_BLOCK", name: name, key: name, builtin: true, vars: vars, varMap: {} }
    for (i = 0; i < vars.length; i++) pou.varMap[vars[i].key] = vars[i]
    pou.run = run
    pou.type = { kind: "fb", name: name, pou: pou }
    BUILTIN_FBS[name] = pou
}

var B = TYPES.BOOL, TIME = TYPES.TIME, INT = TYPES.INT

builtinFb("TON", [["IN", B], ["PT", TIME]], [["Q", B], ["ET", TIME]], function(v, h, rt) {
    if (!v.IN) {
        v.Q = false; v.ET = 0; h.start = null
    } else {
        if (h.start === null || h.start === undefined) h.start = rt.now
        var et = rt.now - h.start
        if (et >= v.PT) { v.Q = true; v.ET = v.PT } else { v.Q = false; v.ET = et }
    }
})
builtinFb("TOF", [["IN", B], ["PT", TIME]], [["Q", B], ["ET", TIME]], function(v, h, rt) {
    if (v.IN) {
        v.Q = true; v.ET = 0; h.start = null
    } else if (v.Q) {
        if (h.start === null || h.start === undefined) h.start = rt.now
        var et = rt.now - h.start
        if (et >= v.PT) { v.Q = false; v.ET = v.PT } else v.ET = et
    }
})
builtinFb("TP", [["IN", B], ["PT", TIME]], [["Q", B], ["ET", TIME]], function(v, h, rt) {
    var running = h.start !== null && h.start !== undefined
    if (!running && v.IN && !h.prev) {
        h.start = rt.now
        running = true
    }
    if (running) {
        var et = rt.now - h.start
        if (et >= v.PT) {
            v.Q = false
            v.ET = v.PT
            if (!v.IN) { h.start = null; v.ET = 0 }
        } else {
            v.Q = true
            v.ET = et
        }
    } else if (!v.IN) {
        v.ET = 0
    }
    h.prev = v.IN
})
builtinFb("R_TRIG", [["CLK", B]], [["Q", B]], function(v, h) {
    v.Q = v.CLK && !h.m
    h.m = v.CLK
})
builtinFb("F_TRIG", [["CLK", B]], [["Q", B]], function(v, h) {
    v.Q = !v.CLK && !!h.m
    h.m = v.CLK
})
builtinFb("CTU", [["CU", B], ["RESET", B], ["PV", INT]], [["Q", B], ["CV", INT]], function(v, h) {
    if (v.RESET) v.CV = 0
    else if (v.CU && !h.cu && v.CV < 32767) v.CV++
    h.cu = v.CU
    v.Q = v.CV >= v.PV
})
builtinFb("CTD", [["CD", B], ["LOAD", B], ["PV", INT]], [["Q", B], ["CV", INT]], function(v, h) {
    if (v.LOAD) v.CV = v.PV
    else if (v.CD && !h.cd && v.CV > -32768) v.CV--
    h.cd = v.CD
    v.Q = v.CV <= 0
})
builtinFb("CTUD", [["CU", B], ["CD", B], ["RESET", B], ["LOAD", B], ["PV", INT]],
          [["QU", B], ["QD", B], ["CV", INT]], function(v, h) {
    if (v.RESET) v.CV = 0
    else if (v.LOAD) v.CV = v.PV
    else {
        var up = v.CU && !h.cu, down = v.CD && !h.cd
        if (up && !down && v.CV < 32767) v.CV++
        else if (down && !up && v.CV > -32768) v.CV--
    }
    h.cu = v.CU
    h.cd = v.CD
    v.QU = v.CV >= v.PV
    v.QD = v.CV <= 0
})
builtinFb("SR", [["SET1", B], ["RESET", B]], [["Q1", B]], function(v) {
    v.Q1 = v.SET1 || (!v.RESET && v.Q1)
})
builtinFb("RS", [["SET", B], ["RESET1", B]], [["Q1", B]], function(v) {
    v.Q1 = !v.RESET1 && (v.SET || v.Q1)
})

// --- Compiler ---------------------------------------------------------------------

function compile(source) {
    var errors = [], warnings = []
    function report(list, e, severity) {
        list.push({ line: e.line, col: e.col, message: e.message, severity: severity })
    }
    var unit
    try {
        unit = parse(String(source || ""))
    } catch (e) {
        if (!(e instanceof StError)) throw e
        report(errors, e, "error")
        return { ok: false, errors: errors, warnings: warnings, app: null }
    }
    var app = null
    try {
        app = new Compiler(unit, function(e) { report(errors, e, "error") },
                           function(e) { report(warnings, e, "warning") }).run()
    } catch (e2) {
        if (!(e2 instanceof StError)) throw e2
        report(errors, e2, "error")
    }
    function byLine(a, b) { return a.line - b.line || a.col - b.col }
    errors.sort(byLine)
    warnings.sort(byLine)
    return { ok: errors.length === 0, errors: errors, warnings: warnings, app: errors.length === 0 ? app : null }
}

function Compiler(unit, onError, onWarning) {
    this.unit = unit
    this.onError = onError
    this.onWarning = onWarning
    this.typeDecls = {}   // TYPE name -> { decl, type, resolving }
    this.pous = {}        // POU name -> info
    this.enumValues = {}  // enum value name -> [{ type, value }]
    this.globals = { kind: "GLOBALS", name: "GVL", key: "GVL", vars: [], varMap: {} }
}

Compiler.prototype = {
    warn: function(message, at) {
        this.onWarning(new StError(message, at ? at.line : 0, at ? at.col : 0))
    },
    // Runs fn, reporting a mistake in it and going on with the next thing.
    attempt: function(fn) {
        try { return fn.call(this) } catch (e) {
            if (!(e instanceof StError)) throw e
            this.onError(e)
            return null
        }
    },

    run: function() {
        var unit = this.unit, self = this, i
        // Names first, so everything can refer to everything.
        for (i = 0; i < unit.types.length; i++) {
            var td = unit.types[i]
            this.attempt(function() {
                self.checkNewName(td.key, td)
                self.typeDecls[td.key] = { decl: td, type: null, resolving: false }
            })
        }
        for (i = 0; i < unit.pous.length; i++) {
            var pd = unit.pous[i]
            this.attempt(function() {
                self.checkNewName(pd.key, pd.nameAt)
                var info = { decl: pd, kind: pd.kind, name: pd.name, key: pd.key, vars: [], varMap: {},
                             retType: null, body: null }
                if (pd.kind === "FUNCTION_BLOCK") info.type = { kind: "fb", name: pd.name, pou: info }
                if (pd.kind === "PROGRAM") info.type = { kind: "program", name: pd.name, pou: info }
                self.pous[pd.key] = info
            })
        }
        for (i = 0; i < unit.types.length; i++) {
            var key = unit.types[i].key
            this.attempt(function() { if (self.typeDecls[key]) self.resolveNamedType(key, self.typeDecls[key].decl) })
        }
        // Struct fields' initial values.
        for (i = 0; i < unit.types.length; i++) {
            var entry = this.typeDecls[unit.types[i].key]
            if (!entry || !entry.type || entry.type.kind !== "struct" || entry.decl !== unit.types[i]) continue
            entry.type.fields.forEach(function(fd) {
                if (!fd.initAst) return
                self.attempt(function() {
                    if (fd.type.kind === "fb") fail("A function block field can't have an initial value", fd.at)
                    fd.init = self.initializer(fd.initAst, fd.type, { pou: null, varMap: {}, init: true })
                })
            })
        }
        // Variables: the global ones, then each POU's.
        for (i = 0; i < unit.globals.length; i++) this.declareSection(this.globals, unit.globals[i])
        var keys = Object.keys(this.pous)
        for (i = 0; i < keys.length; i++) this.declarePou(this.pous[keys[i]])
        for (i = 0; i < this.globals.vars.length; i++) this.compileInit(this.globals, this.globals.vars[i])
        for (i = 0; i < keys.length; i++) {
            var pou = this.pous[keys[i]]
            for (var v = 0; v < pou.vars.length; v++) this.compileInit(pou, pou.vars[v])
        }
        // Then the code.
        for (i = 0; i < keys.length; i++) this.compileBody(this.pous[keys[i]])

        var programs = keys.map(function(k) { return self.pous[k] }).filter(function(p) { return p.kind === "PROGRAM" })
        if (programs.length === 0) fail("There's no PROGRAM to run: add PROGRAM PLC_PRG ... END_PROGRAM", { line: 1, col: 1 })
        var main = this.pous.PLC_PRG && this.pous.PLC_PRG.kind === "PROGRAM" ? this.pous.PLC_PRG : null
        if (!main) {
            programs.sort(function(a, b) { return a.decl.line - b.decl.line })
            main = programs[0]
        }
        return { main: main, programs: programs, pous: this.pous, globals: this.globals }
    },

    checkNewName: function(key, at) {
        if (elementary(key) || key === "STRING") fail("'" + key + "' is a built-in type and can't be redefined", at)
        if (BUILTIN_FBS.hasOwnProperty(key)) fail("'" + key + "' is a standard function block and can't be redefined", at)
        if (BUILTINS.hasOwnProperty(key) || conversionOf(key)) fail("'" + key + "' is a standard function and can't be redefined", at)
        if (KEYWORDS.hasOwnProperty(key)) fail("'" + key + "' is a keyword", at)
        if (this.typeDecls.hasOwnProperty(key) || this.pous.hasOwnProperty(key)) fail("'" + key + "' is defined twice", at)
    },

    // --- types ---
    resolveNamedType: function(key, decl) {
        var entry = this.typeDecls[key]
        if (entry.type) return entry.type
        if (entry.resolving) fail("The type " + decl.name + " contains itself", decl)
        entry.resolving = true
        var spec = decl.spec, t
        if (spec.k === "struct") {
            t = { kind: "struct", name: decl.name, fields: [], fieldMap: {} }
            for (var i = 0; i < spec.fields.length; i++) {
                var fd = spec.fields[i]
                if (t.fieldMap.hasOwnProperty(fd.key)) fail("The field " + fd.name + " is declared twice", fd)
                var field = { name: fd.name, key: fd.key, type: this.resolveType(fd.spec), initAst: fd.init, at: fd }
                t.fields.push(field)
                t.fieldMap[fd.key] = field
            }
        } else if (spec.k === "enum") {
            t = { kind: "enum", name: decl.name, values: [], byValue: {}, valueMap: {} }
            var next = 0
            for (var j = 0; j < spec.values.length; j++) {
                var ev = spec.values[j]
                if (t.valueMap.hasOwnProperty(ev.key)) fail("The value " + ev.name + " is in " + decl.name + " twice", ev)
                var value = next
                if (ev.value) {
                    var c = this.constValue(ev.value, null)
                    if (!c || c.type.kind !== "int") fail("An enum value needs a whole number: " + ev.name + " := 5", ev)
                    value = c.value
                }
                t.values.push({ name: ev.name, key: ev.key, value: value })
                t.valueMap[ev.key] = value
                if (!t.byValue.hasOwnProperty(value)) t.byValue[value] = ev.name
                next = value + 1
                if (!this.enumValues[ev.key]) this.enumValues[ev.key] = []
                this.enumValues[ev.key].push({ type: t, value: value })
            }
        } else {
            t = this.resolveType(spec)
        }
        entry.type = t
        entry.resolving = false
        return t
    },

    resolveType: function(spec) {
        switch (spec.k) {
        case "named":
            var e = elementary(spec.key)
            if (e) return e
            if (this.typeDecls.hasOwnProperty(spec.key)) return this.resolveNamedType(spec.key, this.typeDecls[spec.key].decl)
            if (BUILTIN_FBS.hasOwnProperty(spec.key)) return BUILTIN_FBS[spec.key].type
            if (this.pous.hasOwnProperty(spec.key)) {
                var pou = this.pous[spec.key]
                if (pou.kind === "FUNCTION_BLOCK") return pou.type
                fail(spec.name + " is a " + pou.kind + ", not a type", spec)
            }
            if (UNSUPPORTED.hasOwnProperty(spec.key)) fail(UNSUPPORTED[spec.key] + " aren't supported in CodeSysFish", spec)
            fail("Unknown type '" + spec.name + "'", spec)
            break
        case "string":
            var len = this.constInt(spec.len, "A STRING's length")
            if (len < 1 || len > 65535) fail("A STRING's length must be 1 to 65535", spec)
            return stringType(len)
        case "array":
            var dims = [], total = 1
            for (var i = 0; i < spec.dims.length; i++) {
                var lo = this.constInt(spec.dims[i].lo, "An array's first index")
                var hi = this.constInt(spec.dims[i].hi, "An array's last index")
                if (hi < lo) fail("The array's last index (" + hi + ") is smaller than its first (" + lo + ")", spec)
                dims.push({ lo: lo, hi: hi })
                total *= hi - lo + 1
            }
            if (total > 1000000) fail("That array is too big: at most a million elements", spec)
            var of = this.resolveType(spec.of)
            if (of.kind === "array") {
                dims = dims.concat(of.dims)
                of = of.of
            }
            return this.arrayType(dims, of)
        case "struct": case "enum":
            fail("Declare STRUCTs and enums in a TYPE ... END_TYPE block", spec)
        }
        fail("Unknown type", spec)
    },

    // ARRAY[a..b, c..d] OF T is kept as nested arrays: sub is the type of
    // one element of the outermost dimension.
    arrayType: function(dims, of) {
        var t = { kind: "array", dims: dims, of: of }
        t.name = typeName(t)
        t.sub = dims.length > 1 ? this.arrayType(dims.slice(1), of) : of
        return t
    },

    constInt: function(ast, what) {
        var c = this.constValue(ast, null)
        if (!c || c.type.kind !== "int") fail(what + " must be a constant whole number", ast)
        return c.value
    },

    // The value of a constant expression, or null when it isn't one.
    constValue: function(ast, scope, seen) {
        var self = this
        seen = seen || {}
        switch (ast.e) {
        case "lit":
            if (ast.typed) return this.typedLiteral(ast)
            return { type: ast.type, value: ast.value }
        case "un":
            var x = this.constValue(ast.x, scope, seen)
            if (!x) return null
            if (ast.op === "-" && isNum(x.type)) return { type: x.type, value: x.type.lit ? -x.value : (x.type.kind === "int" ? wrap(-x.value, x.type) : -x.value) }
            if (ast.op === "NOT" && x.type.kind === "bool") return { type: x.type, value: !x.value }
            return null
        case "bin":
            var a = this.constValue(ast.a, scope, seen), b = this.constValue(ast.b, scope, seen)
            if (!a || !b || !isNum(a.type) || !isNum(b.type)) return null
            var ints = a.type.kind === "int" && b.type.kind === "int"
            var t = ints ? (a.type.lit ? b.type : a.type) : (a.type.name === "LREAL" || b.type.name === "LREAL" ? TYPES.LREAL : (a.type.lit && b.type.lit ? ANY_REAL : TYPES.REAL))
            if (ints && a.type.lit && b.type.lit) t = ANY_INT
            var v
            switch (ast.op) {
            case "+": v = a.value + b.value; break
            case "-": v = a.value - b.value; break
            case "*": v = a.value * b.value; break
            case "/":
                if (b.value === 0) fail("Division by zero", ast)
                v = ints ? trunc(a.value / b.value) : a.value / b.value
                break
            case "MOD":
                if (!ints) return null
                if (b.value === 0) fail("Division by zero", ast)
                v = a.value - trunc(a.value / b.value) * b.value
                break
            default: return null
            }
            if (ints && !t.lit) v = wrap(v, t)
            return { type: t, value: v }
        case "name":
            var key = ast.key
            var vars = []
            if (scope && scope.varMap && scope.varMap.hasOwnProperty(key)) vars.push(scope.varMap[key])
            else if (this.globals.varMap.hasOwnProperty(key)) vars.push(this.globals.varMap[key])
            if (vars.length > 0) {
                var vi = vars[0]
                if (!vi.constant || !vi.initAst || seen[key]) return null
                seen[key] = true
                var cv = this.constValue(vi.initAst, vi.owner, seen)
                if (!cv) return null
                return { type: vi.type, value: vi.type.kind === "int" && isNum(cv.type) ? wrap(cv.value, vi.type) : cv.value }
            }
            if (this.enumValues.hasOwnProperty(key) && this.enumValues[key].length === 1) {
                var ev = this.enumValues[key][0]
                return { type: ev.type, value: ev.value }
            }
            return null
        case "member":
            if (ast.obj.e === "name" && this.typeDecls.hasOwnProperty(ast.obj.key)) {
                var et = this.resolveNamedType(ast.obj.key, this.typeDecls[ast.obj.key].decl)
                if (et.kind === "enum" && et.valueMap.hasOwnProperty(ast.key)) return { type: et, value: et.valueMap[ast.key] }
            }
            return null
        }
        return null
    },

    typedLiteral: function(ast) {
        var t = elementary(ast.typed)
        if (!t) {
            if (this.typeDecls.hasOwnProperty(ast.typed)) fail("Write an enum's value as " + ast.typed + "#Name", ast)
            fail("Unknown type '" + ast.typed + "'", ast)
        }
        var v = ast.value
        if (t.kind === "bool") {
            if (typeof v === "boolean") return { type: t, value: v }
            if (v === 0 || v === 1) return { type: t, value: v === 1 }
            fail("BOOL# takes TRUE, FALSE, 0 or 1", ast)
        }
        if (typeof v !== "number") fail(t.name + "# needs a number", ast)
        if (t.kind === "int") {
            if (ast.litKind === "real") fail(t.name + "# needs a whole number", ast)
            if (v !== wrap(v, t)) fail(v + " doesn't fit in " + t.name, ast)
            return { type: t, value: v }
        }
        if (t.kind === "real") return { type: t, value: v }
        if (t.kind === "time") fail("Write a TIME like T#1s500ms", ast)
        if (t.kind === "string") fail("Write a STRING in quotes: 'text'", ast)
        return { type: t, value: v }
    },

    // --- variables ---
    declarePou: function(pou) {
        var self = this, d = pou.decl
        if (pou.kind === "FUNCTION") {
            this.attempt(function() {
                pou.retType = this.resolveType(d.retSpec)
                if (pou.retType.kind === "fb") fail("A FUNCTION can't return a function block", d.retSpec)
                var rv = { name: d.name, key: d.key, type: pou.retType, section: "RETURN", owner: pou, at: d.nameAt }
                pou.vars.push(rv)
                pou.varMap[d.key] = rv
            })
        }
        for (var i = 0; i < d.sections.length; i++) {
            var s = d.sections[i]
            this.attempt(function() {
                if (s.kind === "VAR_GLOBAL") fail("VAR_GLOBAL goes outside the POUs, on its own", s)
                if (pou.kind === "PROGRAM" && s.kind === "VAR_IN_OUT") fail("A PROGRAM can't have VAR_IN_OUT", s)
            })
            this.declareSection(pou, s)
        }
    },

    declareSection: function(owner, s) {
        for (var i = 0; i < s.vars.length; i++) {
            var vd = s.vars[i]
            this.attempt(function() {
                if (owner.varMap.hasOwnProperty(vd.key)) fail("The variable " + vd.name + " is declared twice", vd)
                if (owner.kind === "GLOBALS" && (this.pous.hasOwnProperty(vd.key) || this.typeDecls.hasOwnProperty(vd.key))) {
                    fail("'" + vd.name + "' is already the name of a POU or type", vd)
                }
                var type = this.resolveType(vd.spec)
                if (type.kind === "fb" && owner.kind === "FUNCTION") {
                    fail("A FUNCTION can't have function block instances (it keeps nothing between calls): use a FUNCTION_BLOCK", vd)
                }
                if (s.constant && (type.kind === "fb" || type.kind === "struct" || type.kind === "array")) {
                    // Allowed: their values come from the initial value.
                }
                var section = owner.kind === "GLOBALS" ? "VAR_GLOBAL" : s.kind
                var info = { name: vd.name, key: vd.key, type: type, section: section, constant: s.constant,
                             initAst: vd.init, owner: owner, at: vd }
                owner.vars.push(info)
                owner.varMap[vd.key] = info
            })
        }
    },

    // A variable's initial value: compiled to a function(f, rt) giving it.
    compileInit: function(owner, v) {
        if (!v.initAst || v.section === "VAR_IN_OUT") return
        this.attempt(function() {
            if (v.type.kind === "fb" && v.initAst.e !== "structinit") fail("A function block instance's initial values go like (PT := T#1s)", v.at)
            v.init = this.initializer(v.initAst, v.type, { pou: owner, varMap: owner.varMap, init: true })
        })
    },

    initializer: function(ast, type, scope) {
        var self = this
        if (ast.e === "arrinit") {
            if (type.kind !== "array") fail("[...] gives an array's values, but this is " + typeName(type), ast)
            var leaves = 1
            for (var d = 0; d < type.dims.length; d++) leaves *= type.dims[d].hi - type.dims[d].lo + 1
            var items = [], count = 0
            for (var i = 0; i < ast.items.length; i++) {
                items.push({ count: ast.items[i].count, f: this.initializer(ast.items[i].value, type.of, scope) })
                count += ast.items[i].count
            }
            if (count > leaves) fail("Too many values: the array has " + leaves + " elements", ast)
            return function(f, rt) {
                var flat = []
                for (var a = 0; a < items.length; a++) {
                    for (var c = 0; c < items[a].count; c++) flat.push(items[a].f(f, rt))
                }
                var arr = rt.newValue(type)
                // Fill the nested arrays in order, last index fastest.
                var k = 0
                function fill(level, t) {
                    for (var j = 0; j < level.length && k < flat.length; j++) {
                        if (t.dims.length > 1) fill(level[j], t.sub)
                        else level[j] = flat[k++]
                    }
                }
                fill(arr, type)
                return arr
            }
        }
        if (ast.e === "structinit" && type.kind === "fb") {
            var pou = type.pou, sets = []
            for (var s = 0; s < ast.fields.length; s++) {
                var fs = ast.fields[s]
                if (!pou.varMap.hasOwnProperty(fs.key) || pou.varMap[fs.key].section !== "VAR_INPUT") fail(pou.name + " has no input '" + fs.name + "'", fs)
                var iv = pou.varMap[fs.key]
                sets.push({ key: iv.key, f: this.initializer(fs.value, iv.type, scope) })
            }
            return function(f, rt) {
                var inst = rt.newInstance(pou)
                for (var k = 0; k < sets.length; k++) inst.v[sets[k].key] = sets[k].f(f, rt)
                return inst
            }
        }
        if (ast.e === "structinit") {
            if (type.kind !== "struct") fail("(field := ...) gives a struct's values, but this is " + typeName(type), ast)
            var fields = []
            for (var j = 0; j < ast.fields.length; j++) {
                var fa = ast.fields[j]
                if (!type.fieldMap.hasOwnProperty(fa.key)) fail(type.name + " has no field " + fa.name, fa)
                var field = type.fieldMap[fa.key]
                fields.push({ key: field.key, f: this.initializer(fa.value, field.type, scope) })
            }
            return function(f, rt) {
                var o = rt.newValue(type)
                for (var k = 0; k < fields.length; k++) o[fields[k].key] = fields[k].f(f, rt)
                return o
            }
        }
        var ex = this.expr(ast, scope)
        var conv = this.converter(type, ex, ast, "assign")
        return function(f, rt) { return conv(ex.f(f, rt)) }
    },

    // --- code ---
    compileBody: function(pou) {
        var scope = { pou: pou, varMap: pou.varMap, loops: 0 }
        pou.body = this.block(pou.decl.body, scope)
    },

    block: function(stmts, scope) {
        var fns = []
        for (var i = 0; i < stmts.length; i++) {
            var st = stmts[i]
            var fn = this.attempt(function() { return this.statement(st, scope) })
            if (fn) fns.push(fn)
        }
        var n = fns.length
        if (n === 0) return function() { return NEXT }
        if (n === 1) return fns[0]
        return function(f, rt) {
            for (var k = 0; k < n; k++) {
                var r = fns[k](f, rt)
                if (r !== NEXT) return r
            }
            return NEXT
        }
    },

    condition: function(ast, scope, what) {
        var c = this.expr(ast, scope)
        if (c.type.kind !== "bool") fail(what + " must be BOOL, but it's " + typeName(c.type), ast)
        return c.f
    },

    statement: function(st, scope) {
        var self = this, line = st.line
        switch (st.s) {
        case "empty":
            return null
        case "assign": {
            var lv = this.lvalue(st.target, scope)
            var ex = this.expr(st.value, scope)
            var conv = this.converter(lv.type, ex, st.value, "assign")
            var set = lv.set, get = ex.f
            return function(f, rt) { rt.line = line; set(f, rt, conv(get(f, rt))); return NEXT }
        }
        case "set": case "reset": {
            var lv2 = this.lvalue(st.target, scope)
            if (lv2.type.kind !== "bool") fail(st.s === "set" ? "S= sets a BOOL" : "R= resets a BOOL", st)
            var cond = this.condition(st.value, scope, "The condition")
            var to = st.s === "set", set2 = lv2.set
            return function(f, rt) { rt.line = line; if (cond(f, rt)) set2(f, rt, to); return NEXT }
        }
        case "call": {
            var call = this.call(st.call, scope, true)
            var cf = call.f
            return function(f, rt) { rt.line = line; cf(f, rt); return NEXT }
        }
        case "if": {
            var conds = [], bodies = []
            for (var i = 0; i < st.branches.length; i++) {
                var br = st.branches[i]
                var cf2 = this.attempt(function() { return this.condition(br.cond, scope, i === 0 ? "IF's condition" : "ELSIF's condition") })
                conds.push(cf2 || function() { return false })
                bodies.push(this.block(br.body, scope))
            }
            var otherwise = st.otherwise ? this.block(st.otherwise, scope) : null
            var nb = conds.length
            return function(f, rt) {
                rt.line = line
                for (var k = 0; k < nb; k++) {
                    if (conds[k](f, rt)) return bodies[k](f, rt)
                }
                return otherwise ? otherwise(f, rt) : NEXT
            }
        }
        case "case": {
            var sel = this.expr(st.selector, scope)
            if (sel.type.kind !== "int" && sel.type.kind !== "enum") fail("CASE needs a whole number or an enum, but this is " + typeName(sel.type), st.selector)
            var ranges = [], seen = {}
            for (var c = 0; c < st.cases.length; c++) {
                var cs = st.cases[c]
                var body = this.block(cs.body, scope)
                for (var l = 0; l < cs.labels.length; l++) {
                    var lab = cs.labels[l]
                    this.attempt(function() {
                        var lo = this.caseLabel(lab.lo, sel.type, scope)
                        var hi = lab.hi ? this.caseLabel(lab.hi, sel.type, scope) : lo
                        if (hi < lo) fail("This range runs backwards: " + lo + ".." + hi, lab.lo)
                        if (lo === hi) {
                            if (seen.hasOwnProperty(lo)) fail("The value " + lo + " is in this CASE twice", lab.lo)
                            seen[lo] = true
                        }
                        ranges.push({ lo: lo, hi: hi, body: body })
                    })
                }
            }
            var other = st.otherwise ? this.block(st.otherwise, scope) : null
            var selF = sel.f, nr = ranges.length
            return function(f, rt) {
                rt.line = line
                var v = selF(f, rt)
                for (var k = 0; k < nr; k++) {
                    var r = ranges[k]
                    if (v >= r.lo && v <= r.hi) return r.body(f, rt)
                }
                return other ? other(f, rt) : NEXT
            }
        }
        case "for": {
            var cv = this.lvalue(st.v, scope)
            if (cv.type.kind !== "int") fail("A FOR loop's variable must be a whole number type, but " + st.v.name + " is " + typeName(cv.type), st.v)
            if (cv.inout) fail("A FOR loop's variable can't be a VAR_IN_OUT", st.v)
            var from = this.expr(st.from, scope), toE = this.expr(st.to, scope)
            var fromC = this.converter(cv.type, from, st.from, "assign")
            if (toE.type.kind !== "int") fail("TO needs a whole number", st.to)
            var by = null, byConst = 1
            if (st.by) {
                by = this.expr(st.by, scope)
                if (by.type.kind !== "int") fail("BY needs a whole number", st.by)
                var bc = this.constValue(st.by, scope)
                if (bc) {
                    if (bc.value === 0) fail("BY 0 would never end the loop", st.by)
                    byConst = bc.value
                    by = null
                }
            }
            scope.loops++
            var body2 = this.block(st.body, scope)
            scope.loops--
            var vt = cv.type, getV = cv.get, setV = cv.set, toF = toE.f, fromF = from.f, byF = by ? by.f : null
            return function(f, rt) {
                rt.line = line
                setV(f, rt, fromC(fromF(f, rt)))
                var end = toF(f, rt)
                var step = byF ? byF(f, rt) : byConst
                if (step === 0) throw new RunError("FOR loop with BY 0 never ends", line)
                for (;;) {
                    var v = getV(f, rt)
                    if (step > 0 ? v > end : v < end) return NEXT
                    rt.tick()
                    var r = body2(f, rt)
                    if (r === EXIT) return NEXT
                    if (r === RETURN) return RETURN
                    setV(f, rt, wrap(getV(f, rt) + step, vt))
                }
            }
        }
        case "while": {
            var wc = this.condition(st.cond, scope, "WHILE's condition")
            scope.loops++
            var wb = this.block(st.body, scope)
            scope.loops--
            return function(f, rt) {
                rt.line = line
                while (wc(f, rt)) {
                    rt.tick()
                    var r = wb(f, rt)
                    if (r === EXIT) return NEXT
                    if (r === RETURN) return RETURN
                }
                return NEXT
            }
        }
        case "repeat": {
            scope.loops++
            var rb = this.block(st.body, scope)
            scope.loops--
            var rc = this.condition(st.cond, scope, "UNTIL's condition")
            return function(f, rt) {
                rt.line = line
                do {
                    rt.tick()
                    var r = rb(f, rt)
                    if (r === EXIT) return NEXT
                    if (r === RETURN) return RETURN
                } while (!rc(f, rt))
                return NEXT
            }
        }
        case "exit":
            if (scope.loops === 0) fail("EXIT only works inside a FOR, WHILE or REPEAT loop", st)
            return function() { return EXIT }
        case "continue":
            if (scope.loops === 0) fail("CONTINUE only works inside a FOR, WHILE or REPEAT loop", st)
            return function() { return CONTINUE }
        case "return":
            return function() { return RETURN }
        }
        fail("Unknown statement", st)
    },

    caseLabel: function(ast, selType, scope) {
        if (selType.kind === "enum" && ast.e === "name" && selType.valueMap.hasOwnProperty(ast.key)) return selType.valueMap[ast.key]
        var c = this.constValue(ast, scope)
        if (!c) fail("A CASE value must be a constant", ast)
        if (selType.kind === "enum") {
            if (c.type !== selType && c.type.kind !== "int") fail("This CASE is on " + selType.name + ", but this value is " + typeName(c.type), ast)
            return c.value
        }
        if (c.type.kind !== "int" && c.type.kind !== "enum") fail("A CASE value must be a whole number", ast)
        return c.value
    },

    // --- names and places ---

    // What a name means here: { kind: "var", info } or "enum", "program",
    // "function", "fbtype", "builtin", "conversion".
    lookup: function(key, scope) {
        if (scope.varMap.hasOwnProperty(key)) return { kind: "var", info: scope.varMap[key], global: false }
        if (this.globals.varMap.hasOwnProperty(key)) return { kind: "var", info: this.globals.varMap[key], global: true }
        if (this.enumValues.hasOwnProperty(key)) return { kind: "enum", list: this.enumValues[key] }
        if (this.pous.hasOwnProperty(key)) {
            var p = this.pous[key]
            return { kind: p.kind === "PROGRAM" ? "program" : p.kind === "FUNCTION" ? "function" : "fbtype", pou: p }
        }
        if (this.typeDecls.hasOwnProperty(key)) return { kind: "type", decl: this.typeDecls[key] }
        if (BUILTINS.hasOwnProperty(key)) return { kind: "builtin", fn: BUILTINS[key] }
        var conv = conversionOf(key)
        if (conv) return { kind: "conversion", conv: conv }
        if (BUILTIN_FBS.hasOwnProperty(key)) return { kind: "fbtype", pou: BUILTIN_FBS[key] }
        return null
    },

    // A variable's place: { type, get, set, constant, inout }.
    varPlace: function(info, isGlobal, at) {
        var key = info.key
        var place = { type: info.type, constant: !!info.constant, info: info }
        if (isGlobal) {
            place.get = function(f, rt) { return rt.g[key] }
            place.set = function(f, rt, v) { rt.g[key] = v }
        } else if (info.section === "VAR_IN_OUT") {
            place.inout = true
            place.get = function(f, rt) { return f.v[key].get(rt) }
            place.set = function(f, rt, v) { f.v[key].set(rt, v) }
        } else {
            place.get = function(f) { return f.v[key] }
            place.set = function(f, rt, v) { f.v[key] = v }
        }
        return place
    },

    // Where an expression lives, for reading and writing.
    place: function(ast, scope) {
        var self = this
        if (ast.e === "name") {
            var found = this.lookup(ast.key, scope)
            if (!found) fail("Unknown name '" + ast.name + "'", ast)
            if (found.kind === "var") return this.varPlace(found.info, found.global, ast)
            if (found.kind === "program") {
                var pk = found.pou.key
                return { type: found.pou.type, constant: true, program: true,
                         get: function(f, rt) { return rt.programs[pk] }, set: null }
            }
            return null
        }
        if (ast.e === "member") {
            // An enum's qualified value isn't a place.
            if (ast.obj.e === "name") {
                var on = this.lookup(ast.obj.key, scope)
                if (on && on.kind === "type") return null
            }
            var obj = this.place(ast.obj, scope)
            if (!obj) return null
            var t = obj.type, key = ast.key, og = obj.get
            if (t.kind === "struct") {
                if (!t.fieldMap.hasOwnProperty(key)) fail(t.name + " has no field '" + ast.name + "'", ast)
                return { type: t.fieldMap[key].type, constant: obj.constant,
                         get: function(f, rt) { return og(f, rt)[key] },
                         set: function(f, rt, v) { og(f, rt)[key] = v } }
            }
            if (t.kind === "fb" || t.kind === "program") {
                var pou = t.pou
                if (!pou.varMap.hasOwnProperty(key)) fail(pou.name + " has no variable '" + ast.name + "'", ast)
                var mv = pou.varMap[key]
                if (t.kind === "fb") {
                    if (mv.section !== "VAR_INPUT" && mv.section !== "VAR_OUTPUT") {
                        fail(ast.name + " is internal to " + pou.name + ": from outside, only its inputs and outputs can be used", ast)
                    }
                }
                if (mv.section === "VAR_TEMP") fail(ast.name + " is a VAR_TEMP of " + pou.name + " and only exists while it runs", ast)
                if (mv.section === "VAR_IN_OUT") fail(ast.name + " is a VAR_IN_OUT of " + pou.name + " and can't be used from outside", ast)
                return { type: mv.type, constant: !!mv.constant || (t.kind === "fb" && mv.section === "VAR_OUTPUT"),
                         output: t.kind === "fb" && mv.section === "VAR_OUTPUT",
                         get: function(f, rt) { return og(f, rt).v[key] },
                         set: function(f, rt, v) { og(f, rt).v[key] = v } }
            }
            fail("'" + this.text(ast.obj) + "' is " + typeName(t) + " and has no members", ast)
        }
        if (ast.e === "index") {
            var arr = this.place(ast.obj, scope)
            if (!arr) fail("Only arrays can be indexed", ast)
            var at = arr.type
            if (at.kind !== "array") fail("'" + this.text(ast.obj) + "' is " + typeName(at) + ", not an array", ast)
            if (ast.index.length > at.dims.length) fail("The array has " + at.dims.length + " dimension" + (at.dims.length > 1 ? "s" : ""), ast)
            var getter = arr.get, setter = null, type = at, line = ast.line
            for (var i = 0; i < ast.index.length; i++) {
                var ix = this.expr(ast.index[i], scope)
                if (ix.type.kind !== "int" && ix.type.kind !== "enum") fail("An array index must be a whole number", ast.index[i])
                var lo = type.dims[0].lo, hi = type.dims[0].hi
                var ixc = this.constValue(ast.index[i], scope)
                if (ixc && (ixc.value < lo || ixc.value > hi)) fail("Index " + ixc.value + " is outside the array's " + lo + ".." + hi, ast.index[i])
                getter = this.indexGet(getter, ix.f, lo, hi, line)
                setter = this.indexSet(getter.parent, ix.f, lo, hi, line)
                type = type.sub
            }
            return { type: type, constant: arr.constant, get: getter, set: setter }
        }
        return null
    },

    indexGet: function(parent, ix, lo, hi, line) {
        var g = function(f, rt) {
            var a = parent(f, rt), i = ix(f, rt)
            if (i < lo || i > hi) throw new RunError("Index " + i + " is outside the array's " + lo + ".." + hi, rt.line)
            return a[i - lo]
        }
        g.parent = parent
        return g
    },
    indexSet: function(parent, ix, lo, hi) {
        return function(f, rt, v) {
            var a = parent(f, rt), i = ix(f, rt)
            if (i < lo || i > hi) throw new RunError("Index " + i + " is outside the array's " + lo + ".." + hi, rt.line)
            a[i - lo] = v
        }
    },

    text: function(ast) {
        if (ast.e === "name") return ast.name
        if (ast.e === "member") return this.text(ast.obj) + "." + ast.name
        if (ast.e === "index") return this.text(ast.obj) + "[...]"
        return "it"
    },

    lvalue: function(ast, scope) {
        if (ast.e === "call") fail("A call's result can't be assigned to", ast)
        var p = ast.e === "name" || ast.e === "member" || ast.e === "index" ? this.place(ast, scope) : null
        if (!p || !p.set) fail("Can't assign to " + (ast.e === "lit" ? "a value" : "'" + this.text(ast) + "'"), ast)
        if (p.output) fail(this.text(ast) + " is an output: only its function block sets it", ast)
        if (p.constant) fail("'" + this.text(ast) + "' is a CONSTANT", ast)
        if (p.type.kind === "fb") fail("A function block instance can't be assigned", ast)
        if (scope.init) fail("Initial values can't assign", ast)
        return p
    },

    // --- expressions: { type, f(f, rt) } ---
    expr: function(ast, scope) {
        switch (ast.e) {
        case "lit":
            var lit = ast.typed ? this.typedLiteral(ast) : { type: ast.type, value: ast.value }
            var lv = lit.value
            return { type: lit.type, f: function() { return lv }, constant: true, value: lv }
        case "name": case "member": case "index":
            if (ast.e === "name") {
                var found = this.lookup(ast.key, scope)
                if (!found) fail("Unknown name '" + ast.name + "'", ast)
                if (found.kind === "enum") {
                    if (found.list.length > 1) fail("'" + ast.name + "' is in more than one enum: write it as " + found.list[0].type.name + "." + ast.name, ast)
                    var ev = found.list[0].value
                    return { type: found.list[0].type, f: function() { return ev }, constant: true, value: ev }
                }
                if (found.kind === "function" || found.kind === "builtin" || found.kind === "conversion") fail(ast.name + " is a function: call it with " + ast.name + "(...)", ast)
                if (found.kind === "fbtype") fail(ast.name + " is a function block type: declare an instance of it in VAR", ast)
                if (found.kind === "type") fail(ast.name + " is a type", ast)
            }
            if (ast.e === "member" && ast.obj.e === "name") {
                var on = this.lookup(ast.obj.key, scope)
                if (on && on.kind === "type") {
                    var et = this.resolveNamedType(ast.obj.key, on.decl.decl)
                    if (et.kind !== "enum") fail(ast.obj.name + " is a type, not a variable", ast.obj)
                    if (!et.valueMap.hasOwnProperty(ast.key)) fail(et.name + " has no value '" + ast.name + "'", ast)
                    var qv = et.valueMap[ast.key]
                    return { type: et, f: function() { return qv }, constant: true, value: qv }
                }
            }
            var p = this.place(ast, scope)
            if (!p) fail("'" + this.text(ast) + "' isn't a value", ast)
            if (p.type.kind === "program") fail(this.text(ast) + " is a PROGRAM: use its variables, like " + this.text(ast) + ".x", ast)
            return { type: p.type, f: p.get }
        case "call":
            var c = this.call(ast, scope, false)
            if (c.type === VOID) fail("This call gives no value", ast)
            return c
        case "un":
            return this.unary(ast, scope)
        case "bin":
            return this.binaryExpr(ast, scope)
        case "arrinit": case "structinit":
            fail("[...] and (x := ...) only work as initial values in VAR", ast)
        }
        fail("Unknown expression", ast)
    },

    unary: function(ast, scope) {
        var x = this.expr(ast.x, scope), t = x.type, xf = x.f
        if (ast.op === "-") {
            if (x.constant && isNum(t)) {
                var nv = t.kind === "int" && !t.lit ? wrap(-x.value, t) : -x.value
                return { type: t, f: function() { return nv }, constant: true, value: nv }
            }
            if (t.kind === "int") {
                if (!t.signed) this.warn("Negating an unsigned " + t.name + " wraps around", ast)
                return { type: t, f: function(f, rt) { return wrap(-xf(f, rt), t) } }
            }
            if (t.kind === "real") return { type: t, f: function(f, rt) { return -xf(f, rt) } }
            fail("Can't negate " + typeName(t), ast)
        }
        // NOT
        if (t.kind === "bool") return { type: t, f: function(f, rt) { return !xf(f, rt) } }
        if (t.kind === "int") {
            var it = t.lit ? TYPES.DINT : t
            return { type: it, f: function(f, rt) { return wrap(-xf(f, rt) - 1, it) } }
        }
        fail("NOT works on BOOL and bit strings, not " + typeName(t), ast)
    },

    // The type two numbers make together.
    common: function(a, b, at) {
        if (a.kind === "real" || b.kind === "real") {
            if (a.name === "LREAL" || b.name === "LREAL") return TYPES.LREAL
            if (a.lit && b.lit) return ANY_REAL
            return TYPES.REAL
        }
        if (a.lit && b.lit) return ANY_INT
        if (a.lit) return b
        if (b.lit) return a
        if (a.bits !== b.bits) return a.bits > b.bits ? a : b
        if (a.signed !== b.signed) return a.signed ? b : a
        return a
    },

    binaryExpr: function(ast, scope) {
        var a = this.expr(ast.a, scope), b = this.expr(ast.b, scope)
        var ta = a.type, tb = b.type, af = a.f, bf = b.f, op = ast.op, line = ast.line, self = this
        function bad() {
            var hidden = ""
            ;[[ta, ast.b], [tb, ast.a]].forEach(function(pair) {
                if (pair[0].kind === "enum" && pair[1].e === "name" && pair[0].valueMap.hasOwnProperty(pair[1].key)) {
                    hidden = ": '" + pair[1].name + "' is a variable here, which hides " + pair[0].name + "." + pair[1].name + ". Write " + pair[0].name + "." + pair[1].name
                }
            })
            fail("Can't use " + op + " with " + typeName(ta) + " and " + typeName(tb) + hidden, ast)
        }
        var r
        switch (op) {
        case "AND": case "OR": case "XOR": case "AND_THEN": case "OR_ELSE":
            if (ta.kind === "bool" && tb.kind === "bool") {
                if (op === "AND") r = function(f, rt) { var x = af(f, rt), y = bf(f, rt); return x && y }
                else if (op === "OR") r = function(f, rt) { var x = af(f, rt), y = bf(f, rt); return x || y }
                else if (op === "XOR") r = function(f, rt) { return af(f, rt) !== bf(f, rt) }
                else if (op === "AND_THEN") r = function(f, rt) { return af(f, rt) && bf(f, rt) }
                else r = function(f, rt) { return af(f, rt) || bf(f, rt) }
                return this.fold({ type: TYPES.BOOL, f: r }, a, b)
            }
            if (ta.kind === "int" && tb.kind === "int" && op !== "AND_THEN" && op !== "OR_ELSE") {
                var bt = this.common(ta, tb)
                if (bt.lit) bt = TYPES.DWORD
                r = function(f, rt) { return bitwise(op, af(f, rt), bf(f, rt), bt) }
                return this.fold({ type: bt, f: r }, a, b)
            }
            if ((ta.kind === "bool") !== (tb.kind === "bool")) fail("Can't mix BOOL and " + typeName(ta.kind === "bool" ? tb : ta) + " in " + op, ast)
            bad()
            break
        case "=": case "<>": case "<": case ">": case "<=": case ">=":
            var ok = (isNum(ta) && isNum(tb)) || (ta.kind === tb.kind && ta.kind !== "struct" && ta.kind !== "array" && ta.kind !== "fb")
                || (ta.kind === "enum" && tb.kind === "int") || (ta.kind === "int" && tb.kind === "enum")
            if (ta.kind === "enum" && tb.kind === "enum" && ta !== tb) fail("Can't compare " + ta.name + " with " + tb.name, ast)
            if (ta.kind === "bool" && op !== "=" && op !== "<>") ok = false
            if (!ok) {
                if (ta.kind === "struct" || ta.kind === "array") fail("STRUCTs and arrays can't be compared whole: compare their parts", ast)
                bad()
            }
            switch (op) {
            case "=": r = function(f, rt) { return af(f, rt) === bf(f, rt) }; break
            case "<>": r = function(f, rt) { return af(f, rt) !== bf(f, rt) }; break
            case "<": r = function(f, rt) { return af(f, rt) < bf(f, rt) }; break
            case ">": r = function(f, rt) { return af(f, rt) > bf(f, rt) }; break
            case "<=": r = function(f, rt) { return af(f, rt) <= bf(f, rt) }; break
            default: r = function(f, rt) { return af(f, rt) >= bf(f, rt) }
            }
            return this.fold({ type: TYPES.BOOL, f: r }, a, b)
        case "+": case "-": case "*": case "/": case "MOD": case "**":
            if (ta.kind === "string" || tb.kind === "string") {
                if (op === "+") fail("Strings can't be added with +: use CONCAT(a, b)", ast)
                bad()
            }
            if (ta.kind === "time" || tb.kind === "time") return this.timeArith(ast, a, b)
            if (!isNum(ta) || !isNum(tb)) bad()
            if (op === "**") {
                var pt = ta.name === "LREAL" || tb.name === "LREAL" ? TYPES.LREAL : TYPES.REAL
                return this.fold({ type: pt, f: function(f, rt) { return Math.pow(af(f, rt), bf(f, rt)) } }, a, b)
            }
            var t = this.common(ta, tb)
            if (t.kind === "real") {
                if (op === "MOD") fail("MOD works on whole numbers, not " + t.name, ast)
                switch (op) {
                case "+": r = function(f, rt) { return af(f, rt) + bf(f, rt) }; break
                case "-": r = function(f, rt) { return af(f, rt) - bf(f, rt) }; break
                case "*": r = function(f, rt) { return af(f, rt) * bf(f, rt) }; break
                default: r = function(f, rt) { return af(f, rt) / bf(f, rt) }
                }
                return this.fold({ type: t, f: r }, a, b)
            }
            // Whole numbers: worked out in 32 bits (64 for the L types),
            // like the PLC's registers; assigning wraps to the target's size.
            var wt = t.lit ? TYPES.DINT : t.bits <= 32 ? (t.bits === 32 && !t.signed ? TYPES.UDINT : TYPES.DINT) : t
            switch (op) {
            case "+": r = function(f, rt) { return wrap(af(f, rt) + bf(f, rt), wt) }; break
            case "-": r = function(f, rt) { return wrap(af(f, rt) - bf(f, rt), wt) }; break
            case "*":
                if (wt.bits <= 32) r = function(f, rt) { return wrap(imul(af(f, rt), bf(f, rt)), wt) }
                else r = function(f, rt) { return wrap(af(f, rt) * bf(f, rt), wt) }
                break
            case "/":
                r = function(f, rt) {
                    var y = bf(f, rt)
                    if (y === 0) throw new RunError("Division by zero", rt.line)
                    return wrap(trunc(af(f, rt) / y), wt)
                }
                break
            default:
                r = function(f, rt) {
                    var x = af(f, rt), y = bf(f, rt)
                    if (y === 0) throw new RunError("Division by zero (MOD 0)", rt.line)
                    return x - trunc(x / y) * y
                }
            }
            if ((op === "/" || op === "MOD") && b.constant && b.value === 0) fail("Division by zero", ast)
            return this.fold({ type: t, f: r }, a, b)
        }
        bad()
    },

    // Constant parts are worked out once, while compiling.
    fold: function(result, a, b) {
        if (a.constant && b.constant) {
            var v
            try { v = result.f(null, { line: 0 }) } catch (e) { return result }
            if (result.type.lit && result.type.kind === "int" && Math.abs(v) > 9007199254740991) return result
            return { type: result.type, f: function() { return v }, constant: true, value: v }
        }
        return result
    },

    timeArith: function(ast, a, b) {
        var ta = a.type, tb = b.type, af = a.f, bf = b.f, op = ast.op, T = TYPES.TIME, r
        function tw(v) { return wrap(Math.round(v), TYPES.UDINT) }
        if (ta.kind === "time" && tb.kind === "time") {
            if (op === "+") r = function(f, rt) { return tw(af(f, rt) + bf(f, rt)) }
            else if (op === "-") r = function(f, rt) { return tw(af(f, rt) - bf(f, rt)) }
            else fail("Two TIMEs can only be added or subtracted", ast)
        } else if (ta.kind === "time" && isNum(tb)) {
            if (op === "*") r = function(f, rt) { return tw(af(f, rt) * bf(f, rt)) }
            else if (op === "/") r = function(f, rt) {
                var y = bf(f, rt)
                if (y === 0) throw new RunError("Division by zero", rt.line)
                return tw(af(f, rt) / y)
            }
            else fail("A TIME and a number can only be multiplied or divided: to add, use T#...", ast)
        } else if (isNum(ta) && tb.kind === "time" && op === "*") {
            r = function(f, rt) { return tw(af(f, rt) * bf(f, rt)) }
        } else {
            fail("Can't use " + op + " with " + typeName(ta) + " and " + typeName(tb), ast)
        }
        return this.fold({ type: T, f: r }, a, b)
    },

    // A function turning a value of the expression's type into dst's,
    // with the checks CODESYS makes (errors, or warnings for lost data).
    converter: function(dst, ex, at, how) {
        var src = ex.type, self = this
        function no() {
            fail("Can't assign " + typeName(src) + " to " + typeName(dst) + hint(), at)
        }
        function hint() {
            if (dst.kind === "enum" && at.e === "name" && dst.valueMap.hasOwnProperty(at.key)) {
                return ": '" + at.name + "' is a variable here, which hides " + dst.name + "." + at.name + ". Write " + dst.name + "." + at.name
            }
            if (dst.kind === "time" && src.kind === "int") return ": write a TIME like T#1s, or use " + (src.lit ? "DINT" : src.name) + "_TO_TIME"
            if (src.kind === "bool" && isNum(dst)) return ": use BOOL_TO_" + dst.name
            if (isNum(src) && dst.kind === "bool") return ": use a comparison, like x <> 0"
            if (dst.kind === "string") return ": use " + (src.lit ? "DINT" : src.name) + "_TO_STRING"
            if (src.kind === "string") return ": use STRING_TO_" + dst.name
            return ""
        }
        switch (dst.kind) {
        case "bool":
            if (src.kind !== "bool") no()
            return identity
        case "int":
            if (src.kind === "int") {
                if (src.lit) {
                    if (ex.constant && wrap(ex.value, dst) !== ex.value) this.warn(ex.value + " doesn't fit in " + dst.name + ": it becomes " + wrap(ex.value, dst), at)
                } else if (src.bits > dst.bits || (src.signed && !dst.signed && !dst.bitstr) || (!src.signed && dst.signed && src.bits === dst.bits)) {
                    this.warn("Implicit conversion from " + src.name + " to " + dst.name + " may lose data", at)
                }
                // Always wrapped: arithmetic runs in 32 bits, so INT + INT can
                // be 32768 until it's stored in an INT.
                return function(v) { return wrap(v, dst) }
            }
            if (src.kind === "real") {
                if (!src.lit || !ex.constant || ex.value !== trunc(ex.value)) this.warn("Implicit conversion from " + (src.lit ? "REAL" : src.name) + " to " + dst.name + ": the value is rounded", at)
                return function(v) { return wrap(roundHalfAway(v), dst) }
            }
            if (src.kind === "enum") return function(v) { return wrap(v, dst) }
            no()
            break
        case "real":
            if (src.kind === "real" || src.kind === "int") return identity
            no()
            break
        case "time":
            if (src.kind === "time") return identity
            no()
            break
        case "string":
            if (src.kind !== "string") no()
            if (src.len > dst.len && !(ex.constant && ex.value.length <= dst.len)) {
                if (ex.constant) this.warn("'" + ex.value + "' is longer than " + dst.name + ": it's cut to " + dst.len + " characters", at)
            }
            var len = dst.len
            return function(v) { return v.length > len ? v.substr(0, len) : v }
        case "enum":
            if (src === dst) return identity
            if (src.kind === "int") {
                this.warn("Implicit conversion from " + (src.lit ? "a number" : src.name) + " to " + dst.name + ": use its values, like " + dst.name + "." + (dst.values[0] ? dst.values[0].name : "Value"), at)
                return identity
            }
            no()
            break
        case "struct":
            if (src !== dst) no()
            return function(v) { return copyValue(v, dst) }
        case "array":
            if (src.kind !== "array" || src.name !== dst.name) no()
            return function(v) { return copyValue(v, dst) }
        case "fb":
            fail("A function block instance can't be assigned", at)
        }
        no()
    },

    // --- calls ---
    call: function(ast, scope, asStatement) {
        var callee = ast.callee
        if (callee.e === "name") {
            var found = this.lookup(callee.key, scope)
            // Inside a FUNCTION, its name is its return value, unless it's called.
            if (found && found.kind === "var" && found.info.section === "RETURN") found = { kind: "function", pou: scope.pou }
            if (!found) fail("Unknown function or function block '" + callee.name + "'", callee)
            switch (found.kind) {
            case "builtin": return this.builtinCall(found.fn, callee.key, ast, scope)
            case "conversion": return this.conversionCall(found.conv, callee.name, ast, scope)
            case "function": return this.functionCall(found.pou, ast, scope)
            case "program":
                if (!asStatement) fail("A PROGRAM call gives no value", ast)
                if (ast.args.length > 0) fail("A PROGRAM is called without values: " + callee.name + "();", ast)
                if (found.pou === scope.pou) fail("A PROGRAM can't call itself", ast)
                var prog = found.pou, pk = prog.key
                return { type: VOID, f: function(f, rt) {
                    var inst = rt.programs[pk]
                    rt.enter()
                    rt.resetTemps(inst, prog)
                    prog.body(inst, rt)
                    rt.leave()
                } }
            case "fbtype":
                fail(callee.name + " is a function block type: declare an instance, like myTimer : " + callee.name + ";, and call that", callee)
                break
            case "enum": case "type":
                fail(callee.name + " can't be called", callee)
            }
        }
        var p = this.place(callee, scope)
        if (!p) fail("'" + this.text(callee) + "' can't be called", callee)
        if (p.type.kind !== "fb" && callee.e === "name" && this.pous.hasOwnProperty(callee.key) && this.pous[callee.key].kind === "FUNCTION") {
            fail("'" + callee.name + "' is a variable here, which hides the FUNCTION " + this.pous[callee.key].name + " (names ignore case): rename the variable", callee)
        }
        if (p.type.kind !== "fb") {
            if (p.type.kind === "program") fail("Call a PROGRAM by its name: " + this.text(callee) + "();", callee)
            fail("'" + this.text(callee) + "' is " + typeName(p.type) + " and can't be called", callee)
        }
        if (!asStatement) fail("A function block call gives no value: call it on its own line, then use its outputs, like " + this.text(callee) + ".Q", ast)
        return this.fbCall(p, ast, scope)
    },

    // Matches a call's values to a POU's inputs: { inputs: [{var, ex}],
    // outputs: [{var, place}], inouts: [{var, place}] }.
    bindArgs: function(pou, ast, scope) {
        var inputs = [], outputs = [], inouts = [], named = false, positional = 0, given = {}
        var formals = pou.vars.filter(function(v) { return v.section === "VAR_INPUT" || v.section === "VAR_IN_OUT" })
        for (var i = 0; i < ast.args.length; i++) {
            var arg = ast.args[i], v
            if (arg.out) {
                named = true
                if (!pou.varMap.hasOwnProperty(arg.key) || pou.varMap[arg.key].section !== "VAR_OUTPUT") fail(pou.name + " has no output '" + arg.name + "'", arg)
                v = pou.varMap[arg.key]
                var op = this.lvalue(arg.out, scope)
                outputs.push({ v: v, place: op, conv: this.converter(op.type, { type: v.type }, arg.out, "assign") })
                continue
            }
            if (arg.key) {
                named = true
                if (!pou.varMap.hasOwnProperty(arg.key)) fail(pou.name + " has no input '" + arg.name + "'", arg)
                v = pou.varMap[arg.key]
                if (v.section === "VAR_OUTPUT") fail(arg.name + " is an output of " + pou.name + ": get it with " + arg.name + " => variable", arg)
                if (v.section !== "VAR_INPUT" && v.section !== "VAR_IN_OUT") fail(arg.name + " isn't an input of " + pou.name, arg)
            } else {
                if (named) fail("Values without a name must come before the named ones", arg)
                if (positional >= formals.length) fail(pou.name + " takes " + formals.length + " value" + (formals.length === 1 ? "" : "s"), arg)
                v = formals[positional++]
            }
            if (given[v.key]) fail(v.name + " is given twice", arg)
            given[v.key] = true
            if (v.section === "VAR_IN_OUT") {
                var ip = this.lvalue(arg.value, scope)
                if (ip.type !== v.type && ip.type.name !== v.type.name) fail(v.name + " is " + typeName(v.type) + ", so it needs a variable of that type", arg.value)
                inouts.push({ v: v, place: ip })
            } else {
                var ex = this.expr(arg.value, scope)
                inputs.push({ v: v, f: ex.f, conv: this.converter(v.type, ex, arg.value, "assign") })
            }
        }
        for (var k = 0; k < formals.length; k++) {
            if (formals[k].section === "VAR_IN_OUT" && !given[formals[k].key]) fail("The VAR_IN_OUT " + formals[k].name + " must be given: " + formals[k].name + " := variable", ast)
        }
        return { inputs: inputs, outputs: outputs, inouts: inouts }
    },

    functionCall: function(pou, ast, scope) {
        var b = this.bindArgs(pou, ast, scope)
        var ins = b.inputs, outs = b.outputs, inouts = b.inouts, key = pou.key, line = ast.line
        return { type: pou.retType, f: function(f, rt) {
            var frame = rt.newFrame(pou)
            var i
            for (i = 0; i < ins.length; i++) frame.v[ins[i].v.key] = ins[i].conv(ins[i].f(f, rt))
            for (i = 0; i < inouts.length; i++) frame.v[inouts[i].v.key] = rt.ref(inouts[i].place, f)
            rt.enter()
            pou.body(frame, rt)
            rt.leave()
            rt.line = line
            for (i = 0; i < outs.length; i++) outs[i].place.set(f, rt, outs[i].conv(frame.v[outs[i].v.key]))
            return frame.v[key]
        } }
    },

    fbCall: function(inst, ast, scope) {
        var pou = inst.type.pou
        var b = this.bindArgs(pou, ast, scope)
        var ins = b.inputs, outs = b.outputs, inouts = b.inouts, get = inst.get, line = ast.line
        return { type: VOID, f: function(f, rt) {
            var o = get(f, rt)
            var i
            for (i = 0; i < ins.length; i++) o.v[ins[i].v.key] = ins[i].conv(ins[i].f(f, rt))
            for (i = 0; i < inouts.length; i++) o.v[inouts[i].v.key] = rt.ref(inouts[i].place, f)
            rt.enter()
            if (pou.builtin) pou.run(o.v, o.h, rt)
            else {
                rt.resetTemps(o, pou)
                pou.body(o, rt)
            }
            rt.leave()
            rt.line = line
            for (i = 0; i < outs.length; i++) outs[i].place.set(f, rt, outs[i].conv(o.v[outs[i].v.key]))
        } }
    },

    // Arguments of a standard function: positional only.
    args: function(ast, scope, name, min, max) {
        var n = ast.args.length
        if (n < min || n > max) {
            fail(name + " takes " + (min === max ? min : max === Infinity ? "at least " + min : min + " to " + max) + " value" + (max === 1 ? "" : "s"), ast)
        }
        var out = []
        for (var i = 0; i < n; i++) {
            if (ast.args[i].key || ast.args[i].out) fail(name + " takes its values in order, without names", ast.args[i])
            out.push(this.expr(ast.args[i].value, scope))
        }
        return out
    },

    builtinCall: function(def, name, ast, scope) {
        var a = this.args(ast, scope, name, def.min, def.max)
        var r = def.compile(a, ast, this)
        var res = { type: r.type, f: r.f }
        var allConst = a.every(function(x) { return x.constant })
        if (allConst && def.pure !== false && a.length > 0) {
            try {
                var v = r.f(null, { line: 0, now: 0 })
                return { type: r.type, f: function() { return v }, constant: true, value: v }
            } catch (e) { }
        }
        return res
    },

    conversionCall: function(conv, name, ast, scope) {
        var a = this.args(ast, scope, name, 1, 1)[0]
        var from = a.type, to = conv.to
        if (conv.from) {
            var fromT = elementary(conv.from)
            if (fromT.kind === "string" && from.kind !== "string") fail(name + " needs a STRING", ast.args[0])
            if (fromT.kind !== "string" && from.kind === "string") fail(name + " needs " + conv.from + ", not a STRING: use STRING_TO_" + to.name, ast.args[0])
            if (fromT.kind === "bool" && from.kind !== "bool") fail(name + " needs a BOOL", ast.args[0])
        }
        if (from.kind === "struct" || from.kind === "array" || from.kind === "fb") fail(name + " can't convert " + typeName(from), ast.args[0])
        var fn = convertFn(from, to), af = a.f
        var line = ast.line
        var res = { type: to, f: function(f, rt) { return fn(af(f, rt)) } }
        if (a.constant) {
            var v = fn(a.value)
            return { type: to, f: function() { return v }, constant: true, value: v }
        }
        return res
    }
}

function identity(v) { return v }

function bitwise(op, x, y, t) {
    if (t.bits <= 32) {
        var r = op === "AND" ? (x & y) : op === "OR" ? (x | y) : (x ^ y)
        return wrap(r, t)
    }
    // 64-bit: in two halves.
    var xh = Math.floor(x / TWO32), xl = x - xh * TWO32
    var yh = Math.floor(y / TWO32), yl = y - yh * TWO32
    function one(p, q) { return (op === "AND" ? (p & q) : op === "OR" ? (p | q) : (p ^ q)) >>> 0 }
    return wrap(one(xh, yh) * TWO32 + one(xl, yl), t)
}

// --- Conversions ------------------------------------------------------------------

var CONV_NAMES = ["BOOL", "SINT", "INT", "DINT", "LINT", "USINT", "UINT", "UDINT", "ULINT",
                  "BYTE", "WORD", "DWORD", "LWORD", "REAL", "LREAL", "TIME", "STRING"]

// X_TO_Y and TO_Y: { from, to } or null.
function conversionOf(key) {
    var m = /^(?:([A-Z]+)_)?TO_([A-Z]+)$/.exec(key)
    if (!m) return null
    if (m[1] && CONV_NAMES.indexOf(m[1]) < 0) return null
    if (CONV_NAMES.indexOf(m[2]) < 0) return null
    return { from: m[1] || null, to: elementary(m[2]) }
}

function parseNumberText(s) {
    s = String(s).trim().replace(/_/g, "")
    var m = /^([+-]?)(2|8|16)#([0-9A-Fa-f]+)$/.exec(s)
    if (m) return (m[1] === "-" ? -1 : 1) * parseInt(m[3], parseInt(m[2], 10))
    if (/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(s)) return parseFloat(s)
    return NaN
}

function convertFn(from, to) {
    switch (to.kind) {
    case "bool":
        if (from.kind === "string") return function(v) { var u = v.trim().toUpperCase(); return u === "TRUE" || (u !== "FALSE" && parseNumberText(u) !== 0 && parseNumberText(u) === parseNumberText(u)) }
        return function(v) { return !!v }
    case "int":
        if (from.kind === "bool") return function(v) { return v ? 1 : 0 }
        if (from.kind === "real") return function(v) { return wrap(roundHalfAway(v), to) }
        if (from.kind === "string") return function(v) {
            var n = parseNumberText(v)
            return n === n ? wrap(roundHalfAway(n), to) : 0
        }
        if (from.kind === "time") return function(v) { return wrap(v, to) }
        return function(v) { return wrap(v, to) }
    case "real":
        if (from.kind === "bool") return function(v) { return v ? 1 : 0 }
        if (from.kind === "string") return function(v) { var n = parseNumberText(v); return n === n ? n : 0 }
        return function(v) { return v }
    case "time":
        if (from.kind === "bool") return function(v) { return v ? 1 : 0 }
        if (from.kind === "string") return function(v) {
            var s = v.trim(), m = /^(T|TIME)#(.*)$/i.exec(s)
            var ms = m ? parseDuration(m[2]) : parseNumberText(s)
            return ms === null || ms !== ms ? 0 : wrap(Math.round(ms), TYPES.UDINT)
        }
        if (from.kind === "real") return function(v) { return wrap(roundHalfAway(v), TYPES.UDINT) }
        return function(v) { return wrap(v, TYPES.UDINT) }
    case "string":
        return function(v) { return toStringValue(v, from) }
    }
    return identity
}

// --- Standard functions ----------------------------------------------------------

function numArg(a, name, i, ast) {
    if (!isNum(a.type)) fail(name + " needs a number, not " + typeName(a.type), ast.args[i])
}
function realOf(t) { return t.name === "LREAL" ? TYPES.LREAL : TYPES.REAL }
function strArg(a, name, i, ast) {
    if (a.type.kind !== "string") fail(name + " needs a STRING, not " + typeName(a.type), ast.args[i])
}
function intArg(a, name, i, ast) {
    if (a.type.kind !== "int") fail(name + " needs a whole number, not " + typeName(a.type), ast.args[i])
}
function commonOf(c, list, name, ast) {
    var t = list[0].type
    for (var i = 1; i < list.length; i++) {
        var u = list[i].type
        if (isNum(t) && isNum(u)) t = c.common(t, u)
        else if (t.kind !== u.kind || (t.kind === "enum" && t !== u)) fail(name + " needs values of the same type", ast)
    }
    // Plain numbers stay plain numbers, so LIMIT(0, 150, 100) fits an INT.
    if (t.lit && !list.every(function(x) { return x.constant })) t = t.kind === "int" ? TYPES.DINT : TYPES.LREAL
    return t
}

var BUILTINS = {}

function mathFn(name, fn) {
    BUILTINS[name] = { min: 1, max: 1, compile: function(a, ast) {
        numArg(a[0], name, 0, ast)
        var x = a[0].f
        return { type: realOf(a[0].type), f: function(f, rt) { return fn(x(f, rt)) } }
    } }
}
mathFn("SQRT", Math.sqrt)
mathFn("LN", Math.log)
mathFn("LOG", function(v) { return Math.log(v) / Math.LN10 })
mathFn("EXP", Math.exp)
mathFn("SIN", Math.sin)
mathFn("COS", Math.cos)
mathFn("TAN", Math.tan)
mathFn("ASIN", Math.asin)
mathFn("ACOS", Math.acos)
mathFn("ATAN", Math.atan)

BUILTINS.ABS = { min: 1, max: 1, compile: function(a, ast) {
    numArg(a[0], "ABS", 0, ast)
    var t = a[0].type.lit && !a[0].constant ? (a[0].type.kind === "int" ? TYPES.DINT : TYPES.LREAL) : a[0].type, x = a[0].f
    if (t.kind === "int") return { type: t, f: function(f, rt) { return wrap(Math.abs(x(f, rt)), t) } }
    return { type: t, f: function(f, rt) { return Math.abs(x(f, rt)) } }
} }
BUILTINS.EXPT = { min: 2, max: 2, compile: function(a, ast) {
    numArg(a[0], "EXPT", 0, ast)
    numArg(a[1], "EXPT", 1, ast)
    var x = a[0].f, y = a[1].f
    return { type: realOf(a[0].type.name === "LREAL" ? a[0].type : a[1].type), f: function(f, rt) { return Math.pow(x(f, rt), y(f, rt)) } }
} }
function minMax(name, pick) {
    BUILTINS[name] = { min: 2, max: Infinity, compile: function(a, ast, c) {
        var t = commonOf(c, a, name, ast)
        if (t.kind === "bool" || t.kind === "struct" || t.kind === "array" || t.kind === "fb") fail(name + " needs numbers, TIMEs or STRINGs", ast)
        var fs = a.map(function(x) { return x.f })
        return { type: t, f: function(f, rt) {
            var best = fs[0](f, rt)
            for (var i = 1; i < fs.length; i++) {
                var v = fs[i](f, rt)
                if (pick(v, best)) best = v
            }
            return best
        } }
    } }
}
minMax("MIN", function(v, best) { return v < best })
minMax("MAX", function(v, best) { return v > best })
BUILTINS.LIMIT = { min: 3, max: 3, compile: function(a, ast, c) {
    var t = commonOf(c, a, "LIMIT", ast)
    var mn = a[0].f, x = a[1].f, mx = a[2].f
    return { type: t, f: function(f, rt) {
        var lo = mn(f, rt), v = x(f, rt), hi = mx(f, rt)
        return v < lo ? lo : v > hi ? hi : v
    } }
} }
BUILTINS.SEL = { min: 3, max: 3, compile: function(a, ast, c) {
    if (a[0].type.kind !== "bool") fail("SEL's first value chooses, so it must be BOOL", ast.args[0])
    var t = commonOf(c, [a[1], a[2]], "SEL", ast)
    var g = a[0].f, x0 = a[1].f, x1 = a[2].f
    return { type: t, f: function(f, rt) { return g(f, rt) ? x1(f, rt) : x0(f, rt) } }
} }
BUILTINS.MUX = { min: 2, max: Infinity, compile: function(a, ast, c) {
    intArg(a[0], "MUX", 0, ast)
    var t = commonOf(c, a.slice(1), "MUX", ast)
    var k = a[0].f, fs = a.slice(1).map(function(x) { return x.f })
    return { type: t, f: function(f, rt) {
        var i = k(f, rt)
        if (i < 0 || i >= fs.length) throw new RunError("MUX: " + i + " is outside 0.." + (fs.length - 1), rt.line)
        return fs[i](f, rt)
    } }
} }
function shiftFn(name, fn) {
    BUILTINS[name] = { min: 2, max: 2, compile: function(a, ast) {
        intArg(a[0], name, 0, ast)
        intArg(a[1], name, 1, ast)
        var t = a[0].type.lit ? TYPES.DWORD : a[0].type, x = a[0].f, n = a[1].f
        var bits = t.bits
        return { type: t, f: function(f, rt) {
            // On the bit pattern, as an unsigned number of t's size.
            var m = Math.pow(2, bits)
            var v = x(f, rt), s = n(f, rt)
            var u = v < 0 ? v + m : v
            return wrap(fn(u, s, bits, m), t)
        } }
    } }
}
shiftFn("SHL", function(u, s, bits, m) { return s >= bits ? 0 : (u * Math.pow(2, s)) % m })
shiftFn("SHR", function(u, s, bits) { return s >= bits ? 0 : Math.floor(u / Math.pow(2, s)) })
shiftFn("ROL", function(u, s, bits, m) {
    s = s % bits
    return ((u * Math.pow(2, s)) % m) + Math.floor(u / Math.pow(2, bits - s))
})
shiftFn("ROR", function(u, s, bits, m) {
    s = s % bits
    return Math.floor(u / Math.pow(2, s)) + ((u * Math.pow(2, bits - s)) % m)
})
BUILTINS.TRUNC = { min: 1, max: 1, compile: function(a, ast) {
    numArg(a[0], "TRUNC", 0, ast)
    var x = a[0].f
    return { type: TYPES.DINT, f: function(f, rt) { return wrap(trunc(x(f, rt)), TYPES.DINT) } }
} }
BUILTINS.TRUNC_INT = { min: 1, max: 1, compile: function(a, ast) {
    numArg(a[0], "TRUNC_INT", 0, ast)
    var x = a[0].f
    return { type: TYPES.INT, f: function(f, rt) { return wrap(trunc(x(f, rt)), TYPES.INT) } }
} }
BUILTINS.LEN = { min: 1, max: 1, compile: function(a, ast) {
    strArg(a[0], "LEN", 0, ast)
    var x = a[0].f
    return { type: TYPES.INT, f: function(f, rt) { return x(f, rt).length } }
} }
BUILTINS.LEFT = { min: 2, max: 2, compile: function(a, ast) {
    strArg(a[0], "LEFT", 0, ast); intArg(a[1], "LEFT", 1, ast)
    var s = a[0].f, n = a[1].f
    return { type: STRING, f: function(f, rt) { return s(f, rt).substr(0, Math.max(0, n(f, rt))) } }
} }
BUILTINS.RIGHT = { min: 2, max: 2, compile: function(a, ast) {
    strArg(a[0], "RIGHT", 0, ast); intArg(a[1], "RIGHT", 1, ast)
    var s = a[0].f, n = a[1].f
    return { type: STRING, f: function(f, rt) {
        var v = s(f, rt), k = Math.max(0, n(f, rt))
        return k >= v.length ? v : v.substr(v.length - k)
    } }
} }
BUILTINS.MID = { min: 3, max: 3, compile: function(a, ast) {
    strArg(a[0], "MID", 0, ast); intArg(a[1], "MID", 1, ast); intArg(a[2], "MID", 2, ast)
    var s = a[0].f, n = a[1].f, p = a[2].f
    return { type: STRING, f: function(f, rt) { return s(f, rt).substr(Math.max(0, p(f, rt) - 1), Math.max(0, n(f, rt))) } }
} }
BUILTINS.CONCAT = { min: 2, max: Infinity, compile: function(a, ast) {
    for (var i = 0; i < a.length; i++) strArg(a[i], "CONCAT", i, ast)
    var fs = a.map(function(x) { return x.f })
    return { type: STRING, f: function(f, rt) {
        var out = ""
        for (var k = 0; k < fs.length; k++) out += fs[k](f, rt)
        return out.length > 255 ? out.substr(0, 255) : out
    } }
} }
BUILTINS.INSERT = { min: 3, max: 3, compile: function(a, ast) {
    strArg(a[0], "INSERT", 0, ast); strArg(a[1], "INSERT", 1, ast); intArg(a[2], "INSERT", 2, ast)
    var s1 = a[0].f, s2 = a[1].f, p = a[2].f
    return { type: STRING, f: function(f, rt) {
        var v = s1(f, rt), k = Math.max(0, Math.min(v.length, p(f, rt)))
        return v.substr(0, k) + s2(f, rt) + v.substr(k)
    } }
} }
BUILTINS.DELETE = { min: 3, max: 3, compile: function(a, ast) {
    strArg(a[0], "DELETE", 0, ast); intArg(a[1], "DELETE", 1, ast); intArg(a[2], "DELETE", 2, ast)
    var s = a[0].f, n = a[1].f, p = a[2].f
    return { type: STRING, f: function(f, rt) {
        var v = s(f, rt), k = Math.max(1, p(f, rt)) - 1
        return v.substr(0, k) + v.substr(k + Math.max(0, n(f, rt)))
    } }
} }
BUILTINS.REPLACE = { min: 4, max: 4, compile: function(a, ast) {
    strArg(a[0], "REPLACE", 0, ast); strArg(a[1], "REPLACE", 1, ast); intArg(a[2], "REPLACE", 2, ast); intArg(a[3], "REPLACE", 3, ast)
    var s1 = a[0].f, s2 = a[1].f, n = a[2].f, p = a[3].f
    return { type: STRING, f: function(f, rt) {
        var v = s1(f, rt), k = Math.max(1, p(f, rt)) - 1
        return v.substr(0, k) + s2(f, rt) + v.substr(k + Math.max(0, n(f, rt)))
    } }
} }
BUILTINS.FIND = { min: 2, max: 2, compile: function(a, ast) {
    strArg(a[0], "FIND", 0, ast); strArg(a[1], "FIND", 1, ast)
    var s1 = a[0].f, s2 = a[1].f
    return { type: TYPES.INT, f: function(f, rt) { return s1(f, rt).indexOf(s2(f, rt)) + 1 } }
} }
// TIME(): the time since the PLC started.
BUILTINS.TIME = { min: 0, max: 0, pure: false, compile: function() {
    return { type: TYPES.TIME, f: function(f, rt) { return wrap(rt.now, TYPES.UDINT) } }
} }

// --- Runtime ------------------------------------------------------------------------

function createRuntime(app, options) {
    options = options || {}
    var rt = {
        app: app,
        g: {},            // global variables
        programs: {},     // program instances by name
        now: 0,           // ms since the PLC started
        line: 0,          // the line running
        cycles: 0,
        watchdogMs: options.watchdogMs || 1000,
        maxDepth: 200,
        depth: 0,
        ticks: 0,
        deadline: 0,
        startedAt: null,
        lastError: null
    }

    rt.tick = function() {
        if ((++rt.ticks & 1023) === 0 && Date.now() > rt.deadline) {
            throw new RunError("Watchdog: one cycle ran longer than " + rt.watchdogMs + " ms (an endless loop?)", rt.line)
        }
    }
    rt.enter = function() {
        if (++rt.depth > rt.maxDepth) throw new RunError("Too many nested calls (a function calling itself?)", rt.line)
    }
    rt.leave = function() { rt.depth-- }

    rt.newValue = function(t) {
        switch (t.kind) {
        case "array":
            var n = t.dims[0].hi - t.dims[0].lo + 1, a = []
            for (var i = 0; i < n; i++) a.push(rt.newValue(t.sub))
            return a
        case "struct":
            var o = {}
            for (var j = 0; j < t.fields.length; j++) {
                var fd = t.fields[j]
                o[fd.key] = fd.init ? fd.init(null, rt) : rt.newValue(fd.type)
            }
            return o
        case "fb":
            return rt.newInstance(t.pou)
        }
        return defaultScalar(t)
    }

    rt.newInstance = function(pou) {
        var inst = { pou: pou, v: {}, h: {} }
        for (var i = 0; i < pou.vars.length; i++) {
            var vr = pou.vars[i]
            if (vr.section === "VAR_IN_OUT") { inst.v[vr.key] = null; continue }
            inst.v[vr.key] = vr.init ? vr.init(inst, rt) : rt.newValue(vr.type)
        }
        return inst
    }

    rt.newFrame = function(pou) {
        return rt.newInstance(pou)
    }

    // VAR_TEMP starts again on every call.
    rt.resetTemps = function(inst, pou) {
        for (var i = 0; i < pou.vars.length; i++) {
            var vr = pou.vars[i]
            if (vr.section === "VAR_TEMP") inst.v[vr.key] = vr.init ? vr.init(inst, rt) : rt.newValue(vr.type)
        }
    }

    // A reference to a place, for VAR_IN_OUT.
    rt.ref = function(place, f) {
        return { get: function(r) { return place.get(f, r) }, set: function(r, v) { place.set(f, r, v) } }
    }

    // Every variable back to its initial value.
    rt.reset = function() {
        rt.g = {}
        var gl = app.globals.vars
        var holder = { v: rt.g }
        for (var i = 0; i < gl.length; i++) rt.g[gl[i].key] = gl[i].init ? gl[i].init(holder, rt) : rt.newValue(gl[i].type)
        rt.programs = {}
        for (var j = 0; j < app.programs.length; j++) rt.programs[app.programs[j].key] = rt.newInstance(app.programs[j])
        rt.cycles = 0
        rt.startedAt = null
        rt.now = 0
        rt.lastError = null
    }

    // One PLC cycle at nowMs (any clock in ms; the PLC's time starts at its
    // first cycle). Returns null, or { line, message } if it failed.
    rt.cycle = function(nowMs) {
        if (rt.startedAt === null) rt.startedAt = nowMs
        rt.now = nowMs - rt.startedAt
        rt.deadline = Date.now() + rt.watchdogMs
        rt.ticks = 0
        rt.depth = 0
        rt.line = app.main.decl.line
        var main = app.main
        try {
            rt.resetTemps(rt.programs[main.key], main)
            main.body(rt.programs[main.key], rt)
            rt.cycles++
            return null
        } catch (e) {
            if (e instanceof RunError) {
                rt.lastError = { line: e.line, message: e.message }
            } else {
                rt.lastError = { line: rt.line, message: "Internal error: " + (e && e.message ? e.message : String(e)) }
            }
            return rt.lastError
        }
    }

    // --- the online view ---

    // The children of a value: [{ name, key, type, get, set, section }].
    function children(value, type) {
        var out = []
        if (type.kind === "struct") {
            type.fields.forEach(function(fd) {
                out.push({ name: fd.name, seg: "." + fd.name, type: fd.type,
                           get: function() { return value[fd.key] }, set: function(v) { value[fd.key] = v } })
            })
        } else if (type.kind === "array") {
            var lo = type.dims[0].lo
            for (var i = 0; i < value.length; i++) {
                (function(i) {
                    out.push({ name: "[" + (i + lo) + "]", seg: "[" + (i + lo) + "]", type: type.sub,
                               get: function() { return value[i] }, set: function(v) { value[i] = v } })
                })(i)
            }
        } else if (type.kind === "fb" || type.kind === "program") {
            type.pou.vars.forEach(function(vr) {
                if (vr.section === "VAR_TEMP" || vr.section === "VAR_IN_OUT" || vr.section === "RETURN") return
                out.push({ name: vr.name, seg: "." + vr.name, type: vr.type, section: vr.section, constant: vr.constant,
                           get: function() { return value.v[vr.key] }, set: function(v) { value.v[vr.key] = v } })
            })
        }
        return out
    }

    function roots() {
        var out = []
        var main = app.main
        children(rt.programs[main.key], main.type).forEach(function(c) {
            c.seg = main.name + c.seg
            out.push(c)
        })
        app.programs.forEach(function(p) {
            if (p === main) return
            out.push({ name: p.name, seg: p.name, type: p.type, get: function() { return rt.programs[p.key] } })
        })
        if (app.globals.vars.length > 0) {
            out.push({ name: "Global variables", seg: "GVL", type: { kind: "program", name: "GVL", pou: app.globals },
                       get: function() { return { v: rt.g } } })
        }
        return out
    }

    function isLeaf(t) {
        return t.kind !== "struct" && t.kind !== "array" && t.kind !== "fb" && t.kind !== "program"
    }

    // The rows of the online view: every variable, and the parts of the
    // expanded ones (expanded: { path: true }).
    rt.rows = function(expanded) {
        expanded = expanded || {}
        var out = []
        function add(list, depth, prefix) {
            list.forEach(function(c) {
                var path = prefix + c.seg
                var leaf = isLeaf(c.type)
                var v = c.get()
                var count = leaf ? 0 : c.type.kind === "array" ? v.length : children(v, c.type).length
                out.push({ path: path, name: c.name, depth: depth, type: typeName(c.type),
                           kind: leaf ? (c.type.kind === "bool" ? "bool" : "value") : "node",
                           value: leaf ? formatValue(v, c.type) : (c.type.kind === "array" ? count + " elements" : ""),
                           expanded: !leaf && !!expanded[path], writable: leaf && !c.constant && !!c.set,
                           section: c.section || "" })
                if (!leaf && expanded[path]) add(children(v, c.type), depth + 1, path)
            })
        }
        add(roots(), 0, "")
        return out
    }

    // The entry at a path like "PLC_PRG.timer.ET" or "PLC_PRG.list[3]".
    function find(path) {
        var list = roots(), entry = null, rest = String(path)
        while (rest.length > 0) {
            var match = null
            for (var i = 0; i < list.length; i++) {
                var seg = list[i].seg
                if (rest.toUpperCase().indexOf(seg.toUpperCase()) === 0 &&
                        (rest.length === seg.length || rest.charAt(seg.length) === "." || rest.charAt(seg.length) === "[")) {
                    if (!match || seg.length > match.seg.length) match = list[i]
                }
            }
            if (!match) return null
            entry = match
            rest = rest.substr(match.seg.length)
            if (rest.length > 0) {
                if (isLeaf(entry.type)) return null
                list = children(entry.get(), entry.type)
            }
        }
        return entry
    }

    rt.value = function(path) {
        var e = find(path)
        return e ? e.get() : undefined
    }

    rt.display = function(path) {
        var e = find(path)
        return e && isLeaf(e.type) ? formatValue(e.get(), e.type) : ""
    }

    // Writes a value typed as text ("TRUE", "42", "16#FF", "T#2s",
    // "'text'" or text, an enum's name). Returns "" or why not.
    rt.write = function(path, text) {
        var e = find(path)
        var why = whyNot(e, path, text)
        if (why) return why
        e.set(parseValueText(text, e.type).value)
        return ""
    }

    // What writing would say, without writing: "" or why not.
    rt.check = function(path, text) {
        return whyNot(find(path), path, text)
    }

    function whyNot(e, path, text) {
        if (!e) return "No variable " + path
        if (!isLeaf(e.type) || !e.set) return path + " can't be written"
        if (e.constant) return path + " is a CONSTANT"
        return parseValueText(text, e.type).error || ""
    }

    // The type of the variable at a path, by name ("" if none).
    rt.typeOf = function(path) {
        var e = find(path)
        return e ? typeName(e.type) : ""
    }

    rt.reset()
    return rt
}

// A value typed in the online view, for a variable of type t.
function parseValueText(text, t) {
    var s = String(text).trim()
    switch (t.kind) {
    case "bool":
        var u = s.toUpperCase()
        if (u === "TRUE" || u === "1") return { value: true }
        if (u === "FALSE" || u === "0") return { value: false }
        return { error: "A BOOL is TRUE or FALSE" }
    case "int":
        var n = parseNumberText(s.replace(/^[A-Za-z]+#(?=[0-9+-])/, ""))
        if (n !== n || n !== trunc(n)) return { error: t.name + " needs a whole number" }
        if (wrap(n, t) !== n) {
            var lo = t.signed ? -Math.pow(2, t.bits - 1) : 0, hi = t.signed ? Math.pow(2, t.bits - 1) - 1 : Math.pow(2, t.bits) - 1
            return { error: t.name + " goes from " + lo + " to " + hi }
        }
        return { value: n }
    case "real":
        var r = parseNumberText(s.replace(/^L?REAL#/i, ""))
        if (r !== r) return { error: t.name + " needs a number, like 1.5" }
        return { value: r }
    case "time":
        var m = /^(T|TIME)#(.*)$/i.exec(s)
        var ms = m ? parseDuration(m[2]) : parseNumberText(s)
        if (ms === null || ms !== ms || ms < 0) return { error: "Write a TIME like T#1s500ms, or milliseconds" }
        return { value: wrap(Math.round(ms), TYPES.UDINT) }
    case "string":
        if (s.length >= 2 && s.charAt(0) === "'" && s.charAt(s.length - 1) === "'") s = s.substr(1, s.length - 2)
        else s = String(text)
        return { value: s.length > t.len ? s.substr(0, t.len) : s }
    case "enum":
        var key = s.toUpperCase().replace(/^[A-Z_0-9]+[.#]/, "")
        if (t.valueMap.hasOwnProperty(key)) return { value: t.valueMap[key] }
        var en = parseNumberText(s)
        if (en === en && t.byValue.hasOwnProperty(en)) return { value: en }
        return { error: t.name + " is one of " + t.values.map(function(x) { return x.name }).join(", ") }
    }
    return { error: "Can't write " + typeName(t) }
}

// The words to highlight in the editor, for the syntax highlighter.
function highlightWords() {
    var types = Object.keys(TYPES).concat(["STRING"])
    return {
        keywords: Object.keys(KEYWORDS).filter(function(k) { return k !== "TRUE" && k !== "FALSE" }),
        types: types,
        functions: Object.keys(BUILTINS).concat(Object.keys(BUILTIN_FBS)),
        constants: ["TRUE", "FALSE"]
    }
}
