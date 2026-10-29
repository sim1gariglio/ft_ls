#!/usr/bin/env bash
#
# Tester per ft_ls: confronta ./ft_ls con il vero ls.
#
# Uso:
#   ./test.sh                 usa ./ft_ls nella cartella corrente
#   ./test.sh percorso/ft_ls  usa un altro eseguibile
#   VALGRIND=1 ./test.sh      controlla anche i memory leak (piu lento)
#   VERBOSE=1 ./test.sh       mostra le differenze anche per stderr
#
# Per ogni test confronta:
#   - stdout (deve essere identico)
#   - codice di uscita (deve essere identico)
#   - stderr (solo avviso: il formato dei messaggi lo sistemerai alla fine)

export LC_ALL=C
set -f   # niente espansione di * e ? negli argomenti dei test

FT_LS="$(realpath "${1:-./ft_ls}" 2>/dev/null)"
if [ ! -x "$FT_LS" ]; then
    echo "Eseguibile non trovato: ${1:-./ft_ls} (hai compilato?)"
    exit 1
fi

if [ "$VALGRIND" = "1" ] && ! command -v valgrind >/dev/null; then
    echo "valgrind non installato: sudo apt install valgrind"
    exit 1
fi

GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; RESET="\033[0m"

ROOT="$(mktemp -d /tmp/ft_ls_test.XXXXXX)"
OUT="$ROOT/.results"
mkdir -p "$OUT"

