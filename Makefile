kompilator: bison.y flex.l
	bison -d -t bison.y
	flex flex.l
	g++ -o kompilator lex.yy.c bison.tab.c
