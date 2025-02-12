# Compiler
CC = gcc

# Compiler Flags
CFLAGS = -Wall -Wextra -std=c99

# Include Directory
INCLUDE_DIR = .

# Libraries
LIBS = -lncurses -lpthread

# Target Executable
TARGET = user_gui

# Source Files
SRCS = user_gui.c

# Object Files
OBJS = $(SRCS:.c=.o)

# Default Target
all: $(TARGET)

# Linking
$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LIBS)

# Compilation
%.o: %.c
	$(CC) $(CFLAGS) -I$(INCLUDE_DIR) -c $< -o $@

# Clean
clean:
	rm -f $(OBJS) $(TARGET)
