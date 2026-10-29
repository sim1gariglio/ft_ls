#include "ft_ls.h"

int ft_ls(char *path){
    DIR *current_dir = NULL;
    if (!(current_dir=opendir(path))){
        perror(path);
        return 1;
    }
    struct dirent *dir =readdir(current_dir);
    t_file *files= NULL;
    while(dir!=NULL){
        t_file *node = new_node(dir->d_name);
        if(!node){
            free_list(&files);
            closedir(current_dir);
            return 1;
        }
        insert_sorted(&files, node);
        dir =readdir(current_dir);
    }
    print_list(files);
    free_list(&files);
    closedir(current_dir);
    return 0;
}