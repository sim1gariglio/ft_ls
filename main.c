#include "ft_ls.h"

int main(int ac, char* av[])
{
    char *path = av[1];
    if (ac==1)
        path = ".";
    if(ft_ls(path))
        return 1;
    return 0;
}