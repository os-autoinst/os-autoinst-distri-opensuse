// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

#include <QApplication>
#include <QPushButton>

int main(int argc, char **argv)
{
    QApplication app(argc, argv);

    QPushButton button("Hello World: Qt6");
    button.show();

    return app.exec();
}

// g++ qt6.cc $(pkg-config --cflags --libs Qt6Gui Qt6Core Qt6Widgets) -fPIC
