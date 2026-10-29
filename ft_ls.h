#ifndef FT_LS_H
# define FT_LS_H

# include <stdio.h>
# include <dirent.h>
# include <stdlib.h>
#include <string.h>

typedef struct s_file
{
    char *name;
    struct s_file *next;
} t_file;

typedef struct s_flags
{
    int l;
    int R;
    int a;
    int r;
    int t;
} t_flags;

int ft_ls(char *str);
t_file  *new_node(const char *name);
void    add_back(t_file **list, t_file *node);
void    insert_sorted(t_file **list, t_file *node);
void    print_list(t_file *list);
void    free_list(t_file **list);
int     compare_files(t_file *a, t_file *b);

#endif