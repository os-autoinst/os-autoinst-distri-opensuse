// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

#include <QtGui>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QLabel *label = new QLabel("Hello World: Qt4");
    label->show();
    return app.exec();
}

// g++ qt4.cc $(pkg-config --cflags --libs QtGui) $(pkg-config --cflags --libs QtCore)
