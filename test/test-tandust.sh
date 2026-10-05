TMP_TANDUST=$(mktemp -d)

cat > "$TMP_TANDUST/reads.fa" <<'EOF'
>homopolymer
AAAAAAAAAAAA
>dinucleotide
ATATATATATAT
>imperfect
ATGATGACGATG
>ambiguous
NNNNNNNNNNNN
>random
ACGTTCGAGTCA
>suffix
GGGACACACACAC
EOF

cat > "$TMP_TANDUST/reads.fq" <<'EOF'
@homopolymer
AAAAAAAAAAAA
+
IIIIIIIIIIII
@random
ACGTTCGAGTCA
+
IIIIIIIIIIII
EOF

cat > "$TMP_TANDUST/R1.fq" <<'EOF'
@pair1
AAAAAAAAAAAA
+
IIIIIIIIIIII
@pair2
ACGTTCGAGTCA
+
IIIIIIIIIIII
@pair3
ATATATATATAT
+
IIIIIIIIIIII
EOF

cat > "$TMP_TANDUST/R2.fq" <<'EOF'
@pair1
ACGTTCGAGTCA
+
IIIIIIIIIIII
@pair2
TGCAGACTTGCA
+
IIIIIIIIIIII
@pair3
TATATATATATA
+
IIIIIIIIIIII
EOF

TANDUST_OUT=$("$BIN" tandust "$TMP_TANDUST/reads.fa")
TANDUST_COUNT=$(printf "%s\n" "$TANDUST_OUT" | grep -c '^>')
if [[ "$TANDUST_COUNT" -eq 2 ]] &&
   printf "%s\n" "$TANDUST_OUT" | grep -q '^>ambiguous' &&
   printf "%s\n" "$TANDUST_OUT" | grep -q '^>random'; then
  echo -e "$OK: tandust discards short tandem repeats and keeps ambiguous/random reads"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: tandust default FASTA filtering unexpected output"
  ERRORS=$((ERRORS+1))
fi

TANDUST_INVERT=$("$BIN" tandust --invert "$TMP_TANDUST/reads.fa" | grep -c '^>')
if [[ "$TANDUST_INVERT" -eq 4 ]]; then
  echo -e "$OK: tandust --invert prints repetitive reads"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: tandust --invert expected 4 repetitive reads, got $TANDUST_INVERT"
  ERRORS=$((ERRORS+1))
fi

TANDUST_STRICT=$("$BIN" tandust --min-identity 1.0 "$TMP_TANDUST/reads.fa" | grep -c '^>')
if [[ "$TANDUST_STRICT" -eq 3 ]]; then
  echo -e "$OK: tandust --min-identity controls imperfect repeat handling"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: tandust --min-identity 1.0 expected 3 kept reads, got $TANDUST_STRICT"
  ERRORS=$((ERRORS+1))
fi

"$BIN" tandust "$TMP_TANDUST/reads.fa" --report "$TMP_TANDUST/report.tsv" > /dev/null
if [[ $(wc -l < "$TMP_TANDUST/report.tsv" | tr -d ' ') -eq 5 ]] &&
   grep -q $'homopolymer\t1\tA\t1\t9\t9\t1.0000' "$TMP_TANDUST/report.tsv" &&
   grep -q $'imperfect\t3\tATG\t1\t12\t12\t0.9167' "$TMP_TANDUST/report.tsv"; then
  echo -e "$OK: tandust report records repeat hit coordinates and identity"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: tandust report did not contain expected hits"
  ERRORS=$((ERRORS+1))
fi

"$BIN" tandust -1 "$TMP_TANDUST/R1.fq" -2 "$TMP_TANDUST/R2.fq" -o "$TMP_TANDUST/any"
ANY_R1=$(grep -c '^@' "$TMP_TANDUST/any_R1.fastq")
ANY_R2=$(grep -c '^@' "$TMP_TANDUST/any_R2.fastq")
if [[ "$ANY_R1" -eq 1 && "$ANY_R2" -eq 1 ]]; then
  echo -e "$OK: tandust paired default policy discards pair if either mate is repetitive"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: tandust paired any policy expected 1 pair, got R1=$ANY_R1 R2=$ANY_R2"
  ERRORS=$((ERRORS+1))
fi

"$BIN" tandust -1 "$TMP_TANDUST/R1.fq" -2 "$TMP_TANDUST/R2.fq" -o "$TMP_TANDUST/both" --pair-policy both
BOTH_R1=$(grep -c '^@' "$TMP_TANDUST/both_R1.fastq")
BOTH_R2=$(grep -c '^@' "$TMP_TANDUST/both_R2.fastq")
if [[ "$BOTH_R1" -eq 2 && "$BOTH_R2" -eq 2 ]]; then
  echo -e "$OK: tandust paired both policy discards pair only if both mates are repetitive"
  PASS=$((PASS+1))
else
  echo -e "$FAIL: tandust paired both policy expected 2 pairs, got R1=$BOTH_R1 R2=$BOTH_R2"
  ERRORS=$((ERRORS+1))
fi

if "$BIN" tandust --max-unit 0 "$TMP_TANDUST/reads.fa" >/dev/null 2>"$TMP_TANDUST/err"; then
  echo -e "$FAIL: tandust accepted invalid --max-unit"
  ERRORS=$((ERRORS+1))
else
  echo -e "$OK: tandust rejects invalid numeric options"
  PASS=$((PASS+1))
fi

rm -rf "$TMP_TANDUST"
