#!/usr/bin/env bash
#
# Tester a passi per ft_ls: controlla solo quello che devi saper fare
# al passo della roadmap in cui ti trovi.
#
# Uso:
#   ./test_step.sh 2            testa il passo 2
#   ./test_step.sh 2 ./ft_ls    con un eseguibile diverso
#   VALGRIND=1 ./test_step.sh 2 controlla anche i memory leak
#
# Passi:
#   1-2  stampa tutti i file di una cartella (ordine di readdir, come ls -f)
#   3    stessi file, ma in ordine alfabetico (come ls -a)
#   4    parsing delle opzioni: senza -a i file nascosti spariscono,
#        opzioni sconosciute danno errore
#   5    -a e -r (anche combinate)
#   6    -t (e -t con -r e -a)
#   7    -l (e combinazioni)
#   8    -R (e combinazioni)
#   9    tutto: usa test.sh

export LC_ALL=C
set -f

STEP="$1"
if [ -z "$STEP" ]; then
    echo "Uso: ./test_step.sh <passo> [eseguibile]   (passo da 1 a 8)"
    exit 1
fi
[ "$STEP" = "1" ] && STEP=2
if [ "$STEP" -ge 9 ] 2>/dev/null; then
    echo "Per il passo 9 usa ./test.sh (il tester completo)."
    exit 0
fi

FT_LS="$(realpath "${2:-./ft_ls}" 2>/dev/null)"
if [ ! -x "$FT_LS" ]; then
    echo "Eseguibile non trovato: ${2:-./ft_ls} (hai compilato?)"
    exit 1
fi
if [ "$VALGRIND" = "1" ] && ! command -v valgrind >/dev/null; then
    echo "valgrind non installato: sudo apt install valgrind"
    exit 1
fi

GREEN="\033[32m"; RED="\033[31m"; RESET="\033[0m"

ROOT="$(mktemp -d /tmp/ft_ls_step.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT

# ---------------------------------------------------------------------------
# Cartella di prova
# ---------------------------------------------------------------------------
b="$ROOT/base"
mkdir -p "$b/alpha/sub" "$b/zeta" "$b/.hidden_dir"
echo "contenuto" > "$b/file_b.txt"
echo "A maiuscola" > "$b/File_A.txt"
echo "x" > "$b/.hidden"
echo "x" > "$b/alpha/inner.txt"
echo "x" > "$b/alpha/sub/deep.txt"
echo "spazio" > "$b/con spazio.txt"
echo "uguale" > "$b/same1"
echo "uguale" > "$b/same2"
echo "vecchio" > "$b/old.txt"
ln -s file_b.txt "$b/link_to_file"
touch -d "2026-03-01 10:00:00" "$b/file_b.txt"
touch -d "2026-02-01 09:30:00" "$b/File_A.txt"
touch -d "2026-01-15 08:00:00" "$b/same1" "$b/same2"
touch -d "2026-01-05 12:00:00" "$b/con spazio.txt"
touch -d "2024-05-01 18:00:00" "$b/old.txt"
touch -d "2026-02-20 07:00:00" "$b/alpha/inner.txt"
touch -d "2026-02-10 07:00:00" "$b/alpha/sub/deep.txt"
touch -h -d "2026-01-20 11:00:00" "$b/link_to_file"
touch -d "2026-01-25 11:00:00" "$b/.hidden"
touch -d "2026-02-25 10:00:00" "$b/alpha/sub" "$b/alpha"
touch -d "2026-01-30 10:00:00" "$b/zeta" "$b/.hidden_dir"
touch -d "2026-03-05 10:00:00" "$b"

pass=0; fail=0; n=0

