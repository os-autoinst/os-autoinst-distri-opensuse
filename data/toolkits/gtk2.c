// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

#include <gtk/gtk.h>

static void destroy(GtkWidget *widget, gpointer data)
{
	gtk_main_quit();
}

int main(int argc, char *argv[])
{
    GtkWidget *window, *label;

    gtk_init(&argc, &argv);

    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);

    /* Here we connect the "destroy" event to a signal handler.
     * This event occurs when we call gtk_widget_destroy() on the window */
    g_signal_connect(window, "destroy", G_CALLBACK(destroy), NULL);

    gtk_container_set_border_width(GTK_CONTAINER(window), 10);

    label = gtk_label_new("Hello World: GTK2");

    gtk_container_add(GTK_CONTAINER(window), label);

    gtk_widget_show(label);
    gtk_widget_show(window);

    gtk_main();

    return 0;
}


// gcc gtk2.c $(pkg-config --cflags --libs gtk+-2.0)
