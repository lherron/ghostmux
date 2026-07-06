#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${GHOSTMUX_BIN:-$ROOT/.build/debug/ghostmux}"
README="${GHOSTMUX_README:-$ROOT/README.md}"
AGENTS="${GHOSTMUX_AGENTS:-$ROOT/AGENTS.md}"
COMMAND_DIR="$ROOT/Sources/ghostmux/Commands"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

failures=0

fail() {
  echo "command-surface: ERROR: $*" >&2
  failures=1
}

compare_files() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if ! diff -u "$expected" "$actual" >"$tmpdir/$label.diff"; then
    fail "$label drift"
    sed "s/^/command-surface: $label: /" "$tmpdir/$label.diff" >&2
  fi
}

if [[ ! -x "$BIN" ]]; then
  fail "ghostmux binary not found at $BIN"
  exit 1
fi

if [[ ! -f "$README" ]]; then
  fail "README not found at $README"
  exit 1
fi

if [[ ! -f "$AGENTS" ]]; then
  fail "AGENTS router not found at $AGENTS"
  exit 1
fi

if ! "$BIN" __command-surface >"$tmpdir/live.tsv" 2>"$tmpdir/live.err"; then
  fail "failed to read live command registry from $BIN"
  sed 's/^/command-surface: live-registry stderr: /' "$tmpdir/live.err" >&2
  exit 1
fi

sort "$tmpdir/live.tsv" >"$tmpdir/live.sorted.tsv"

awk -F '\t' '
  {
    print $1
    if ($2 != "") {
      n = split($2, aliases, ",")
      for (i = 1; i <= n; i++) print aliases[i]
    }
  }
' "$tmpdir/live.tsv" | sort -u >"$tmpdir/valid-command-tokens.txt"

perl -0ne '
  my ($name) = /static\s+let\s+name\s*=\s*"([^"]+)"/ or next;
  my @aliases = ();
  if (/static\s+let\s+aliases(?:\s*:\s*\[[^\]]+\])?\s*=\s*\[([^\]]*)\]/s) {
    @aliases = $1 =~ /"([^"]+)"/g;
  }
  print "$name\t", join(",", @aliases), "\n";
' "$COMMAND_DIR"/*.swift | sort >"$tmpdir/source.sorted.tsv"

compare_files source-vs-registry "$tmpdir/source.sorted.tsv" "$tmpdir/live.sorted.tsv"

if ! "$BIN" --help >"$tmpdir/root.help" 2>"$tmpdir/root.err"; then
  fail "root help failed"
  sed 's/^/command-surface: root-help stderr: /' "$tmpdir/root.err" >&2
fi

perl -ne '
  $in = 1 if /^\s*Commands:\s*$/;
  $in = 0 if /^\s*Options:\s*$/;
  if ($in && /^\s+([a-z0-9-]+(?:,\s*[a-z0-9-]+)*)\s{2,}/) {
    my @parts = split /,\s*/, $1;
    my $name = shift @parts;
    print "$name\t", join(",", @parts), "\n";
  }
' "$tmpdir/root.help" | sort >"$tmpdir/root.sorted.tsv"

compare_files root-help-vs-registry "$tmpdir/live.sorted.tsv" "$tmpdir/root.sorted.tsv"

while IFS=$'\t' read -r name aliases; do
  help_path="$tmpdir/help.$name.txt"
  err_path="$tmpdir/help.$name.err"
  if ! "$BIN" "$name" --help >"$help_path" 2>"$err_path"; then
    fail "per-command help failed for '$name'"
    sed "s/^/command-surface: $name stderr: /" "$err_path" >&2
    continue
  fi

  if ! grep -q 'Usage:' "$help_path"; then
    fail "per-command help for '$name' does not contain a Usage section"
  fi

  if ! grep -Eq "ghostmux[[:space:]]+$name([^[:alnum:]_-]|$)" "$help_path"; then
    fail "per-command help for '$name' does not reference 'ghostmux $name'"
  fi

  if [[ -n "${aliases:-}" ]]; then
    IFS=',' read -r -a alias_items <<<"$aliases"
    for alias in "${alias_items[@]}"; do
      alias_help_path="$tmpdir/help.alias.$alias.txt"
      alias_err_path="$tmpdir/help.alias.$alias.err"
      if ! "$BIN" "$alias" --help >"$alias_help_path" 2>"$alias_err_path"; then
        fail "alias '$alias' did not resolve to help for '$name'"
        sed "s/^/command-surface: $alias stderr: /" "$alias_err_path" >&2
        continue
      fi

      compare_files "alias-$alias-help-vs-$name" "$help_path" "$alias_help_path"
    done
  fi

  if ! grep -Eq "(^|[^[:alnum:]_-])ghostmux[[:space:]]+$name([^[:alnum:]_-]|$)" "$README"; then
    fail "README does not reference canonical command 'ghostmux $name'"
  fi