# run_cmp "descrizione" "argomenti di ft_ls" "comando ls equivalente"
# Confronta stdout e codice di uscita con il vero ls.
run_cmp() {
    local label="$1" args="$2" ref="$3"
    n=$((n + 1))
    (cd "$ROOT" && eval "$ref" > "$ROOT/exp" 2>/dev/null; echo $? > "$ROOT/exp.code")
    (cd "$ROOT" && "$FT_LS" $args > "$ROOT/got" 2>/dev/null; echo $? > "$ROOT/got.code")
    if cmp -s "$ROOT/exp" "$ROOT/got" && cmp -s "$ROOT/exp.code" "$ROOT/got.code"; then
        pass=$((pass + 1)); printf "${GREEN}[OK]${RESET} %s\n" "$label"
    else
        fail=$((fail + 1)); printf "${RED}[KO]${RESET} %s\n" "$label"
        echo "     comando: ./ft_ls $args   (atteso come: $ref)"
        if ! cmp -s "$ROOT/exp" "$ROOT/got"; then
            echo "     output diverso (- atteso, + il tuo):"
            diff "$ROOT/exp" "$ROOT/got" | head -n 12 | sed 's/^/       /'
        fi
        cmp -s "$ROOT/exp.code" "$ROOT/got.code" || \
            echo "     codice di uscita: atteso $(cat "$ROOT/exp.code"), il tuo $(cat "$ROOT/got.code")"
    fi
    check_valgrind "$args"
}

# run_error "descrizione" "argomenti"
# Atteso: niente su stdout, un messaggio su stderr, codice di uscita diverso da 0.
run_error() {
    local label="$1" args="$2"
    n=$((n + 1))
    (cd "$ROOT" && "$FT_LS" $args > "$ROOT/got" 2> "$ROOT/got.err"; echo $? > "$ROOT/got.code")
    local code; code=$(cat "$ROOT/got.code")
    local problems=""
    [ -s "$ROOT/got" ] && problems="$problems stampa qualcosa su stdout;"
    [ -s "$ROOT/got.err" ] || problems="$problems nessun messaggio su stderr;"
    [ "$code" = "0" ] && problems="$problems codice di uscita 0 (deve essere diverso da 0);"
    [ "$code" -ge 128 ] 2>/dev/null && problems="$problems il programma e crashato (codice $code);"
    if [ -z "$problems" ]; then
        pass=$((pass + 1)); printf "${GREEN}[OK]${RESET} %s\n" "$label"
    else
        fail=$((fail + 1)); printf "${RED}[KO]${RESET} %s\n" "$label"
        echo "     comando: ./ft_ls $args"
        echo "     problemi:$problems"
    fi
    check_valgrind "$args"
}

check_valgrind() {
    [ "$VALGRIND" = "1" ] || return
    (cd "$ROOT" && valgrind --leak-check=full --errors-for-leak-kinds=definite,indirect,possible \
        --error-exitcode=242 --log-file="$ROOT/vg.log" "$FT_LS" $1 > /dev/null 2>&1)
    if [ $? -eq 242 ]; then
        printf "${RED}     valgrind: leak o errori di memoria${RESET}\n"
        grep -E "definitely lost|indirectly lost|possibly lost|Invalid|uninitialised" "$ROOT/vg.log" \
            | head -n 4 | sed 's/^/       /'
    fi
}

echo "=== Passo $STEP ==="

case "$STEP" in
2)
    echo "Atteso: tutti i file (anche nascosti, . e ..), nell'ordine di readdir, come 'ls -f'"
    run_cmp "cartella con file e sottocartelle"   "base"            "ls -f base"
    run_cmp "sottocartella"                       "base/alpha"      "ls -f base/alpha"
    run_cmp "cartella vuota (solo . e ..)"        "base/zeta"       "ls -f base/zeta"
    run_cmp "percorso con piu livelli"            "base/alpha/sub"  "ls -f base/alpha/sub"
    run_cmp "senza argomenti = cartella corrente" ""                "ls -f"
    run_error "cartella inesistente"              "inesistente"
    ;;
