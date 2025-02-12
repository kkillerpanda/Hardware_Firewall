#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include "hps_bridge_header.h"
#define enter (key =='\n' || key == '\r')

int window_init_function(hps_bridge_input *input)
{
    input->system_Reset = false;
    start_fpga_thread(input);

    pthread_mutex_lock(&file_creation_mutex);
    while (!file_created)
    {
        pthread_cond_wait(&file_creation_cond, &file_creation_mutex); // Wait for the signal
    }
    pthread_mutex_unlock(&file_creation_mutex);

    if (has_colors() == TRUE)
    {
        start_color();
        init_pair(1, COLOR_RED, COLOR_BLACK);
        attron(A_BOLD);
        attron(COLOR_PAIR(1));
    }
    

    keypad(stdscr, TRUE);
    noecho();
    raw();
    curs_set(0);

    return 0;
}

void arrow_mover(int key, int *y)
{
    if (key == KEY_UP)
    {
        (*y)--;
        if ((*y) < 0)
            *y = 0;
    }
    else if (key == KEY_DOWN)
    {
        (*y)++;
        if (*y > 2)
            *y = 2;
    }
}

void menu_choices(char first_choice[], char second_choice[], char third_choice[], int starty, int startx, int y)
{
    clear();
    move(starty, startx);
    printw("%s", first_choice);
    move(starty + 1, startx);
    printw("%s", second_choice);
    move(starty + 2, startx);
    printw("%s", third_choice);
    move(starty + y, startx - 4);
    printw("==>");
    refresh();
}

void Summary_function(int key, int y, int starty, int startx, FILE *file_ptr)
{
    int threat_count = 0;
    char ip_string[20], mac_string[20], port_string[6], phy_string[2];
    char threats[7][20];
    while (key != 'q')
    {
        rewind(file_ptr);
        menu_choices("IP stats", "threat detected", "exit", starty, startx, y);
        key = getch();
        arrow_mover(key, &y);
        if (enter)
        {
            switch (y)
            {
                case 0:
                    pthread_mutex_lock(&file_mutex);
                    fscanf(file_ptr, "IP Address: %s\n", ip_string);
                    fscanf(file_ptr, "MAC Address: %s\n", mac_string);
                    fscanf(file_ptr, "Port Number: %s\n", port_string);
                    fscanf(file_ptr, "PHY Number: %s\n", phy_string);
                    pthread_mutex_unlock(&file_mutex);

                    clear();
                    mvprintw(starty, startx, "The IP that attacked is: %s", ip_string);
                    mvprintw(starty + 1, startx, "The MAC Address is: %s", mac_string);
                    mvprintw(starty + 2, startx, "The Port is: %s", port_string);
                    mvprintw(starty + 3, startx, "The PHY is: %s", phy_string);
                    refresh();
                    getch();
                    break;
                case 1:
                    threat_count = 0;
                    pthread_mutex_lock(&file_mutex);
                    // Find the line "Threats Detected:"
                    fseek(file_ptr, 96, SEEK_SET);
                    while (fscanf(file_ptr, "  %[^\n]\n", threats[threat_count]) == 1)
                    {
                        threat_count++;
                        if (threat_count > 3)
                        {
                            break; // Limit to 4 threats
                        }
                    }
                    pthread_mutex_unlock(&file_mutex);

                    // Display threats
                    clear();
                    mvprintw(starty, startx, "Threats Detected:");
                    for (int i = 0; i < threat_count; i++)
                    {
                        mvprintw(starty + i + 1, startx, "  %s", threats[i]);
                    }
                    refresh();
                    getch();
                    break;
                case 2:
                    key = 'q';
                    break;
            }
        }
    }
    key = 0;
}

void restart_function(hps_bridge_input *input, int starty, int startx)
{
    input->system_Reset = true;
    clear();
    mvprintw(starty, startx, "You have 10 seconds to confirm your identity");
    refresh();

    pthread_mutex_lock(&auth_process_mutex);
    while (authentication_processing)
    {
        clear();
        mvprintw(starty, startx, "Give it a sec while system is restarting");
        refresh();
        pthread_cond_wait(&auth_process_cond, &auth_process_mutex); // Wait for the signal
    }
    authentication_processing = true;
    pthread_mutex_unlock(&auth_process_mutex);

    pthread_mutex_lock(&auth_mutex);
    while (!authentication_done)
    {
        pthread_cond_wait(&auth_cond, &auth_mutex); // Wait for the signal
    }
    authentication_done = false;
    pthread_mutex_unlock(&auth_mutex);
}


