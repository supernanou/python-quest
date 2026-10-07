extends RefCounted
## Helpers for checking answers and colouring Python code.
## Used by the exercise window and the quiz.

const KEYWORDS := ["def", "return", "if", "elif", "else", "for", "in", "while", "and", "or", "not", "True", "False", "None"]
const BUILTINS := ["print", "range", "len", "input", "int", "str", "append", "upper", "lower"]

static var _token_re: RegEx
static var _spaces_re: RegEx


## "output" answers ignore extra spaces (and capitals, unless case_sensitive).
## "code" answers ignore all spaces and treat ' and " the same.
static func normalize(text: String, mode: String, case_sensitive := false) -> String:
	var s := text.strip_edges()
	if mode == "code":
		return s.replace(" ", "").replace("\t", "").replace("'", "\"")
	if _spaces_re == null:
		_spaces_re = RegEx.create_from_string("\\s+")
	s = _spaces_re.sub(s, " ", true)
	return s if case_sensitive else s.to_lower()


static func matches(text: String, answers: Array, mode: String, case_sensitive := false) -> bool:
	var given := normalize(text, mode, case_sensitive)
	for accepted in answers:
		if given == normalize(accepted, mode, case_sensitive):
			return true
	return false


static func matches_ignoring_case(text: String, answers: Array, mode: String) -> bool:
	var given := normalize(text, mode).to_lower()
	for accepted in answers:
		if given == normalize(accepted, mode).to_lower():
			return true
	return false


## Colours Python code like a real code editor (BBCode for RichTextLabel).
static func highlight(code: String) -> String:
	if _token_re == null:
		_token_re = RegEx.create_from_string("(\"[^\"]*\"|'[^']*')|(#.*)|\\b(\\d+)\\b|\\b([A-Za-z_]+)\\b")
	var out := ""
	var last := 0
	for m in _token_re.search_all(code):
		out += escape(code.substr(last, m.get_start() - last))
		var token := m.get_string()
		var color := ""
		if m.get_string(1) != "":
			color = "#fbbf24"
		elif m.get_string(2) != "":
			color = "#64748b"
		elif m.get_string(3) != "":
			color = "#f472b6"
		elif token in KEYWORDS:
			color = "#c084fc"
		elif token in BUILTINS:
			color = "#38bdf8"
		if color == "":
			out += escape(token)
		else:
			out += "[color=%s]%s[/color]" % [color, escape(token)]
		last = m.get_end()
	out += escape(code.substr(last))
	return out


static func escape(text: String) -> String:
	var out := ""
	for ch in text:
		if ch == "[":
			out += "[lb]"
		elif ch == "]":
			out += "[rb]"
		else:
			out += ch
	return out
