// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

#include <QApplication>
#include <QPushButton>

int main(int argc, char **argv)
{
	QApplication app (argc, argv);

	QPushButton button ("Hello World: Qt5");
	button.show();

	return app.exec();
}

// g++ qt5.cc $(pkg-config --cflags --libs Qt5Gui Qt5Core Qt5Widgets) -fPIC
