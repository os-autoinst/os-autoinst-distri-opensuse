// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

#include <Xm/XmAll.h>

void main(int argc, char *argv[])
{
    Widget toplevel, main_w, button;
    XtAppContext app;

    XtSetLanguageProc(NULL, NULL, NULL);

    toplevel = XtVaAppInitialize(&app, "main", NULL, 0, &argc, argv, NULL, NULL);
    main_w = XtVaCreateManagedWidget("main_w", xmMainWindowWidgetClass, toplevel, XmNscrollingPolicy, XmAUTOMATIC, NULL);
    button = XtVaCreateWidget("Hello World: motif", xmLabelWidgetClass, main_w, NULL);

    XtManageChild(button);
    XtRealizeWidget(toplevel);
    XtAppMainLoop(app);
}

// gcc -lXm -lXt
// source http://www2.latech.edu/~acm/helloworld/motif.html jlk@engr.latech.edu (Josh Kleinpeter)
