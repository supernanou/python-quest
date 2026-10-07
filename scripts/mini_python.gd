extends RefCounted
## A tiny Python for the Code Lab. It understands everything in the Beginner
## course: print, input, variables, maths, strings, True/False, if/elif/else,
## for, while, lists, functions (def/return) - and gives Python-style errors.
##
## Usage:
##   var py := MiniPython.new()
##   py.printed.connect(func(text): console.add(text))
##   var ok := await py.run(source)
##   if not ok: show(py.error, py.error_line)

signal printed(text: String)
signal input_requested(prompt: String)
signal _input_received(text: String)

const MAX_STEPS := 200000
const MAX_DEPTH := 100
const MAX_RANGE := 100000
const BUILTINS := ["print", "input", "len", "range", "int", "float", "str", "abs", "max", "min", "sum", "round", "sorted", "type"]
const RESERVED := ["if", "elif", "else", "while", "for", "in", "def", "return", "and", "or", "not", "pass", "break", "continue"]
const TWO_CHAR_OPS := ["**", "//", "==", "!=", "<=", ">=", "+=", "-=", "*=", "/="]
const ONE_CHAR_OPS := "+-*/%<>=()[],:."

var tree: SceneTree  # lets long programs pause each frame so the game doesn't freeze
var scripted_inputs: Array = []  # used for automatic challenge checks
var use_scripted := false
var output := ""  # everything print() wrote
var globals := {}
var error := ""
var error_line := 0
var stopped := false

var _tokens: Array = []
var _pos := 0
var _locals: Array = []
var _flow := ""  # "", "break", "continue" or "return"
var _return_value = null
var _steps := 0
var _waiting_for_input := false


func run(source: String) -> bool:
	output = ""
	error = ""
	error_line = 0
	globals = {}
	_locals = []
	_flow = ""
	_steps = 0
	stopped = false
	var program := _parse(source)
	if error != "":
		return false
	await _exec_block(program)
	return error == ""


func provide_input(text: String) -> void:
	_input_received.emit(text)


func stop() -> void:
	stopped = true
	if _waiting_for_input:
		_input_received.emit("")


func _fail(kind: String, message: String, line: int) -> void:
	if error == "":
		error = "%s: %s" % [kind, message]
		error_line = line


# ================================================================ tokenizer

func _tokenize(source: String) -> Array:
	var tokens := []
	var indents := [0]
	var depth := 0
	var lines := source.replace("\r", "").replace("\t", "    ").split("\n")
	var last_line := 1
	for li in lines.size():
		var line: String = lines[li]
		var n := li + 1
		var i := 0
		if depth == 0:
			var stripped := line.strip_edges()
			if stripped == "" or stripped.begins_with("#"):
				continue
			var indent := 0
			while indent < line.length() and line[indent] == " ":
				indent += 1
			if indent > indents[-1]:
				indents.append(indent)
				tokens.append({"t": "INDENT", "line": n})
			else:
				while indent < indents[-1]:
					indents.pop_back()
					tokens.append({"t": "DEDENT", "line": n})
				if indent != indents[-1]:
					_fail("IndentationError", "unindent does not match any outer indentation level", n)
					return []
			i = indent
		last_line = n
		while i < line.length():
			var c := line[i]
			if c == " ":
				i += 1
			elif c == "#":
				break
			elif c == "\"" or c == "'":
				var j := i + 1
				var text := ""
				var closed := false
				while j < line.length():
					var ch := line[j]
					if ch == "\\" and j + 1 < line.length():
						var esc := line[j + 1]
						text += {"n": "\n", "t": "\t"}.get(esc, esc)
						j += 2
						continue
					if ch == c:
						closed = true
						break
					text += ch
					j += 1
				if not closed:
					_fail("SyntaxError", "unterminated string literal (detected at line %d)" % n, n)
					return []
				tokens.append({"t": "STR", "v": text, "line": n})
				i = j + 1
			elif _is_digit(c):
				var j := i
				while j < line.length() and (_is_digit(line[j]) or line[j] == "."):
					j += 1
				if j < line.length() and _is_letter(line[j]):
					_fail("SyntaxError", "invalid decimal literal (names can't start with a number)", n)
					return []
				var text := line.substr(i, j - i)
				if text.count(".") > 1:
					_fail("SyntaxError", "invalid number '%s'" % text, n)
					return []
				tokens.append({"t": "NUM", "v": text.to_float() if "." in text else text.to_int(), "line": n})
				i = j
			elif _is_letter(c):
				var j := i
				while j < line.length() and (_is_letter(line[j]) or _is_digit(line[j])):
					j += 1
				tokens.append({"t": "NAME", "v": line.substr(i, j - i), "line": n})
				i = j
			else:
				var two := line.substr(i, 2)
				if two in TWO_CHAR_OPS:
					tokens.append({"t": "OP", "v": two, "line": n})
					i += 2
				elif c in ONE_CHAR_OPS:
					if c == "(" or c == "[":
						depth += 1
					elif c == ")" or c == "]":
						depth = maxi(depth - 1, 0)
					tokens.append({"t": "OP", "v": c, "line": n})
					i += 1
				else:
					_fail("SyntaxError", "invalid character '%s'" % c, n)
					return []
		if depth == 0 and not tokens.is_empty() and tokens[-1]["t"] not in ["NEWLINE", "INDENT", "DEDENT"]:
			tokens.append({"t": "NEWLINE", "line": n})
	if depth > 0:
		_fail("SyntaxError", "a bracket ( or [ was never closed", last_line)
		return []
	if not tokens.is_empty() and tokens[-1]["t"] != "NEWLINE":
		tokens.append({"t": "NEWLINE", "line": last_line})
	while indents.size() > 1:
		indents.pop_back()
		tokens.append({"t": "DEDENT", "line": last_line})
	tokens.append({"t": "EOF", "line": last_line})
	return tokens


