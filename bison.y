%{
#define TRUE 1
#define FALSE 0
#include <iostream>
#include <string>
#include <vector>
#include <sstream>

using namespace std;
extern int yylineno;
void yyerror (const char *error);
int yylex();
string dest_token;

bool good = TRUE;
unsigned int position = 0;

vector <string> commands;

struct number {
	string name;  // nazwa
	string value; // wartość
	unsigned int type; // 0 - zmienna niezainicjalizowana, 1 - zmienna zainicjalizowana, 2 - stała
	unsigned int position; // Pozycja liczby w pamięci
};

vector <number> numbers;

struct jump {
    unsigned int start;
    vector <unsigned int> ends;
    vector <unsigned int> ifends;
};

vector <jump> jumps;

struct reg {
	string value;
	unsigned int position;
	string name;
	bool uptodate;
	bool active;
};

vector <reg> regs(4);

string i2s(int);

void add_command(string);
void add_to_command(int, string);
unsigned int counter();
void add_const(string, string);
void add_var(string);
void assign_var(string, string);
void read_value(string);
void write_value(string);
void check_const();

// Obsługa rejestrów u pamięci
int get_reg_by_name(string);
int get_reg_by_pos(unsigned int);
unsigned int get_mem_by_name(string);

// Magia zaczyna się tutaj
void add(string, string);
void sub(string, string);
void mul(string, string);
void div(string, string);
void mod(string, string);
void assign(string);

// Warunki
void eq(string, string);
void ne(string, string);
void lt(string, string);
void ge(string, string);

// ify i while'e (większa magia)
void fif();
void fthen();
void felse();
void fifend();
void fwhile();
void fdo();
void fwhileend();

void mem_dump();

%}
%union {
	char* str;
}
%start program
%token CONST
%token VAR
%token START
%token END
%token ID
%token NUM

%token SEMICOLON
%token ASSIGN
%token ADD
%token SUB
%token MUL
%token DIV
%token MOD
%token READ
%token WRITE
%token IF
%token THEN
%token ELSE
%token WHILE
%token DO
%token EQ
%token GT
%token LT
%token LE
%token GE
%token NE
%token BLAD
%%

program
: CONST constDeclare VAR varDeclare START commands END { add_command("HALT"); }
;

constDeclare
: constDeclare ID EQ NUM  {	add_const($<str>2, $<str>4); }
|
;

varDeclare
: varDeclare ID 	{ add_var($<str>2); }
|
;

commands
: commands command
|
;

command
: ID { dest_token=$<str>1; } ASSIGN expression SEMICOLON { }
| IF { fif(); } condition THEN { fthen(); } commands ELSE { felse();} commands END { fifend(); }
| WHILE { fwhile(); } condition DO { fdo(); } commands END { fwhileend(); }
| READ ID SEMICOLON 				{ read_value($<str>2); }
| WRITE ID SEMICOLON				{ write_value($<str>2); }
;

expression
: ID ADD ID { check_const(); add($<str>1, $<str>3); }
| ID SUB ID { check_const(); sub($<str>1, $<str>3); }
| ID MUL ID { check_const(); mul($<str>1, $<str>3); }
| ID DIV ID { check_const(); div($<str>1, $<str>3); }
| ID MOD ID { check_const(); mod($<str>1, $<str>3); }
| ID { assign($<str>1); }
|
;

condition
: ID EQ ID { eq($<str>1, $<str>3); }
| ID NE ID { ne($<str>1, $<str>3); }
| ID LT ID { lt($<str>1, $<str>3); }
| ID LE ID { ge($<str>3, $<str>1); }
| ID GT ID { lt($<str>3, $<str>1); }
| ID GE ID { ge($<str>1, $<str>3); }
|
;

%%
void fwhile() {
    jump j;
    j.start = counter();
    jumps.push_back(j);
}

void fdo() {
}

void fwhileend() {
    add_command("JUMP " + i2s(jumps.back().start));
    for (int i=0; i<jumps.back().ends.size(); i++) {
        add_to_command(jumps.back().ends.at(i), i2s(counter()));
    }
    jumps.pop_back();
}

