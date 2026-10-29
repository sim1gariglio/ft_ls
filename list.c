#include "ft_ls.h"

t_file  *new_node(const char *name){
    t_file *new = malloc(sizeof(t_file));
    if(!new){
        return (NULL);
    }
    new->next= NULL;
    new->name = strdup(name);
    if(!new->name)
    {
        free(new);
        return NULL;
    }
    return new;
}

void    add_back(t_file **list, t_file *node){
    if (!*list){
        *list = node;
    }
    else{
        t_file *tmp = *list;
        while(tmp->next != NULL)
        {
            tmp = tmp->next;
        }
        tmp->next = node;
    }
}

void    print_list(t_file *list){
    t_file *tmp = list;
    while(tmp != NULL)
    {
        printf("%s\n",tmp->name);
        tmp = tmp->next;
    }
}

void    free_list(t_file **list){
    t_file *tmp = *list;
    while(tmp != NULL)
    {
        t_file *tmp2=tmp->next;
        free(tmp->name);
        free(tmp);
        tmp = tmp2;
    }
    *list =NULL;
}

int     compare_files(t_file *a, t_file *b){
    return (strcmp(a->name, b->name));
}


void    insert_sorted(t_file **list, t_file *node){
    if (*list == NULL){ //lista vuota
        add_back(list, node);
        return;
    }
    t_file *tmp = *list;
    if (compare_files(node, tmp) <= 0) //elemento in testa
    {
        node->next = tmp;
        *list = node;
        return;
    }
    while(tmp->next != NULL)
    {
        if (compare_files(node,tmp->next) <= 0)
        {
            node -> next = tmp-> next;
            tmp->next = node;
            return;
        }else{
            tmp = tmp->next;
        }
    }
    tmp->next = node;
}