3)
    echo "Atteso: tutti i file (anche nascosti), in ordine alfabetico, come 'ls -a'"
    run_cmp "ordine alfabetico"                    "base"           "ls -a base"
    run_cmp "maiuscole prima delle minuscole"      "base"           "ls -a base"
    run_cmp "sottocartella"                        "base/alpha"     "ls -a base/alpha"
    run_cmp "cartella vuota"                       "base/zeta"      "ls -a base/zeta"
    run_cmp "senza argomenti"                      ""               "ls -a"
    run_error "cartella inesistente"               "inesistente"
    ;;
4)
    echo "Atteso: senza -a niente file nascosti; opzioni lette anche se non ancora usate"
    run_cmp "senza opzioni: niente file nascosti"  "base"           "ls base"
    run_cmp "senza argomenti"                      ""               "ls"
    run_cmp "cartella vuota"                       "base/zeta"      "ls base/zeta"
    run_error "opzione sconosciuta -z"             "-z base"
    run_error "opzione sconosciuta in mezzo -lzR"  "-lzR base"
    run_error "cartella inesistente"               "inesistente"
    ;;
5)
    echo "Atteso: -a e -r funzionano, anche insieme e in ordine diverso"
    run_cmp "-a"                                   "-a base"        "ls -a base"
    run_cmp "-r"                                   "-r base"        "ls -r base"
    run_cmp "-ar"                                  "-ar base"       "ls -ar base"
    run_cmp "-ra"                                  "-ra base"       "ls -ra base"
    run_cmp "-a -r separate"                       "-a -r base"     "ls -a -r base"
    run_cmp "-a senza cartella"                    "-a"             "ls -a"
    run_cmp "-r su cartella vuota"                 "-r base/zeta"   "ls -r base/zeta"
    ;;
6)
    echo "Atteso: -t ordina dal piu recente; a parita di data vince il nome"
    run_cmp "-t"                                   "-t base"        "ls -t base"
    run_cmp "-tr"                                  "-tr base"       "ls -tr base"
    run_cmp "-ta"                                  "-ta base"       "ls -ta base"
    run_cmp "-tra"                                 "-tra base"      "ls -tra base"
    run_cmp "-t su sottocartella"                  "-t base/alpha"  "ls -t base/alpha"
    run_cmp "senza -t resta alfabetico"            "base"           "ls base"
    ;;
7)
    echo "Atteso: formato lungo identico a ls -l (total, permessi, link, utente, gruppo, dimensione, data, nome)"
    run_cmp "-l"                                   "-l base"            "ls -l base"
    run_cmp "-la"                                  "-la base"           "ls -la base"
    run_cmp "-lr"                                  "-lr base"           "ls -lr base"
    run_cmp "-lt"                                  "-lt base"           "ls -lt base"
    run_cmp "-ltra"                                "-ltra base"         "ls -ltra base"
    run_cmp "-l con un solo file"                  "-l base/alpha/sub"  "ls -l base/alpha/sub"
    run_cmp "-l cartella vuota"                    "-l base/zeta"       "ls -l base/zeta"
    ;;
8)
    echo "Atteso: -R entra nelle sottocartelle dopo aver stampato la cartella corrente"
    run_cmp "-R"                                   "-R base"        "ls -R base"
    run_cmp "-Ra (non entra in . e ..)"            "-Ra base"       "ls -Ra base"
    run_cmp "-Rr"                                  "-Rr base"       "ls -Rr base"
    run_cmp "-Rt"                                  "-Rt base"       "ls -Rt base"
    run_cmp "-lR"                                  "-lR base"       "ls -lR base"
    run_cmp "-lRa"                                 "-lRa base"      "ls -lRa base"
    run_cmp "-R su sottocartella"                  "-R base/alpha"  "ls -R base/alpha"
    ;;
*)
    echo "Passo non valido: usa un numero da 1 a 8"
    exit 1
    ;;
esac

echo
echo "Passo $STEP: $pass/$n passati"
[ $fail -eq 0 ] && echo "Passo completato, puoi andare avanti."
[ $fail -eq 0 ]