void fif() {
    jump j;
    jumps.push_back(j);
}
void fthen() {

}
void felse() {
    jumps.back().ifends.push_back(counter());
    add_command("JUMP ");
    for (int i=0; i<jumps.back().ends.size(); i++) {
        add_to_command(jumps.back().ends.at(i), i2s(counter()));
    }
}
void fifend() {
    for (int i=0; i<jumps.back().ifends.size(); i++) {
        add_to_command(jumps.back().ifends.at(i), i2s(counter()));
    }
        jumps.pop_back();
}
void eq(string left, string right) {
    add_command("LOAD 0 " + i2s(get_mem_by_name(left)));
    add_command("LOAD 1 " + i2s(get_mem_by_name(right)));
    add_command("SUB 2 2");
    add_command("ADD 2 0");
    add_command("SUB 2 1");
    jumps.back().ends.push_back(counter());
    add_command("JG 2 "); // spadamy stąd
    add_command("SUB 2 2");
    add_command("ADD 2 1");
    add_command("SUB 2 0");
    jumps.back().ends.push_back(counter());
    add_command("JG 2 "); // spadamy stąd również
}

void ne(string left, string right) {
    add_command("LOAD 0 " + i2s(get_mem_by_name(left)));
    add_command("LOAD 1 " + i2s(get_mem_by_name(right)));
    add_command("SUB 2 2");
    add_command("ADD 2 0");
    add_command("SUB 2 1");
    add_command("JG 2 " + i2s(counter()+5)); // a może w drugą stronę?
    add_command("SUB 2 2");
    add_command("ADD 2 1");
    add_command("SUB 2 0");
    jumps.back().ends.push_back(counter());
    add_command("JZ 2 "); // spadamy stąd, bo są równe
}

void ge(string left, string right) {
    add_command("LOAD 0 " + i2s(get_mem_by_name(left)));
    add_command("LOAD 1 " + i2s(get_mem_by_name(right)));
    add_command("SUB 1 0"); // w 1 right - left
    add_command("JZ 1 "+ i2s(counter()+2)); // spadamy stąd
    jumps.back().ends.push_back(counter());
    add_command("JUMP ");
}

void lt(string left, string right) {
    add_command("LOAD 0 " + i2s(get_mem_by_name(left)));
    add_command("LOAD 1 " + i2s(get_mem_by_name(right)));
    add_command("SUB 1 0");
    add_command("JG 1 " + i2s(counter()+2));
    jumps.back().ends.push_back(counter());
    add_command("JUMP ");
}



string i2s(int i){
	ostringstream ss;
	ss << i;
	return ss.str();
}

void add_command(string command) {
	commands.push_back(command);
}

void set_command(int pos, string command) {
    commands.at(pos) = command;
}

void add_to_command(int pos, string command) {
    commands.at(pos) = commands.at(pos) + command;
}

unsigned int counter() {
    return commands.size();
}

void add_const(string name, string value) {
	for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==name) {
			good=false;
			cout << "Blad w linii " << yylineno << " - stala \"" << name << "\" zostala zadeklarowana ponownie." << endl;
			exit(-1);
		}
	}

	add_command("SET " + i2s(position) + " " + value);

	number constant;
	constant.name = name;
	constant.value = value;
	constant.position = position;
	position++;
	constant.type = 2;

	numbers.push_back(constant);
}

void add_var(string name) {
	for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==name) {
			good=false;
			cout << "Blad w linii " << yylineno << " - zmienna \"" << name << "\" zostala zadeklarowana ponownie." << endl;
			exit(-1);
		}
	}

	number variable;
	variable.name = name;
	variable.position = position;
	position++;
	variable.type = 1;
	numbers.push_back(variable);

}

void assign_var(string name, string name2) {
    for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==dest_token) {
			if(numbers.at(i).type==2) {
                cout << "Blad w linii " << yylineno << " - stała \"" << dest_token << "\" nie może zostać zmieniona." << endl;
                exit(-1);
			}
		}
	}
	add_command("LOAD " + i2s(get_mem_by_name(name)) + " " + i2s(get_mem_by_name(name2)));
}

void check_const() {
    for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==dest_token) {
			if(numbers.at(i).type==2) {
                cout << "Blad w linii " << yylineno << " - stała \"" << dest_token << "\" nie może zostać zmieniona." << endl;
                exit(-1);
			}
		}
	}

}

void assign(string name) {
    for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==dest_token) {
			if(numbers.at(i).type==2) {
                cout << "Blad w linii " << yylineno << " - stała \"" << dest_token << "\" nie może zostać zmieniona." << endl;
                exit(-1);
			}
		}
	}
    add_command("LOAD 0 " + i2s(get_mem_by_name(name)));
    add_command("STORE 0 " + i2s(get_mem_by_name(dest_token)));
}

