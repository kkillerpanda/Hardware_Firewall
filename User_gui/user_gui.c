#include "user_gui.h"
int main()
{
    int key=0, y=0;
    initscr();
    int height = 3;
    int width = 10;
    int starty = (LINES - height) / 2; /* Calculating for a center placement */
    int startx = (COLS - width) / 2;
    
    FILE *file_ptr;
    
    hps_bridge_input *input = malloc(sizeof(hps_bridge_input)); // Allocate memory
    if (input == NULL) {
        perror("Error allocating memory for input");
        return 1;
    }
    int exit_error = window_init_function(input);
    
    file_ptr = fopen("output.txt", "r");
    if (file_ptr == NULL) {
        perror("Error opening file!");
        free(input);
        return 1;
    }
    
    if(exit_error)
    {
        free(input);
        return exit_error;
    }

    while (key != 'q' )
    {
        menu_choices("Summary", "restart", "exit", starty, startx, y);
        key = getch();
        arrow_mover(key, &y);
        if (enter)
        {
            switch (y)
            {
                case 0:
                    Summary_function(key, y, starty, startx, file_ptr);
                    break;
                case 1:
                    restart_function(input, starty, startx);
                    break;
                case 2:
                    clear();
                    mvprintw(starty,startx,"goodbye");
                    refresh();
                    sleep(1);
                    key = 'q';
                    break;
            }
        }
    }
    fclose(file_ptr);
    stop_fpga_thread();
    free(input); // Free the memory allocated for 'input'
    
    endwin();
    curs_set(1);  

    return 0;
}
