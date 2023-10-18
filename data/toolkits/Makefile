.PHONY: clean

objects = fltk gtk2 gtk3 gtk4 motif qt4 qt5 qt6 swing.class

all: $(objects)

fltk: fltk.cc
	g++ -o $@ $< -lfltk

gtk2: gtk2.c
	gcc -o $@ $< `pkg-config --cflags --libs gtk+-2.0`

gtk3: gtk3.c
	gcc -o $@ $< `pkg-config --cflags --libs gtk+-3.0`

gtk4: gtk4.c
	gcc -o $@ $< `pkg-config --cflags --libs gtk4`

motif: motif.c
	gcc -o $@ $< -lXm -lXt

qt4: qt4.cc
	g++ -o $@ $< `pkg-config --cflags --libs QtCore QtGui`

qt5: qt5.cc
	g++ -o $@ $< `pkg-config --cflags --libs Qt5Core Qt5Gui Qt5Widgets` -fPIC

qt6: qt6.cc
	g++ -o $@ $< `pkg-config --cflags --libs Qt6Core Qt6Gui Qt6Widgets` -fPIC

swing.class: swing.java
	javac $<

clean:
	rm -f $(objects)