void read_value(string name) {
	unsigned int mempos;
	for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==name) {
			if(numbers.at(i).type==2) {
				good=false;
				cout << "Blad w linii " << yylineno << " - czytanie stałej." << endl;
				exit(-1);
			} else {
				numbers.at(i).type = 1;
				mempos = numbers.at(i).position;
				add_command("READ " + i2s(mempos));
				i = numbers.size();
			}
		}
	}
}

void write_value(string name) {
	unsigned int mempos;
	for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==name) {
			if(numbers.at(i).type==0) {
				good=false;
				cout << "Blad w linii " << yylineno << " - zmienna \"" << name << "\" nie została zainicjalizowana." << endl;
				exit(-1);
			} else {
				mempos = numbers.at(i).position;
				add_command("WRITE " + i2s(mempos));
				i = numbers.size();
			}
		}
	}
}

void add(string element1, string element2) {
	add_command("LOAD 0 " + i2s(get_mem_by_name(element1)));
	add_command("LOAD 1 " + i2s(get_mem_by_name(element2)));
	add_command("ADD 0 1");
	add_command("STORE 0 " + i2s(get_mem_by_name(dest_token)));
}

void sub(string element1, string element2) {
	add_command("LOAD 0 " + i2s(get_mem_by_name(element1)));
	add_command("LOAD 1 " + i2s(get_mem_by_name(element2)));
	add_command("SUB 0 1");
	add_command("STORE 0 " + i2s(get_mem_by_name(dest_token)));
}

void mul(string element1, string element2) {
	string jump;
	string cz1 = i2s(get_mem_by_name(element1));
	string cz2 = i2s(get_mem_by_name(element2));

    add_command("LOAD 0 " + cz1);
    add_command("LOAD 1 " + cz2);

    // 1 czynnik niech będzie większy od 2
    /*add_command("SUB 0 1");
    add_command("JZ 0 " + i2s(counter()+5));
    add_command("LOAD 0 " + cz2);
    add_command("LOAD 1 " + cz1);
    add_command("SUB 2 2");
    add_command("JZ 2 " + i2s(counter()+3));
    add_command("LOAD 0 " + cz1);*/


    add_command("SUB 2 2");
    add_command("LOAD 3 " + i2s(get_mem_by_name("JED")));
	jump = i2s(counter());

    add_command("JODD 1 " + i2s(counter()+4)); // skok do dodanieraz
    add_command("HALF 1"); // 4
    add_command("ADD 0 0");
    add_command("JG 3 " + i2s(counter()+3));
    // dodanieraz
    add_command("ADD 2 0");;
    add_command("SUB 1 3"); // odjęcie 1

    add_command("JG 1 " + jump); // koniec - skok do 4

	add_command("STORE 2 " + i2s(get_mem_by_name(dest_token)));
}

void div2(string element1, string element2) {
    string jump;
	string dzielna = i2s(get_mem_by_name(element1));
	string dzielnik = i2s(get_mem_by_name(element2));

	add_command("STORE 0 0");
	add_command("STORE 1 1");
	add_command("STORE 2 2");
	add_command("STORE 3 3");

    add_command("LOAD 0 " + dzielna);
    add_command("SUB 2 2");
    add_command("LOAD 3 " + dzielnik);

    /*
    r0 - aktualny dzielnik
    r1 - rejestr pomocniczy
    r2 - potęga dwójki
    r3 - potęga dwójki * dzielna
    */

    // Sprawdzenie czy się mieści
    add_command("SUB 3 0");
    add_command("JG 3 " + i2s(counter()+27)); // nie mieści się - Koniec
    add_command("LOAD 2 " + i2s(get_mem_by_name("JED"))); // Mieści się - wstaw jedynkę w wynik
    add_command("LOAD 3 " + dzielnik);
    add_command("SUB 1 1");
    add_command("STORE 1 " + i2s(position));
    add_command("ADD 1 3");

    // No to dzielimy
    jump = i2s(counter());

    add_command("SUB 3 3");
    add_command("ADD 3 1");

    add_command("ADD 3 3");
    add_command("ADD 2 2");

    add_command("SUB 1 1");
    add_command("ADD 1 3");

    add_command("SUB 3 0");
    add_command("JZ 3 " + jump);
    add_command("ADD 3 1");
    add_command("HALF 2");
    // teraz w 3 jest największy dzielnik*potęga dwójki
    // Zapiszemy wynik do pamięci i odpalimy algorytm jeszcze raz
    // aż nie będzie r2=r0

    add_command("SUB 1 1");
    add_command("ADD 1 2");

    add_command("SUB 1 0");
    add_command("JZ 1 " + i2s(counter()+7)); // Uff, koniec

    // Dodajemy wynik dotychczasowy do wyniku w pamięci
    // i ustawiamy algorytm do początku
    add_command("SUB 0 2"); // Zmniejszenie dzielnej
    add_command("LOAD 1 " + i2s(position));
    add_command("ADD 1 2");
    add_command("STORE 1 " + i2s(position));
    add_command("LOAD 2 " + i2s(get_mem_by_name("JED")));
    add_command("JG 2 " + jump);

    add_command("LOAD 1 " + i2s(position));
    add_command("ADD 2 1");
    add_command("STORE 2 " + i2s(get_mem_by_name(dest_token)));
	add_command("LOAD 0 0");
	add_command("LOAD 1 1");
	add_command("LOAD 2 2");
	add_command("LOAD 3 3");
}

