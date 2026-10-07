extends RefCounted
## Code Lab challenges: kids write a whole program, run it, and the game checks it.
## Challenge N unlocks when level N of the course is finished.
##
##   "tests"     - the program is run with these "inputs" (answers to input())
##                 and what it prints must match "output"
##   "must_use"  - bits of code the program has to contain (so print(364) doesn't count as maths!)
##   "check"     - for open-ended tasks: {"var": name, "template": "I love {value}"} means the
##                 output must match the template using whatever the child put in that variable.
##                 {"var": name, "list_lines": 3} means: a list of 3 things, printed one per line.

const REWARD := 2

const CHALLENGES := [
	{
		"id": "hello",
		"title": "Say hello",
		"task": "Write a program that prints these two lines:\nHello!\nI am learning to code",
		"starter": "# Write your code below, then press Run\n",
		"tests": [{"inputs": [], "output": "Hello!\nI am learning to code"}],
		"must_use": ["print"],
		"hint": "Use two print() lines - one for each line of text.",
		"el": {
			"title": "Πες γεια",
			"task": "Γράψε ένα πρόγραμμα που εμφανίζει αυτές τις δύο γραμμές:\nHello!\nI am learning to code",
			"hint": "Χρησιμοποίησε δύο print() - ένα για κάθε γραμμή.",
			"starter": "# Γράψε τον κώδικά σου εδώ και πάτα Εκτέλεση\n",
		},
	},
	{
		"id": "pet",
		"title": "My pet",
		"task": "Make a variable called pet that holds a pet's name (real or made up!). Then print I love and the name - for example: I love Rex",
		"starter": "pet = \n",
		"check": {"var": "pet", "template": "I love {value}"},
		"must_use": ["pet"],
		"hint": "pet = \"Rex\"  then  print(\"I love\", pet)",
		"el": {
			"title": "Το κατοικίδιό μου",
			"task": "Φτιάξε μια μεταβλητή με όνομα pet που κρατάει το όνομα ενός κατοικίδιου (αληθινού ή φανταστικού!). Μετά εμφάνισε I love και το όνομα - για παράδειγμα: I love Rex",
			"hint": "pet = \"Rex\"  και μετά  print(\"I love\", pet)",
		},
	},
	{
		"id": "weeks",
		"title": "Days in a year",
		"task": "There are 7 days in a week. Make the computer work out how many days are in 52 weeks, and print the answer.",
		"starter": "",
		"tests": [{"inputs": [], "output": "364"}],
		"must_use": ["*"],
		"hint": "Use * to multiply 7 and 52 inside print().",
		"el": {
			"title": "Μέρες του χρόνου",
			"task": "Μια εβδομάδα έχει 7 μέρες. Βάλε τον υπολογιστή να υπολογίσει πόσες μέρες έχουν οι 52 εβδομάδες και εμφάνισε την απάντηση.",
			"hint": "Χρησιμοποίησε το * για να πολλαπλασιάσεις 7 και 52 μέσα στο print().",
		},
	},
	{
		"id": "shout",
		"title": "Shout my name",
		"task": "Make a variable called name with your name in it. Then print it in CAPITAL letters using .upper()",
		"starter": "name = \n",
		"check": {"var": "name", "template": "{upper}"},
		"must_use": [".upper()"],
		"hint": "print(name.upper())",
		"el": {
			"title": "Φώναξε το όνομά μου",
			"task": "Φτιάξε μια μεταβλητή με όνομα name με το όνομά σου. Μετά εμφάνισέ το με ΚΕΦΑΛΑΙΑ χρησιμοποιώντας .upper()",
			"hint": "print(name.upper())",
		},
	},
	{
		"id": "old_enough",
		"title": "Old enough?",
		"task": "Make a variable age = 10. Then print whether age is bigger than 8. The computer should print True.",
		"starter": "age = 10\n",
		"tests": [{"inputs": [], "output": "True"}],
		"must_use": [">"],
		"hint": "print(age > 8)",
		"el": {
			"title": "Είσαι αρκετά μεγάλος;",
			"task": "Φτιάξε μια μεταβλητή age = 10. Μετά εμφάνισε αν το age είναι μεγαλύτερο από 8. Ο υπολογιστής πρέπει να εμφανίσει True.",
			"hint": "print(age > 8)",
		},
	},
	{
		"id": "password",
		"title": "Secret door",
		"task": "Ask for a password with input(). If it is dragon, print Welcome! - otherwise print Go away!",
		"starter": "password = input(\"Password? \")\n",
		"tests": [{"inputs": ["dragon"], "output": "Welcome!"}, {"inputs": ["banana"], "output": "Go away!"}],
		"must_use": ["input", "if", "else"],
		"hint": "if password == \"dragon\":  (then an indented print)  else:  (another indented print)",
		"el": {
			"title": "Μυστική πόρτα",
			"task": "Ζήτα έναν κωδικό με input(). Αν είναι dragon, εμφάνισε Welcome! - αλλιώς εμφάνισε Go away!",
			"hint": "if password == \"dragon\":  (μετά ένα print με εσοχή)  else:  (κι άλλο ένα print με εσοχή)",
		},
	},
	{
		"id": "count",
		"title": "Count to 10",
		"task": "Use a for loop to print the numbers 1 to 10, one on each line.",
		"starter": "",
		"tests": [{"inputs": [], "output": "1\n2\n3\n4\n5\n6\n7\n8\n9\n10"}],
		"must_use": ["for"],
		"hint": "for i in range(1, 11):   - remember range stops BEFORE the last number.",
		"el": {
			"title": "Μέτρα ως το 10",
			"task": "Χρησιμοποίησε μια επανάληψη for για να εμφανίσεις τους αριθμούς 1 έως 10, έναν σε κάθε γραμμή.",
			"hint": "for i in range(1, 11):   - θυμήσου ότι το range σταματά ΠΡΙΝ από τον τελευταίο αριθμό.",
		},
	},
	{
		"id": "rocket",
		"title": "Rocket launch",
		"task": "Use a while loop to count down 5, 4, 3, 2, 1 (one per line), then print Blast off!",
		"starter": "n = 5\n",
		"tests": [{"inputs": [], "output": "5\n4\n3\n2\n1\nBlast off!"}],
		"must_use": ["while"],
		"hint": "while n > 0:  print(n)  then  n = n - 1.  Put print(\"Blast off!\") after the loop (not indented).",
		"el": {
			"title": "Εκτόξευση πυραύλου",
			"task": "Χρησιμοποίησε μια επανάληψη while για αντίστροφη μέτρηση 5, 4, 3, 2, 1 (ένα σε κάθε γραμμή), και μετά εμφάνισε Blast off!",
			"hint": "while n > 0:  print(n)  και μετά  n = n - 1.  Βάλε το print(\"Blast off!\") μετά την επανάληψη (χωρίς εσοχή).",
		},
	},
	{
		"id": "fruits",
		"title": "Fruit bowl",
		"task": "Make a list called fruits with 3 fruits in it. Then use a for loop to print each fruit on its own line.",
		"starter": "fruits = []\n",
		"check": {"var": "fruits", "list_lines": 3},
		"must_use": ["for"],
		"hint": "fruits = [\"apple\", \"kiwi\", \"plum\"]   then   for fruit in fruits:   print(fruit)",
		"el": {
			"title": "Φρουτιέρα",
			"task": "Φτιάξε μια λίστα με όνομα fruits με 3 φρούτα. Μετά χρησιμοποίησε μια επανάληψη for για να εμφανίσεις κάθε φρούτο σε δική του γραμμή.",
			"hint": "fruits = [\"apple\", \"kiwi\", \"plum\"]   και μετά   for fruit in fruits:   print(fruit)",
		},
	},
	{
		"id": "double",
		"title": "Double trouble",
		"task": "Write a function called double that takes a number and returns it times 2. Then print(double(21)).",
		"starter": "def double(n):\n    \n",
		"tests": [{"inputs": [], "output": "42"}],
		"must_use": ["def double", "return"],
		"hint": "Inside the function:  return n * 2",
		"el": {
			"title": "Διπλή φασαρία",
			"task": "Γράψε μια συνάρτηση με όνομα double που παίρνει έναν αριθμό και επιστρέφει το διπλάσιό του. Μετά γράψε print(double(21)).",
			"hint": "Μέσα στη συνάρτηση:  return n * 2",
		},
	},
]