cleanup() {
    chmod -R u+rwx "$ROOT" 2>/dev/null
    rm -rf "$ROOT"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Creazione della cartella di prova
# ---------------------------------------------------------------------------
create_fixtures() {
    local b="$ROOT/base"
    mkdir -p "$b/alpha/sub" "$b/zeta" "$b/.hidden_dir"

    echo "contenuto" > "$b/file_b.txt"
    echo "A maiuscola" > "$b/File_A.txt"
    echo "x" > "$b/.hidden"
    echo "x" > "$b/.hidden_dir/dentro"
    echo "x" > "$b/alpha/inner.txt"
    echo "x" > "$b/alpha/sub/deep.txt"
    echo "spazio" > "$b/con spazio.txt"
    echo "uguale" > "$b/same1"
    echo "uguale" > "$b/same2"
    head -c 5000 /dev/zero > "$b/grande.bin"
    echo "vecchio" > "$b/old.txt"
    ln -s file_b.txt "$b/link_to_file"
    ln -s non_esiste "$b/broken_link"

    # Date diverse per testare -t (e il formato con l'anno per i file vecchi)
    touch -d "2026-03-01 10:00:00" "$b/file_b.txt"
    touch -d "2026-02-01 09:30:00" "$b/File_A.txt"
    touch -d "2026-01-15 08:00:00" "$b/same1" "$b/same2"   # pari merito: vince il nome
    touch -d "2026-01-10 12:00:00" "$b/grande.bin"
    touch -d "2026-01-05 12:00:00" "$b/con spazio.txt"
    touch -d "2024-05-01 18:00:00" "$b/old.txt"           # piu di 6 mesi fa
    touch -d "2026-02-20 07:00:00" "$b/alpha/inner.txt"
    touch -d "2026-02-10 07:00:00" "$b/alpha/sub/deep.txt"
    touch -h -d "2026-01-20 11:00:00" "$b/link_to_file" "$b/broken_link"
    touch -d "2026-01-25 11:00:00" "$b/.hidden" "$b/.hidden_dir/dentro"

    # Le date delle cartelle per ultime (creare file le modifica)
    touch -d "2026-02-25 10:00:00" "$b/alpha/sub" "$b/alpha"
    touch -d "2026-01-30 10:00:00" "$b/zeta" "$b/.hidden_dir"
    touch -d "2026-03-05 10:00:00" "$b"

    # Cartella con un errore di permessi dentro, per -R
    mkdir -p "$ROOT/errori/aperta" "$ROOT/errori/chiusa"
    echo "x" > "$ROOT/errori/aperta/file"
    echo "x" > "$ROOT/errori/chiusa/segreto"
    chmod 000 "$ROOT/errori/chiusa"
}

# ---------------------------------------------------------------------------
# Elenco dei test: "cartella_di_lavoro|argomenti"
# La cartella di lavoro e relativa a ROOT ("." = ROOT stesso)
# ---------------------------------------------------------------------------
TESTS=(
    "base|"
    ".|base"
    ".|-a base"
    ".|-r base"
    ".|-t base"
    ".|-tr base"
    ".|-ra base"
    ".|-l base"
    ".|-la base"
    ".|-lt base"
    ".|-ltr base"
    ".|-R base"
    ".|-Ra base"
    ".|-lR base"
    ".|-lRa base"
    ".|-Rtr base"
    ".|-l -a -R base"
    ".|-lartR base"
    ".|base/alpha base/zeta"
    ".|base/zeta base/alpha"
    ".|base/file_b.txt"
    ".|-l base/file_b.txt"
    ".|-l base/link_to_file"
    ".|base/file_b.txt base/alpha"
    ".|inesistente"
    ".|inesistente base"
    ".|-z base"
    ".|-l base/alpha/sub"
)

# I test sui permessi non hanno senso se giri come root
if [ "$(id -u)" != "0" ]; then
    TESTS+=(".|-R errori" ".|errori/chiusa")
fi

# ---------------------------------------------------------------------------
# Esecuzione
# ---------------------------------------------------------------------------
create_fixtures

pass=0; fail=0; warn=0; leaks=0; n=0

for t in "${TESTS[@]}"; do
    n=$((n + 1))
    cwd="${t%%|*}"
    args="${t#*|}"
    label="ls $args"
    [ "$cwd" != "." ] && label="(dentro $cwd) $label"

    exp="$OUT/$n.exp"; got="$OUT/$n.got"

    (cd "$ROOT/$cwd" && ls $args > "$exp.out" 2> "$exp.err"; echo $? > "$exp.code")
    (cd "$ROOT/$cwd" && "$FT_LS" $args > "$got.out" 2> "$got.err"; echo $? > "$got.code")

    ok=1
    cmp -s "$exp.out" "$got.out" || ok=0
    cmp -s "$exp.code" "$got.code" || ok=0

    if [ $ok -eq 1 ]; then
        pass=$((pass + 1))
        printf "${GREEN}[OK]${RESET}   %s\n" "$label"
    else
        fail=$((fail + 1))
        printf "${RED}[KO]${RESET}   %s\n" "$label"
        if ! cmp -s "$exp.out" "$got.out"; then
            echo "       stdout diverso (- ls vero, + ft_ls):"
            diff "$exp.out" "$got.out" | head -n 15 | sed 's/^/         /'
        fi
        if ! cmp -s "$exp.code" "$got.code"; then
            echo "       codice di uscita: ls=$(cat "$exp.code") ft_ls=$(cat "$got.code")"
        fi
    fi

    # stderr: confronta ignorando il nome del programma all'inizio della riga
    sed 's/^ls: //' "$exp.err" > "$exp.err.n"
    sed 's/^ft_ls: //' "$got.err" > "$got.err.n"
    if ! cmp -s "$exp.err.n" "$got.err.n"; then
        warn=$((warn + 1))
        printf "${YELLOW}       stderr diverso${RESET}"
        if [ "$VERBOSE" = "1" ]; then
            echo ":"
            echo "         ls vero: $(head -n 3 "$exp.err" | tr '\n' ' ')"
            echo "         ft_ls:   $(head -n 3 "$got.err" | tr '\n' ' ')"
        else
            echo " (VERBOSE=1 per i dettagli)"
        fi
    fi

    if [ "$VALGRIND" = "1" ]; then
        log="$OUT/$n.valgrind"
        (cd "$ROOT/$cwd" && valgrind --leak-check=full --show-leak-kinds=all \
            --errors-for-leak-kinds=definite,indirect,possible \
            --error-exitcode=242 --log-file="$log" \
            "$FT_LS" $args > /dev/null 2>&1)
        if [ $? -eq 242 ]; then
            leaks=$((leaks + 1))
            printf "${RED}       valgrind: leak o errori di memoria${RESET}\n"
            grep -E "definitely lost|indirectly lost|possibly lost|Invalid|uninitialised" "$log" \
                | head -n 5 | sed 's/^/         /'
        fi
    fi
done

echo
echo "Risultato: $pass/$n passati, $fail falliti, $warn con stderr diverso"
[ "$VALGRIND" = "1" ] && echo "Valgrind: $leaks test con problemi di memoria"
[ $fail -eq 0 ]