void div(string dzielna, string dzielnik) {
    string jump, jump2, jump3;
    string rdzielna = "0";
    string rdzielnik = "1";
    string rpotegi = "2";
    string rpom = "3";

    // A może dzielenie przez 0?

    add_command("LOAD 0 " + i2s(get_mem_by_name(dzielna)));
    add_command("LOAD 1 " + i2s(get_mem_by_name(dzielnik)));

    add_command("JG 1 " + i2s(counter()+3));
    add_command("SUB 3 3");
    add_command("JUMP " + i2s(counter()+23));

    add_command("LOAD 2 " + i2s(get_mem_by_name("JED")));

    add_command("SUB 3 3");
    add_command("STORE 3 " + i2s(position)); // Wrzucamy zero do wynku w pamieci

    jump = i2s(counter()); // Tu bedzie wykonywany skok glowny

    add_command("JZ 2 "  + i2s(counter() + 19)); // Warunek koncowy (potega=0)

    // Sprawdzamy czy dzielnik miesci sie w dzielnej
    jump2 = i2s(counter());

    add_command("SUB 3 3");
    add_command("ADD 3 1");

    add_command("SUB 3 0");
    add_command("JG 3 " + i2s(counter() + 4)); // nie mieści się BUBA

    // mieści się
    add_command("ADD 1 1"); // PODWAJAMY OBA
    add_command("ADD 2 2");

    add_command("JUMP " + jump2);

    // nie mieści się
    jump3 = i2s(counter());
    add_command("HALF 1"); // DZIELIMY OBA
    add_command("HALF 2");

    add_command("SUB 3 3");
    add_command("ADD 3 1");

    add_command("SUB 3 0");
    add_command("JG 3 " + jump3); // nie mieści się BUBA

    add_command("LOAD 3 " + i2s(position)); // ładujemy wynik
    add_command("ADD 3 2"); // powiększamy go
    add_command("STORE 3 " + i2s(position)); // zapisujemy spowrotem

    add_command("SUB 0 1"); // Odejmujemy od dzielnej dzielnik
    add_command("JUMP " + jump);

    // KONIEC
    add_command("STORE 3 " + i2s(get_mem_by_name(dest_token)));
}

void mod2(string dzielna, string dzielnik) {
    string jump, jump2, jump3;
    string rdzielna = "0";
    string rdzielnik = "1";
    string rpotegi = "2";
    string rpom = "3";

    add_command("STORE 0 0");
    add_command("STORE 1 1");
    add_command("STORE 2 2");
    add_command("STORE 3 3");

    // A może dzielenie przez 0?

    add_command("LOAD 0 " + i2s(get_mem_by_name(dzielna)));
    add_command("LOAD 1 " + i2s(get_mem_by_name(dzielnik)));

    add_command("JG 1 " + i2s(counter()+3));
    add_command("SUB 3 3");
    add_command("JUMP " + i2s(counter()+23));

    add_command("LOAD 2 " + i2s(get_mem_by_name("JED")));

    add_command("SUB 3 3");
    add_command("STORE 3 " + i2s(position)); // Wrzucamy zero do wynku w pamieci

    jump = i2s(counter()); // Tu bedzie wykonywany skok glowny

    add_command("JZ 2 "  + i2s(counter() + 21)); // Warunek koncowy (potega=0)

    // Sprawdzamy czy dzielnik miesci sie w dzielnej
    jump2 = i2s(counter());

    add_command("SUB 3 3");
    add_command("ADD 3 1");

    add_command("SUB 3 0");
    add_command("JG 3 " + i2s(counter() + 4)); // nie mieści się BUBA

    // mieści się
    add_command("ADD 1 1"); // PODWAJAMY OBA
    add_command("ADD 2 2");

    add_command("JUMP " + jump2);

    // nie mieści się
    jump3 = i2s(counter());
    add_command("HALF 1"); // DZIELIMY OBA
    add_command("HALF 2");

    add_command("SUB 3 3");
    add_command("ADD 3 1");

    add_command("SUB 3 0");
    add_command("JG 3 " + jump3); // nie mieści się BUBA

    add_command("LOAD 3 " + i2s(position)); // ładujemy wynik
    add_command("ADD 3 2"); // powiększamy go
    add_command("STORE 0 " + i2s(position)); // zapisujemy spowrotem
    add_command("SUB 3 3");
    add_command("ADD 3 0");
    add_command("SUB 0 1"); // Odejmujemy od dzielnej dzielnik
    add_command("JUMP " + jump);

    // KONIEC
    add_command("STORE 3 " + i2s(get_mem_by_name(dest_token)));
}

