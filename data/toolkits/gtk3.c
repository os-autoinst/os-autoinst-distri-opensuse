// Copyright SUSE LLC
// SPDX-License-Identifier: FSFAP

#include <gtk/gtk.h>

static void activate(GtkApplication *app, gpointer user_data)
{
	GtkWidget *window, *label , *button_box;

	window = gtk_application_window_new(app);
	gtk_window_set_title(GTK_WINDOW(window), "Window");
	gtk_window_set_default_size(GTK_WINDOW(window), 200, 200);

	button_box = gtk_button_box_new(GTK_ORIENTATION_HORIZONTAL);
	gtk_container_add(GTK_CONTAINER(window), button_box);

	label = gtk_label_new("Hello World: GTK3");
	gtk_container_add(GTK_CONTAINER(button_box), label);

	gtk_widget_show_all(window);
}

int main(int argc, char **argv)
{
  GtkApplication *app;
  int status;

  app = gtk_application_new("org.gtk.example", G_APPLICATION_FLAGS_NONE);
  g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
  status = g_application_run(G_APPLICATION(app), argc, argv);
  g_object_unref(app);

  return status;
}


// gcc gtk3.c $(pkg-config --cflags --libs gtk+-3.0)
