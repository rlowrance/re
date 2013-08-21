// csvParse.c
// parse a csv line into its constituent strings

// source: http://cboard.cprogramming.com/c-programming/47105-how-read-csv-file.html

// parse line into array list[size]
// return number of items actually parsed (up to size)
int csvParse(char* line, char *list[], int size) {
  char *p = NULL;
  char *dp = NULL;
  int inquote = 0;
  int na = 0;
  char prevc = ',';

  for(p = line; *p != '\0'; prevc = *p, p++) {
    if (!inquote && prevc == ',') {
      if (dp != NULL) *dp = '\0';
      if (na >= size) return na;
      list[na++] = p;
      dp = p;
      if (*p == QUOTE) {
        inquote = 1;
        continue;
      }
    }
    if (inquote && *p == QUOTE) {
      if (p[1] != QUOTE) inquote = 0;
      p++;
    }
    if (inquote || *p != ',') *dp = '\0';
    if (na < size) list[na] = NULL;

}