done <"$tmpdir/live.tsv"

perl -ne '
  BEGIN {
    $line = 0;
    $last_argv = "";
    $in_fence = 0;
  }

  sub emit_examples {
    my ($file, $line, $text) = @_;
    while ($text =~ /(?:^|[[:space:]\/])ghostmux\s+([a-z0-9-]+)\b[^\n`]*/g) {
      my $example = $&;
      $example =~ s/^.*?\bghostmux\b/ghostmux/;
      $example =~ s/\t/ /g;
      $example =~ s/[[:space:]]+$//;
      print "$file\t$line\t$example\n";
    }
  }

  if ($ARGV ne $last_argv) {
    $line = 0;
    $last_argv = $ARGV;
    $in_fence = 0;
  }
  $line++;

  if (/^\s*```/) {
    $in_fence = !$in_fence;
    next;
  }

  if ($in_fence) {
    emit_examples($ARGV, $line, $_);
    next;
  }

  while (/`([^`]*)`/g) {
    emit_examples($ARGV, $line, $1);
  }
' "$README" "$AGENTS" >"$tmpdir/doc-examples.tsv"

awk -F '\t' '{ print $3 }' "$tmpdir/doc-examples.tsv" | perl -ne '
  print "$1\n" if /^ghostmux\s+([a-z0-9-]+)\b/;
' | sort -u >"$tmpdir/referenced-command-tokens.txt"

if ! comm -23 "$tmpdir/referenced-command-tokens.txt" "$tmpdir/valid-command-tokens.txt" >"$tmpdir/unknown-command-tokens.txt"; then
  fail "failed to compare referenced command tokens"
fi

if [[ -s "$tmpdir/unknown-command-tokens.txt" ]]; then
  fail "docs reference unknown ghostmux command token(s)"
  sed 's/^/command-surface: unknown-token: /' "$tmpdir/unknown-command-tokens.txt" >&2
fi

cat >"$tmpdir/validate-doc-example-options.pl" <<'PERL'
use strict;
use warnings;
use File::Basename qw(basename);

my ($tmpdir) = @ARGV;

sub read_registry {
  my ($path) = @_;
  my %canonical_for;
  open my $fh, "<", $path or die "open $path: $!";
  while (my $line = <$fh>) {
    chomp $line;
    my ($name, $aliases) = split /\t/, $line, 2;
    next unless defined $name && length $name;
    $canonical_for{$name} = $name;
    for my $alias (split /,/, $aliases // "") {
      next unless length $alias;
      $canonical_for{$alias} = $name;
    }
  }
  close $fh;
  return %canonical_for;
}

sub parse_help_options {
  my ($path) = @_;
  my (%options, $saw_options);
  open my $fh, "<", $path or die "open $path: $!";
  while (my $line = <$fh>) {
    if ($line =~ /^\s*Options:\s*$/) {
      $saw_options = 1;
      next;
    }
    if ($saw_options && $line =~ /^\S/) {
      last;
    }
    next unless $saw_options;
    next unless $line =~ /^\s+-/;
    while ($line =~ /(?<!\S)(--[A-Za-z0-9][A-Za-z0-9-]*|-[A-Za-z])(?=[,\s]|$)/g) {
      $options{$1} = 1;
    }
  }
  close $fh;
  return ($saw_options, %options);
}

sub shell_words {
  my ($text) = @_;
  my @words;
  my ($buf, $quote, $had_unquoted, $had_quoted) = ("", "", 0, 0);
  my @chars = split //, $text;

  for (my $i = 0; $i < @chars; $i++) {
    my $ch = $chars[$i];

    if ($quote ne "") {
      if ($ch eq $quote) {
        $quote = "";
      } elsif ($ch eq "\\" && $quote eq "\"" && $i + 1 < @chars) {
        $buf .= $chars[++$i];
        $had_quoted = 1;
      } else {
        $buf .= $ch;
        $had_quoted = 1;
      }
      next;
    }

    if ($ch =~ /\s/) {
      if (length($buf) || $had_quoted) {
        push @words, { text => $buf, quoted_only => !$had_unquoted };
      }
      ($buf, $had_unquoted, $had_quoted) = ("", 0, 0);
      next;
    }

    last if $ch eq "#" && !length($buf) && !$had_quoted;

    if ($ch eq "'" || $ch eq "\"") {
      $quote = $ch;
      $had_quoted = 1;
      next;
    }

    if ($ch eq "\\" && $i + 1 < @chars) {
      $buf .= $chars[++$i];
    } else {
      $buf .= $ch;
    }
    $had_unquoted = 1;
  }

  if (length($buf) || $had_quoted) {
    push @words, { text => $buf, quoted_only => !$had_unquoted };
  }

  return @words;
}

sub example_flags {
  my ($example) = @_;
  my @words = shell_words($example);
  my @flags;

  # Flag-shaped tokens that are wholly quoted, or occur after an explicit "--",
  # are command arguments rather than ghostmux options for this conformance check.
  for my $word (@words[2 .. $#words]) {
    last if $word->{text} eq "--";
    next if $word->{quoted_only};
    my $text = $word->{text};

    if ($text =~ /^(--[A-Za-z0-9][A-Za-z0-9-]*)(?:=.*)?$/) {
      push @flags, $1;
    } elsif ($text =~ /^-([A-Za-z])$/) {
      push @flags, "-$1";
    } elsif ($text =~ /^-([A-Za-z]{2,})$/) {
      push @flags, map { "-$_" } split //, $1;
    }
  }

  return @flags;
}

my %canonical_for = read_registry("$tmpdir/live.tsv");
my ($root_saw_options, %root_options) = parse_help_options("$tmpdir/root.help");
my (%command_saw_options, %command_options);

for my $canonical (sort grep { $canonical_for{$_} eq $_ } keys %canonical_for) {
  my ($saw_options, %options) = parse_help_options("$tmpdir/help.$canonical.txt");
  $command_saw_options{$canonical} = $saw_options && keys(%options) > 0;
  $command_options{$canonical} = \%options;
}

my $failed = 0;
while (my $line = <STDIN>) {
  chomp $line;
  my ($file, $line_no, $example) = split /\t/, $line, 3;
  next unless defined $example && $example =~ /^ghostmux\s+([a-z0-9-]+)\b/;

  my $token = $1;
  my $canonical = $canonical_for{$token};
  next unless defined $canonical;

  my @flags = example_flags($example);
  next unless @flags;

  if (!$command_saw_options{$canonical}) {
    print STDERR "command-surface: doc-option: "
      . basename($file) . ":$line_no example '$example' uses flags, but command '$canonical' help has no parseable Options section\n";
    $failed = 1;
    next;
  }

  my %accepted = (%root_options, %{ $command_options{$canonical} });
  for my $flag (@flags) {
    next if $accepted{$flag};
    print STDERR "command-surface: doc-option: "
      . basename($file) . ":$line_no example '$example' uses unsupported flag '$flag' for command '$canonical'\n";
    $failed = 1;
  }
}

exit($failed ? 1 : 0);
PERL

if ! perl "$tmpdir/validate-doc-example-options.pl" "$tmpdir" <"$tmpdir/doc-examples.tsv"; then
  fail "docs reference unsupported ghostmux option flag(s)"
fi

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

echo "command-surface conformance OK"