func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


func _is_letter(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


# ================================================================ parser

func _parse(source: String) -> Array:
	_tokens = _tokenize(source)
	_pos = 0
	var program := []
	if error != "":
		return program
	while _peek()["t"] != "EOF":
		program.append(_statement())
	return program


func _peek(offset := 0) -> Dictionary:
	if error != "" or _pos + offset >= _tokens.size():
		return {"t": "EOF", "line": error_line}
	return _tokens[_pos + offset]


func _next() -> Dictionary:
	var tok := _peek()
	_pos += 1
	return tok


func _is(tok: Dictionary, type: String, value = null) -> bool:
	return tok["t"] == type and (value == null or tok.get("v") == value)


func _expect_op(value: String, message: String) -> bool:
	if _is(_peek(), "OP", value):
		_next()
		return true
	_fail("SyntaxError", message, _peek()["line"])
	return false


func _statement() -> Dictionary:
	var tok := _peek()
	if tok["t"] == "INDENT":
		_fail("IndentationError", "unexpected indent", tok["line"])
		return {}
	if tok["t"] == "NAME":
		match tok["v"]:
			"if":
				return _if_statement()
			"while":
				_next()
				var cond := _expr()
				return {"k": "while", "cond": cond, "body": _block("while", tok["line"]), "line": tok["line"]}
			"for":
				_next()
				var var_tok := _next()
				if var_tok["t"] != "NAME":
					_fail("SyntaxError", "expected a variable name after 'for'", tok["line"])
				if not _is(_next(), "NAME", "in"):
					_fail("SyntaxError", "expected 'in' (like: for i in range(3):)", tok["line"])
				var iter := _expr()
				return {"k": "for", "var": var_tok.get("v", ""), "iter": iter, "body": _block("for", tok["line"]), "line": tok["line"]}
			"def":
				return _def_statement()
			"elif", "else":
				_fail("SyntaxError", "'%s' needs an 'if' before it (check the indentation)" % tok["v"], tok["line"])
				return {}
	var stmt := _simple_statement()
	if not _peek()["t"] in ["NEWLINE", "EOF"]:
		_fail("SyntaxError", "invalid syntax. Perhaps you forgot a comma or a bracket?", _peek()["line"])
	elif _peek()["t"] == "NEWLINE":
		_next()
	return stmt


func _if_statement() -> Dictionary:
	var tok := _next()
	var branches := []
	var cond := _expr()
	branches.append([cond, _block("if", tok["line"])])
	var else_body = null
	while _is(_peek(), "NAME", "elif"):
		var elif_tok := _next()
		var c := _expr()
		branches.append([c, _block("elif", elif_tok["line"])])
	if _is(_peek(), "NAME", "else"):
		var else_tok := _next()
		else_body = _block("else", else_tok["line"])
	return {"k": "if", "branches": branches, "else": else_body, "line": tok["line"]}


func _def_statement() -> Dictionary:
	var tok := _next()
	var name_tok := _next()
	if name_tok["t"] != "NAME":
		_fail("SyntaxError", "expected a function name after 'def'", tok["line"])
	var params := []
	_expect_op("(", "expected '(' after the function name")
	while not _is(_peek(), "OP", ")") and _peek()["t"] != "EOF":
		var p := _next()
		if p["t"] != "NAME":
			_fail("SyntaxError", "function inputs must be names", tok["line"])
			break
		params.append(p["v"])
		if _is(_peek(), "OP", ","):
			_next()
	_expect_op(")", "expected ')'")
	return {"k": "def", "name": name_tok.get("v", ""), "params": params, "body": _block("def", tok["line"]), "line": tok["line"]}


func _block(keyword: String, line: int) -> Array:
	if _is(_peek(), "OP", "="):
		_fail("SyntaxError", "invalid syntax. Maybe you meant '==' instead of '='?", line)
		return []
	if not _expect_op(":", "expected ':' at the end of the '%s' line" % keyword):
		return []
	if _peek()["t"] != "NEWLINE":
		var single := _simple_statement()
		if _peek()["t"] == "NEWLINE":
			_next()
		return [single]
	_next()
	if _peek()["t"] != "INDENT":
		_fail("IndentationError", "expected an indented block after '%s' statement on line %d" % [keyword, line], _peek()["line"])
		return []
	_next()
	var body := []
	while _peek()["t"] != "DEDENT" and _peek()["t"] != "EOF":
		body.append(_statement())
	if _peek()["t"] == "DEDENT":
		_next()
	return body


func _simple_statement() -> Dictionary:
	var tok := _peek()
	if tok["t"] == "NAME":
		match tok["v"]:
			"pass", "break", "continue":
				_next()
				return {"k": tok["v"], "line": tok["line"]}
			"return":
				_next()
				var value = null
				if not _peek()["t"] in ["NEWLINE", "EOF"]:
					value = _expr()
				return {"k": "return", "e": value, "line": tok["line"]}
	var e := _expr()
	var op := _peek()
	if _is(op, "OP", "=") or (op["t"] == "OP" and op["v"] in ["+=", "-=", "*=", "/="]):
		_next()
		if not e.get("k", "") in ["name", "index"]:
			_fail("SyntaxError", "cannot assign to this. The left side of = must be a variable name", tok["line"])
		var value := _expr()
		if op["v"] == "=":
			return {"k": "assign", "target": e, "e": value, "line": tok["line"]}
		return {"k": "aug", "op": op["v"].substr(0, 1), "target": e, "e": value, "line": tok["line"]}
	return {"k": "expr", "e": e, "line": tok["line"]}


func _expr() -> Dictionary:
	return _or_expr()


func _or_expr() -> Dictionary:
	var a := _and_expr()
	while _is(_peek(), "NAME", "or"):
		var tok := _next()
		a = {"k": "bool", "op": "or", "a": a, "b": _and_expr(), "line": tok["line"]}
	return a


func _and_expr() -> Dictionary:
	var a := _not_expr()
	while _is(_peek(), "NAME", "and"):
		var tok := _next()
		a = {"k": "bool", "op": "and", "a": a, "b": _not_expr(), "line": tok["line"]}
	return a


func _not_expr() -> Dictionary:
	if _is(_peek(), "NAME", "not"):
		var tok := _next()
		return {"k": "not", "a": _not_expr(), "line": tok["line"]}
	return _comparison()


func _comparison() -> Dictionary:
	var first := _arith()
	var items := [first]
	var ops := []
	while true:
		var tok := _peek()
		if tok["t"] == "OP" and tok["v"] in ["==", "!=", "<", ">", "<=", ">="]:
			_next()
			ops.append(tok["v"])
		elif _is(tok, "NAME", "in"):
			_next()
			ops.append("in")
		elif _is(tok, "NAME", "not") and _is(_peek(1), "NAME", "in"):
			_next()
			_next()
			ops.append("not in")
		else:
			break
		items.append(_arith())
	if ops.is_empty():
		return first
	return {"k": "cmp", "ops": ops, "items": items, "line": first.get("line", 0)}


func _arith() -> Dictionary:
	var a := _term()
	while _peek()["t"] == "OP" and _peek()["v"] in ["+", "-"]:
		var tok := _next()
		a = {"k": "bin", "op": tok["v"], "a": a, "b": _term(), "line": tok["line"]}
	return a


func _term() -> Dictionary:
	var a := _unary()
	while _peek()["t"] == "OP" and _peek()["v"] in ["*", "/", "//", "%"]:
		var tok := _next()
		a = {"k": "bin", "op": tok["v"], "a": a, "b": _unary(), "line": tok["line"]}
	return a


func _unary() -> Dictionary:
	var tok := _peek()
	if tok["t"] == "OP" and tok["v"] in ["-", "+"]:
		_next()
		return {"k": "unary", "op": tok["v"], "a": _unary(), "line": tok["line"]}
	return _power()


func _power() -> Dictionary:
	var base := _postfix()
	if _is(_peek(), "OP", "**"):
		var tok := _next()
		return {"k": "bin", "op": "**", "a": base, "b": _unary(), "line": tok["line"]}
	return base


func _postfix() -> Dictionary:
	var e := _atom()
	while true:
		var tok := _peek()
		if _is(tok, "OP", "("):
			_next()
			var call := _call_args(tok["line"])
			e = {"k": "call", "f": e, "args": call[0], "kw": call[1], "line": tok["line"]}
		elif _is(tok, "OP", "["):
			_next()
			var index := _expr()
			if _is(_peek(), "OP", ":"):
				_fail("SyntaxError", "slices like [1:3] aren't in the Code Lab yet", tok["line"])
			_expect_op("]", "expected ']'")
			e = {"k": "index", "a": e, "i": index, "line": tok["line"]}
		elif _is(tok, "OP", "."):
			_next()
			var name_tok := _next()
			if name_tok["t"] != "NAME":
				_fail("SyntaxError", "expected a name after '.'", tok["line"])
			if _is(_peek(), "OP", "("):
				_next()
				var call := _call_args(tok["line"])
				e = {"k": "method", "obj": e, "name": name_tok.get("v", ""), "args": call[0], "line": tok["line"]}
			else:
				_fail("SyntaxError", "methods need brackets, like .upper()", tok["line"])
		else:
			break
	return e


func _call_args(line: int) -> Array:
	var args := []
	var kw := {}
	while not _is(_peek(), "OP", ")") and _peek()["t"] != "EOF":
		if _peek()["t"] == "NAME" and _is(_peek(1), "OP", "="):
			var name: String = _next()["v"]
			_next()
			kw[name] = _expr()
		else:
			args.append(_expr())
		if _is(_peek(), "OP", ","):
			_next()
		elif not _is(_peek(), "OP", ")"):
			_fail("SyntaxError", "invalid syntax. Perhaps you forgot a comma?", line)
			break
	_expect_op(")", "expected ')' - a bracket was never closed")
	return [args, kw]


func _atom() -> Dictionary:
	var tok := _next()
	match tok["t"]:
		"NUM":
			return {"k": "lit", "v": tok["v"], "line": tok["line"]}
		"STR":
			var text: String = tok["v"]
			while _peek()["t"] == "STR":
				text += _next()["v"]
			return {"k": "lit", "v": text, "line": tok["line"]}
		"NAME":
			var name: String = tok["v"]
			if name == "True":
				return {"k": "lit", "v": true, "line": tok["line"]}
			if name == "False":
				return {"k": "lit", "v": false, "line": tok["line"]}
			if name == "None":
				return {"k": "lit", "v": null, "line": tok["line"]}
			if name in RESERVED:
				_fail("SyntaxError", "invalid syntax ('%s' can't be used here)" % name, tok["line"])
				return {}
			return {"k": "name", "n": name, "line": tok["line"]}
		"OP":
			if tok["v"] == "(":
				var inner := _expr()
				if _is(_peek(), "OP", ","):
					_fail("SyntaxError", "tuples like (1, 2) aren't in the Code Lab - use a list [1, 2]", tok["line"])
				_expect_op(")", "expected ')'")
				return inner
			if tok["v"] == "[":
				var items := []
				while not _is(_peek(), "OP", "]") and _peek()["t"] != "EOF":
					items.append(_expr())
					if _is(_peek(), "OP", ","):
						_next()
					elif not _is(_peek(), "OP", "]"):
						_fail("SyntaxError", "invalid syntax. Perhaps you forgot a comma?", tok["line"])
						break
				_expect_op("]", "expected ']'")
				return {"k": "list", "items": items, "line": tok["line"]}
	if tok["t"] == "NEWLINE" or tok["t"] == "EOF":
		_fail("SyntaxError", "invalid syntax - this line ends too early", tok["line"])
	else:
		_fail("SyntaxError", "invalid syntax", tok["line"])
	return {}


# ================================================================ running

func _exec_block(stmts: Array) -> void:
	for stmt in stmts:
		await _exec(stmt)
		if error != "" or _flow != "":
			return


func _exec(s: Dictionary) -> void:
	_steps += 1
	if stopped:
		_fail("Stopped", "you pressed Stop", s.get("line", 0))
		return
	if _steps > MAX_STEPS:
		_fail("TooLong", "your program ran for too long. Is there a loop that never ends?", s.get("line", 0))
		return
	if tree != null and _steps % 3000 == 0:
		await tree.process_frame
	var line: int = s.get("line", 0)
	match s.get("k", ""):
		"expr":
			await _eval(s["e"])
		"assign":
			var value = await _eval(s["e"])
			if error == "":
				await _assign(s["target"], value, line)
		"aug":
			var current = await _eval(s["target"])
			var value = await _eval(s["e"])
			if error == "":
				var result = _binop(s["op"], current, value, line)
				if error == "":
					await _assign(s["target"], result, line)
		"if":
			for branch in s["branches"]:
				var cond = await _eval(branch[0])
				if error != "":
					return
				if _truthy(cond):
					await _exec_block(branch[1])
					return
			if s["else"] != null:
				await _exec_block(s["else"])
		"while":
			while true:
				var cond = await _eval(s["cond"])
				if error != "" or not _truthy(cond):
					return
				await _exec_block(s["body"])
				if error != "" or _flow == "return":
					return
				if _flow == "break":
					_flow = ""
					return
				_flow = ""
				_steps += 1
				if _steps > MAX_STEPS:
					_fail("TooLong", "your program ran for too long. Is there a loop that never ends?", line)
					return
		"for":
			var iterable = await _eval(s["iter"])
			if error != "":
				return
			var items: Array
			if iterable is Array:
				items = iterable.duplicate()
			elif iterable is String:
				items = []
				for ch in iterable:
					items.append(ch)
			else:
				_fail("TypeError", "'%s' object is not iterable" % _type_name(iterable), line)
				return
			for item in items:
				_set_var(s["var"], item)
				await _exec_block(s["body"])
				if error != "" or _flow == "return":
					return
				if _flow == "break":
					_flow = ""
					return
				_flow = ""
		"def":
			_set_var(s["name"], {"__func__": true, "name": s["name"], "params": s["params"], "body": s["body"]})
		"return":
			if _locals.is_empty():
				_fail("SyntaxError", "'return' outside function", line)
				return
			_return_value = null
			if s["e"] != null:
				_return_value = await _eval(s["e"])
			_flow = "return"
		"break":
			_flow = "break"
		"continue":
			_flow = "continue"
		"pass":
			pass


func _set_var(name: String, value) -> void:
	if _locals.is_empty():
		globals[name] = value
	else:
		_locals[-1][name] = value


func _assign(target: Dictionary, value, line: int) -> void:
	if target["k"] == "name":
		_set_var(target["n"], value)
		return
	var obj = await _eval(target["a"])
	var index = await _eval(target["i"])
	if error != "":
		return
	if obj is String:
		_fail("TypeError", "'str' object does not support item assignment", line)
	elif obj is Array:
		var i := _check_index(obj, index, "list", line)
		if error == "":
			obj[i] = value
	else:
		_fail("TypeError", "'%s' object does not support item assignment" % _type_name(obj), line)


func _eval(e: Dictionary):
	if error != "":
		return null
	var line: int = e.get("line", 0)
	match e.get("k", ""):
		"lit":
			return e["v"]
		"name":
			var name: String = e["n"]
			if not _locals.is_empty() and _locals[-1].has(name):
				return _locals[-1][name]
			if globals.has(name):
				return globals[name]
			if name in BUILTINS:
				return {"__builtin__": name}
			_fail("NameError", "name '%s' is not defined" % name, line)
			return null
		"list":
			var items := []
			for item in e["items"]:
				items.append(await _eval(item))
			return items
		"bin":
			var a = await _eval(e["a"])
			var b = await _eval(e["b"])
			if error != "":
				return null
			return _binop(e["op"], a, b, line)
		"unary":
			var a = await _eval(e["a"])
			if error != "":
				return null
			if typeof(a) == TYPE_BOOL:
				a = int(a)
			if not (a is int or a is float):
				_fail("TypeError", "bad operand type for unary %s: '%s'" % [e["op"], _type_name(a)], line)
				return null
			return -a if e["op"] == "-" else a
		"bool":
			var a = await _eval(e["a"])
			if error != "":
				return null
			# Python returns one of the two values (it stops early if it can)
			if _truthy(a) == (e["op"] == "or"):
				return a
			return await _eval(e["b"])
		"not":
			var a = await _eval(e["a"])
			return not _truthy(a)
		"cmp":
			var left = await _eval(e["items"][0])
			for i in e["ops"].size():
				var right = await _eval(e["items"][i + 1])
				if error != "":
					return null
				if not _compare(e["ops"][i], left, right, line):
					return false
				left = right
			return true
		"call":
			var f = await _eval(e["f"])
			var args := []
			for arg in e["args"]:
				args.append(await _eval(arg))
			var kw := {}
			for key in e["kw"]:
				kw[key] = await _eval(e["kw"][key])
			if error != "":
				return null
			return await _call(f, args, kw, line)
		"index":
			var obj = await _eval(e["a"])
			var index = await _eval(e["i"])
			if error != "":
				return null
			if obj is Array or obj is String:
				var i := _check_index(obj, index, "list" if obj is Array else "string", line)
				return null if error != "" else obj[i]
			_fail("TypeError", "'%s' object is not subscriptable" % _type_name(obj), line)
			return null
		"method":
			var obj = await _eval(e["obj"])
			var args := []
			for arg in e["args"]:
				args.append(await _eval(arg))
			if error != "":
				return null
			return _method(obj, e["name"], args, line)
	return null


func _check_index(obj, index, kind: String, line: int) -> int:
	if typeof(index) == TYPE_BOOL:
		index = int(index)
	if not index is int:
		_fail("TypeError", "%s indices must be integers, not %s" % [kind, _type_name(index)], line)
		return 0
	var i: int = index
	if i < 0:
		i += obj.length() if obj is String else obj.size()
	var size: int = obj.length() if obj is String else obj.size()
	if i < 0 or i >= size:
		_fail("IndexError", "%s index out of range" % kind, line)
		return 0
	return i


func _call(f, args: Array, kw: Dictionary, line: int):
	if f is Dictionary and f.has("__builtin__"):
		return await _builtin(f["__builtin__"], args, kw, line)
	if f is Dictionary and f.has("__func__"):
		var params: Array = f["params"]
		if not kw.is_empty():
			for key in kw:
				if not key in params:
					_fail("TypeError", "%s() got an unexpected keyword argument '%s'" % [f["name"], key], line)
					return null
		var values := {}
		for i in params.size():
			if i < args.size():
				values[params[i]] = args[i]
			elif kw.has(params[i]):
				values[params[i]] = kw[params[i]]
			else:
				_fail("TypeError", "%s() missing an input: '%s'" % [f["name"], params[i]], line)
				return null
		if args.size() > params.size():
			_fail("TypeError", "%s() takes %d input(s) but %d were given" % [f["name"], params.size(), args.size()], line)
			return null
		if _locals.size() >= MAX_DEPTH:
			_fail("RecursionError", "maximum recursion depth exceeded", line)
			return null
		_locals.append(values)
		await _exec_block(f["body"])
		_locals.pop_back()
		var result = null
		if _flow == "return":
			result = _return_value
		_flow = ""
		_return_value = null
		return result
	_fail("TypeError", "'%s' object is not callable" % _type_name(f), line)
	return null


func _builtin(name: String, args: Array, kw: Dictionary, line: int):
	match name:
		"print":
			var sep: String = _str(kw.get("sep", " "))
			var end: String = _str(kw.get("end", "\n"))
			var parts := PackedStringArray()
			for a in args:
				parts.append(_str(a))
			var text := sep.join(parts) + end
			output += text
			printed.emit(text)
			return null
		"input":
			var prompt := _str(args[0]) if args.size() > 0 else ""
			printed.emit(prompt)
			var value := ""
			if use_scripted:
				value = scripted_inputs.pop_front() if not scripted_inputs.is_empty() else ""
			else:
				_waiting_for_input = true
				input_requested.emit(prompt)
				value = await _input_received
				_waiting_for_input = false
			printed.emit(value + "\n")
			return value
		"len":
			if args.size() != 1:
				_fail("TypeError", "len() takes exactly one argument (%d given)" % args.size(), line)
				return null
			if args[0] is String:
				return args[0].length()
			if args[0] is Array:
				return args[0].size()
			_fail("TypeError", "object of type '%s' has no len()" % _type_name(args[0]), line)
			return null
		"range":
			var nums := []
			for a in args:
				if typeof(a) == TYPE_BOOL:
					a = int(a)
				if not a is int:
					_fail("TypeError", "'%s' object cannot be interpreted as an integer" % _type_name(a), line)
					return null
				nums.append(a)
			if nums.is_empty() or nums.size() > 3:
				_fail("TypeError", "range() needs 1, 2 or 3 numbers", line)
				return null
			var start: int = 0 if nums.size() == 1 else nums[0]
			var stop: int = nums[0] if nums.size() == 1 else nums[1]
			var step: int = nums[2] if nums.size() == 3 else 1
			if step == 0:
				_fail("ValueError", "range() arg 3 must not be zero", line)
				return null
			var result := []
			var i := start
			while (step > 0 and i < stop) or (step < 0 and i > stop):
				result.append(i)
				i += step
				if result.size() > MAX_RANGE:
					_fail("TooLong", "that range is too big for the Code Lab", line)
					return null
			return result
		"int":
			if args.is_empty():
				return 0
			var v = args[0]
			if v is String:
				var s: String = v.strip_edges()
				if s.is_valid_int():
					return s.to_int()
				_fail("ValueError", "invalid literal for int() with base 10: %s" % _repr(v), line)
				return null
			if v is float or v is int or typeof(v) == TYPE_BOOL:
				return int(v)
			_fail("TypeError", "int() can't convert %s" % _type_name(v), line)
			return null
		"float":
			if args.is_empty():
				return 0.0
			var v = args[0]
			if v is String:
				if v.strip_edges().is_valid_float():
					return v.strip_edges().to_float()
				_fail("ValueError", "could not convert string to float: %s" % _repr(v), line)
				return null
			if v is float or v is int or typeof(v) == TYPE_BOOL:
				return float(v)
			_fail("TypeError", "float() can't convert %s" % _type_name(v), line)
			return null
		"str":
			return _str(args[0]) if args.size() > 0 else ""
		"type":
			return "<class '%s'>" % _type_name(args[0] if args.size() > 0 else null)
		"abs":
			if args.size() == 1 and (args[0] is int or args[0] is float):
				return absi(args[0]) if args[0] is int else absf(args[0])
			_fail("TypeError", "abs() needs one number", line)
			return null
		"round":
			if args.is_empty() or not (args[0] is int or args[0] is float):
				_fail("TypeError", "round() needs a number", line)
				return null
			if args.size() > 1:
				var p := pow(10.0, args[1])
				return round(args[0] * p) / p
			var x: float = args[0]
			var r := floorf(x + 0.5)
			if is_equal_approx(x + 0.5, r) and int(r) % 2 != 0:
				r -= 1
			return int(r)
		"max", "min", "sum", "sorted":
			var items: Array = args[0] if args.size() == 1 and args[0] is Array else args
			if name == "sum":
				var total = 0
				for item in items:
					total = _binop("+", total, item, line)
				return total
			if name == "sorted":
				var copy := items.duplicate()
				copy.sort_custom(func(a, b): return _compare("<", a, b, line))
				return copy
			if items.is_empty():
				_fail("ValueError", "%s() arg is an empty sequence" % name, line)
				return null
			var best = items[0]
			for item in items:
				if _compare(">" if name == "max" else "<", item, best, line):
					best = item
			return best
	return null


func _method(obj, name: String, args: Array, line: int):
	if obj is Array:
		match name:
			"append":
				obj.append(args[0] if args.size() > 0 else null)
				return null
			"pop":
				if obj.is_empty():
					_fail("IndexError", "pop from empty list", line)
					return null
				if args.size() > 0:
					var i := _check_index(obj, args[0], "pop", line)
					return null if error != "" else obj.pop_at(i)
				return obj.pop_back()
			"insert":
				if args.size() == 2 and args[0] is int:
					obj.insert(clampi(args[0] if args[0] >= 0 else obj.size() + args[0], 0, obj.size()), args[1])
					return null
			"remove", "index", "count":
				var found := -1
				var count := 0
				for i in obj.size():
					if _equals(obj[i], args[0] if args.size() > 0 else null):
						count += 1
						if found == -1:
							found = i
				if name == "count":
					return count
				if found == -1:
					_fail("ValueError", "%s is not in list" % _repr(args[0] if args.size() > 0 else null), line)
					return null
				if name == "index":
					return found
				obj.remove_at(found)
				return null
			"sort":
				obj.sort_custom(func(a, b): return _compare("<", a, b, line))
				return null
			"reverse":
				obj.reverse()
				return null
	elif obj is String:
		match name:
			"upper":
				return obj.to_upper()
			"lower":
				return obj.to_lower()
			"strip":
				return obj.strip_edges()
			"title", "capitalize":
				return obj.capitalize() if name == "title" else obj.substr(0, 1).to_upper() + obj.substr(1).to_lower()
			"replace":
				if args.size() == 2:
					return obj.replace(_str(args[0]), _str(args[1]))
			"split":
				if args.is_empty():
					return Array(obj.split(" ", false))
				return Array(obj.split(_str(args[0])))
			"join":
				if args.size() == 1 and args[0] is Array:
					var parts := PackedStringArray()
					for item in args[0]:
						if not item is String:
							_fail("TypeError", "sequence item: expected str, %s found" % _type_name(item), line)
							return null
						parts.append(item)
					return obj.join(parts)
			"count":
				return obj.count(_str(args[0])) if args.size() > 0 else 0
			"startswith":
				return obj.begins_with(_str(args[0])) if args.size() > 0 else false
			"endswith":
				return obj.ends_with(_str(args[0])) if args.size() > 0 else false
			"find":
				return obj.find(_str(args[0])) if args.size() > 0 else -1
			"isdigit":
				return obj != "" and obj.is_valid_int() and not ("-" in obj or "+" in obj)
	_fail("AttributeError", "'%s' object has no attribute '%s'" % [_type_name(obj), name], line)
	return null


# ================================================================ values

func _binop(op: String, a, b, line: int):
	if typeof(a) == TYPE_BOOL:
		a = int(a)
	if typeof(b) == TYPE_BOOL:
		b = int(b)
	var a_num: bool = a is int or a is float
	var b_num: bool = b is int or b is float
	match op:
		"+":
			if a_num and b_num:
				return a + b
			if a is String and b is String:
				return a + b
			if a is Array and b is Array:
				return a + b
			if a is String:
				_fail("TypeError", "can only concatenate str (not \"%s\") to str" % _type_name(b), line)
				return null
			if a is Array:
				_fail("TypeError", "can only concatenate list (not \"%s\") to list" % _type_name(b), line)
				return null
		"*":
			if a_num and b_num:
				return a * b
			if (a is String or a is Array) and b is int:
				return _repeat(a, b)
			if a is int and (b is String or b is Array):
				return _repeat(b, a)
			if (a is String or a is Array) and b is float or (b is String or b is Array) and a is float:
				_fail("TypeError", "can't multiply sequence by non-int of type 'float'", line)
				return null
		"-", "/", "//", "%", "**":
			if a_num and b_num:
				if op in ["/", "//", "%"] and b == 0:
					_fail("ZeroDivisionError", "division by zero" if op == "/" else "integer division or modulo by zero", line)
					return null
				match op:
					"-":
						return a - b
					"/":
						return float(a) / float(b)
					"//":
						if a is int and b is int:
							var q: int = a / b
							if a % b != 0 and ((a < 0) != (b < 0)):
								q -= 1
							return q
						return floorf(float(a) / float(b))
					"%":
						if a is int and b is int:
							var r: int = a % b
							if r != 0 and ((r < 0) != (b < 0)):
								r += b
							return r
						return a - b * floorf(float(a) / float(b))
					"**":
						if a is int and b is int and b >= 0 and b <= 62:
							var result := 1
							for i in b:
								result *= a
							return result
						return pow(float(a), float(b))
	_fail("TypeError", "unsupported operand type(s) for %s: '%s' and '%s'" % [op, _type_name(a), _type_name(b)], line)
	return null


func _repeat(value, times: int):
	if value is String:
		return value.repeat(maxi(times, 0))
	var result := []
	for i in maxi(times, 0):
		result.append_array(value)
	return result


func _compare(op: String, a, b, line: int) -> bool:
	match op:
		"==":
			return _equals(a, b)
		"!=":
			return not _equals(a, b)
		"in", "not in":
			var found := false
			if b is Array:
				for item in b:
					if _equals(item, a):
						found = true
						break
			elif b is String:
				if not a is String:
					_fail("TypeError", "'in <string>' requires string as left operand, not %s" % _type_name(a), line)
					return false
				found = a in b
			else:
				_fail("TypeError", "argument of type '%s' is not iterable" % _type_name(b), line)
				return false
			return found if op == "in" else not found
	if typeof(a) == TYPE_BOOL:
		a = int(a)
	if typeof(b) == TYPE_BOOL:
		b = int(b)
	var both_num: bool = (a is int or a is float) and (b is int or b is float)
	if not both_num and not (a is String and b is String):
		_fail("TypeError", "'%s' not supported between instances of '%s' and '%s'" % [op, _type_name(a), _type_name(b)], line)
		return false
	match op:
		"<":
			return a < b
		">":
			return a > b
		"<=":
			return a <= b
		">=":
			return a >= b
	return false


func _equals(a, b) -> bool:
	if typeof(a) == TYPE_BOOL:
		a = int(a)
	if typeof(b) == TYPE_BOOL:
		b = int(b)
	if (a is int or a is float) and (b is int or b is float):
		return a == b
	if a is String and b is String:
		return a == b
	if a == null and b == null:
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _equals(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		return is_same(a, b)
	return false


func _truthy(v) -> bool:
	if v == null:
		return false
	if typeof(v) == TYPE_BOOL:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	if v is Array:
		return not v.is_empty()
	return true


func _type_name(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "NoneType"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "str"
		TYPE_ARRAY:
			return "list"
	return "function"


## How print() shows a value.
func _str(v) -> String:
	return v if v is String else _repr(v)


## How a value looks inside a list, e.g. ['a', 1, True].
func _repr(v) -> String:
	match typeof(v):
		TYPE_NIL:
			return "None"
		TYPE_BOOL:
			return "True" if v else "False"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			if is_inf(v):
				return "inf" if v > 0 else "-inf"
			if is_nan(v):
				return "nan"
			if v == floorf(v) and absf(v) < 1e16:
				return "%d.0" % int(v)
			return str(v)
		TYPE_STRING:
			var s: String = v.replace("\\", "\\\\").replace("\n", "\\n")
			if "'" in s and not "\"" in s:
				return "\"%s\"" % s
			return "'%s'" % s.replace("'", "\\'")
		TYPE_ARRAY:
			var parts := PackedStringArray()
			for item in v:
				parts.append(_repr(item))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			if v.has("__builtin__"):
				return "<built-in function %s>" % v["__builtin__"]
			return "<function %s>" % v.get("name", "?")
	return str(v)
