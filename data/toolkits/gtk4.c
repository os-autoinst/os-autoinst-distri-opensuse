// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

#include <gtk/gtk.h>

static void activate(GtkApplication *app, gpointer user_data) {
    GtkWidget *window;
    GtkWidget *label;

    // Create a new window
    window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Hello, World!");

    // Create a label
    label = gtk_label_new("Hello, World!");

    // Add the label to the window
    gtk_window_set_child(GTK_WINDOW(window), label);

    // Show the window
    gtk_widget_set_visible(GTK_WIDGET(window), TRUE);
}

int main(int argc, char *argv[]) {
    GtkApplication *app;
    int status;

    // Create a new application
    app = gtk_application_new("org.example.hello", 0);

    // Connect the "activate" signal to the callback function
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);

    // Run the application
    status = g_application_run(G_APPLICATION(app), argc, argv);

    // Clean up resources
    g_object_unref(app);

    return status;
}

// gcc gtk4.c $(pkg-config --cflags --libs gtk4)