void mod(string dzielna, string dzielnik) {
    string jump, jump2, jump3;
    string rdzielna = "0";
    string rdzielnik = "1";
    string rpotegi = "2";
    string rpom = "3";

    // A może dzielenie przez 0?

    add_command("LOAD 0 " + i2s(get_mem_by_name(dzielna)));
    add_command("LOAD 1 " + i2s(get_mem_by_name(dzielnik)));

    add_command("JG 1 " + i2s(counter()+3));
    add_command("SUB 3 3");
    add_command("JUMP " + i2s(counter()+22));

    add_command("LOAD 2 " + i2s(get_mem_by_name("JED")));

    add_command("SUB 3 3");

    jump = i2s(counter()); // Tu bedzie wykonywany skok glowny

    add_command("JZ 2 "  + i2s(counter() + 18)); // Warunek koncowy (potega=0)

    // Sprawdzamy czy dzielnik miesci sie w dzielnej
    jump2 = i2s(counter());

    add_command("SUB 3 3");
    add_command("ADD 3 1");

    add_command("SUB 3 0");
    add_command("JG 3 " + i2s(counter() + 4)); // nie mieści się BUBA

    // mieści się
    add_command("ADD 1 1"); // PODWAJAMY OBA
    add_command("ADD 2 2");

    add_command("JUMP " + jump2);

    // nie mieści się
    jump3 = i2s(counter());
    add_command("HALF 1"); // DZIELIMY OBA
    add_command("HALF 2");

    add_command("SUB 3 3");
    add_command("ADD 3 1");

    add_command("SUB 3 0");
    add_command("JG 3 " + jump3); // nie mieści się BUBA

    add_command("SUB 3 3");
    add_command("ADD 3 0");
    add_command("SUB 0 1"); // Odejmujemy od dzielnej dzielnik
    add_command("JUMP " + jump);

    // KONIEC
    add_command("STORE 3 " + i2s(get_mem_by_name(dest_token)));
}

void mem_dump() {
	string type;
	cout << "Mem dump:" << endl;
	for(int i=0; i<numbers.size(); ++i) {
		if(numbers.at(i).type==2)
			type = "const ";
		else
			type = "var ";
		cout << type << numbers.at(i).name << " : " <<  numbers.at(i).value << ", pos: " << numbers.at(i).position << endl;
	}
}

void regs_init() {
	for(int i=0; i<regs.size(); i++) {
		regs.at(i).uptodate = 0;
		regs.at(i).active = 0;
		regs.at(i).position = position;
		position++;
		regs.at(i).value = "0";
	}
	add_const("JED", "1");
}

int get_reg_by_name(string name) {
	for(int i=0; i<regs.size(); i++) {
		if(regs.at(i).name==name)
			if(regs.at(i).uptodate==1)
				return i;
	}
	return -1;
}

int get_reg_by_pos(unsigned int position) {
	for(int i=0; i<regs.size(); i++) {
		if(regs.at(i).position==position)
			if(regs.at(i).uptodate==1)
				return i;
	}
	return -1;
}

unsigned int get_mem_by_name(string name) {
	for(int i=0; i<numbers.size(); i++) {
		if(numbers.at(i).name==name) {
			return numbers.at(i).position;
		}
	}

    good=false;
    cout << "Błąd w linii " << yylineno << " - zmienna \"" << name << "\" nie została zainicjalizowana." << endl;
    exit(-1);
}

int main(){
	regs_init();
	yyparse();
	if(good) {
		for(vector<string>::iterator i=commands.begin(); i!=commands.end(); ++i) {
			cout << *i << endl;
		}
		//mem_dump();
	} else {
		// Błąd składni
	}
}

void yyerror (const char *error) {
	good = FALSE;
	cout << "Error: " << error << " in " <<yylineno <<" line"<<endl;
}
