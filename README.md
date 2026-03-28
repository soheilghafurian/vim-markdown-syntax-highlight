# vim-markdown-syntax-highlight

Markdown syntax highlighting plugin for Vim and Neovim.

This plugin provides syntax highlighting, fenced code block highlighting with
embedded language support, header navigation, URL handling, and table of
contents generation for markdown files.

It is a drop-in replacement for
[preservim/vim-markdown](https://github.com/preservim/vim-markdown) with a fix
for a long-standing syntax highlighting bug (see [Motivation](#motivation)).

## Feature list

| Feature | Description |
|---------|-------------|
| Syntax highlighting | Headings, bold, italic, bold italic, inline code, fenced code blocks, indented code blocks, links, images, autolinks, link definitions, blockquotes, ordered and unordered lists, checkboxes, horizontal rules, footnotes, line breaks |
| Fenced code highlighting | Embedded language syntax inside `` ``` `` blocks (e.g. Python, JavaScript, Bash) |
| LaTeX math | `$...$` inline and `$$...$$` display math via included TeX syntax |
| Strikethrough | `~~text~~` highlighting |
| Frontmatter | YAML (`---`), TOML (`+++`), and JSON (`{}`) frontmatter highlighting |
| Concealing | Hide syntax characters (`*`, `` ` ``, `[`, `]`, etc.) when `conceallevel` is set |
| Header navigation | `]]`, `[[`, `][`, `[]`, `]u`, `]h` for jumping between headers by level, sibling, or parent |
| URL handling | `gx` to open URLs in a browser, `ge` to open linked files in Vim |
| Table of contents | `:Toc`, `:Tocv`, `:Toch`, `:Toct` to view; `:InsertToc`, `:InsertNToc` to insert |
| Header level commands | `:HeaderIncrease`, `:HeaderDecrease`, `:SetexToAtx` |
| Table formatting | `:TableFormat` to align markdown tables (requires [Tabularize](https://github.com/godlygeek/tabular)) |
| Reliable highlighting | Correct syntax everywhere in the file — no gray text when jumping to the end |
| Code block background | Full-line background color on fenced code blocks using signs |
| Header background | Full-line background color on headings, dimming with each level |
| Configurable sync | Tunable lookback (`g:vim_markdown_sync_minlines`) for performance on very large files |
| Drop-in compatible | Same config variables (`g:vim_markdown_*`), highlight groups, and `<Plug>` mappings as vim-markdown |

## Motivation

Vim's syntax engine uses a "sync" mechanism to determine how far back it
should look when redrawing the screen. The popular vim-markdown plugin sets
this to `syntax sync linebreaks=1`, which means Vim only looks back **1 line**
to figure out what syntax state it's in.

This causes a problem: when you jump to the end of a file (e.g. `G`,
`Ctrl-D`, `Ctrl-U`, or search), Vim doesn't look back far enough to see the
start of multi-line constructs like fenced code blocks. The result is that text
near the bottom of the file loses all syntax highlighting and appears as plain
gray text. The only workaround is to scroll back to the top and page down
through the entire file (`Ctrl-F`) so Vim incrementally rebuilds the correct
state.

This plugin fixes the issue by using `syntax sync fromstart`, which tells Vim
to always parse from line 1 of the file. This guarantees correct highlighting
everywhere, regardless of how you navigate. For very large files, a
configurable `minlines` option is available to limit lookback and maintain
performance.

Additionally, this plugin re-applies the sync setting after dynamically
including fenced language syntax files (which can alter the sync state),
ensuring the fix is never silently undone.

## Installation

### Vundle

```vim
Plugin 'soheilghafurian/vim-markdown-syntax-highlight'
```

Then run `:PluginInstall` in Vim.

### vim-plug

```vim
Plug 'soheilghafurian/vim-markdown-syntax-highlight'
```

Then run `:PlugInstall` in Vim.

### Manual

Clone this repository into your Vim packages directory:

```bash
# Vim
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/soheilghafurian/vim-markdown-syntax-highlight.git

# Neovim
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
cd ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/soheilghafurian/vim-markdown-syntax-highlight.git
```

### Switching from vim-markdown

If you are currently using `preservim/vim-markdown`, remove or comment it out
and add this plugin instead. **No other changes are needed.** This plugin uses
the same configuration variables (`g:vim_markdown_*`), the same highlight
group names (`mkdCode`, `htmlH1`, etc.), and the same `<Plug>` mappings, so
your existing `.vimrc` settings will work as-is.

```vim
" Comment out the old plugin:
" Plugin 'preservim/vim-markdown'

" Add this plugin:
Plugin 'soheilghafurian/vim-markdown-syntax-highlight'
```

**Note:** This plugin does not include folding. If you were using
vim-markdown's built-in folding and had not disabled it, you will need a
separate folding solution.

## Features

### Syntax highlighting

All standard markdown elements are highlighted:

- **Headings** — both atx-style (`# H1` through `###### H6`) and setext-style
  (underlined with `=` or `-`)
- **Emphasis** — `*italic*`, `_italic_`, `**bold**`, `__bold__`,
  `***bold italic***`, `___bold italic___`
- **Code** — inline `` `code` ``, double-backtick ``` ``code`` ```, fenced
  code blocks (`` ``` `` and `~~~`), indented code blocks, and HTML
  `<code>`/`<pre>` tags
- **Links** — `[text](url)`, `[text][id]`, `[text][]`, `![image](url)`,
  autolinks (`https://...`), angle-bracket autolinks (`<https://...>`)
- **Link definitions** — `[id]: url "title"`
- **Blockquotes** — `> quoted text`
- **Lists** — unordered (`-`, `*`, `+`), ordered (`1.`), and checkboxes
  (`- [x]`, `- [ ]`)
- **Horizontal rules** — `***`, `---`, `___` (with optional spaces)
- **Footnotes** — `[^1]`
- **Line breaks** — trailing double spaces

### Fenced code block highlighting

Code inside fenced blocks gets full syntax highlighting for the specified
language. The plugin scans your buffer for fenced blocks like:

    ```python
    def hello():
        print("world")
    ```

and dynamically loads the corresponding Vim syntax file so the code inside is
highlighted as Python (or whatever language you specify).

This works with both backtick (`` ``` ``) and tilde (`~~~`) fences.

#### Configuring fenced languages

By default, the plugin recognizes a small set of language aliases:

| You write   | Vim syntax file used |
|-------------|----------------------|
| `c++`       | `cpp`                |
| `viml`      | `vim`                |
| `bash`      | `sh`                 |
| `ini`       | `dosini`             |
| `hack`      | `php`                |

To customize this (or to pre-register languages for faster loading), set
`g:vim_markdown_fenced_languages` in your `.vimrc`:

```vim
let g:vim_markdown_fenced_languages = ['python', 'bash=sh', 'javascript', 'vim', 'sql', 'json', 'html', 'css', 'c', 'cpp', 'java', 'ruby', 'go', 'rust', 'lua', 'yaml']
```

The format is a list of strings. Each string is either:
- A language name that matches its Vim syntax file (e.g. `'python'` loads
  `syntax/python.vim`)
- A `name=filetype` mapping (e.g. `'bash=sh'` means `` ```bash `` loads
  `syntax/sh.vim`)

### LaTeX math

Enable LaTeX math syntax highlighting inside `$...$` (inline) and `$$...$$`
(display) delimiters:

```vim
let g:vim_markdown_math = 1
```

### Strikethrough

Enable `~~strikethrough~~` highlighting:

```vim
let g:vim_markdown_strikethrough = 1
```

### Frontmatter

Highlight YAML, TOML, or JSON frontmatter at the top of the file:

```vim
" YAML frontmatter (between --- delimiters)
let g:vim_markdown_frontmatter = 1

" TOML frontmatter (between +++ delimiters)
let g:vim_markdown_toml_frontmatter = 1

" JSON frontmatter (between { } delimiters)
let g:vim_markdown_json_frontmatter = 1
```

### Concealing

When Vim's `conceallevel` is set to 2, markdown syntax characters (like `*`
around bold text, `[` `]` `(` `)` around links, and `` ` `` around code) are
hidden, showing only the content. This makes markdown files look cleaner while
editing.

```vim
" Toggle concealing on/off (example mapping):
nnoremap <leader>c :if &conceallevel == 0 | set conceallevel=2 | else | set conceallevel=0 | endif<CR>
```

To disable concealing of specific elements:

```vim
" Disable all concealing (show all syntax characters)
let g:vim_markdown_conceal = 0

" Disable concealing only for code blocks/inline code
let g:vim_markdown_conceal_code_blocks = 0
```

### Header navigation

The following key mappings are available in markdown buffers for navigating
between headers. They work in both normal and visual mode.

| Mapping | Action                                |
|---------|---------------------------------------|
| `]]`    | Go to next header (any level)         |
| `[[`    | Go to previous header (any level)     |
| `][`    | Go to next sibling header             |
| `[]`    | Go to previous sibling header         |
| `]u`    | Go to parent header                   |
| `]h`    | Go to current header (start of section) |

To disable all default key mappings:

```vim
let g:vim_markdown_no_default_key_mappings = 1
```

You can then create your own mappings using the `<Plug>` names:

```vim
nmap ]] <Plug>Markdown_MoveToNextHeader
nmap [[ <Plug>Markdown_MoveToPreviousHeader
nmap ][ <Plug>Markdown_MoveToNextSiblingHeader
nmap [] <Plug>Markdown_MoveToPreviousSiblingHeader
nmap ]u <Plug>Markdown_MoveToParentHeader
nmap ]h <Plug>Markdown_MoveToCurHeader
```

### URL handling

| Mapping | Action                                     |
|---------|--------------------------------------------|
| `gx`    | Open the URL under the cursor in a browser |
| `ge`    | Open the linked file in Vim for editing    |

The `ge` mapping opens the file referenced by a markdown link (e.g.
`[text](other-file.md)`) in the current buffer. The `<Plug>` names are:

```vim
nmap gx <Plug>Markdown_OpenUrlUnderCursor
nmap ge <Plug>Markdown_EditUrlUnderCursor
```

#### Configuring ge behavior

Control how `ge` opens linked files:

```vim
" Open in a new tab (default: current buffer)
let g:vim_markdown_edit_url_in = 'tab'

" Other options: 'vsplit', 'hsplit'
```

Follow anchor links (`file.md#section`):

```vim
let g:vim_markdown_follow_anchor = 1
```

Auto-append `.md` extension when following links that omit it:

```vim
let g:vim_markdown_no_extensions_in_markdown = 1

" Use a different extension instead of .md:
let g:vim_markdown_auto_extension_ext = 'txt'
```

Auto-save before following a link:

```vim
let g:vim_markdown_autowrite = 1
```

### Table of contents

Generate a table of contents from the headers in the current file.

| Command      | Action                                        |
|--------------|-----------------------------------------------|
| `:Toc`       | Open TOC in a vertical split (default)        |
| `:Tocv`      | Open TOC in a vertical split                  |
| `:Toch`      | Open TOC in a horizontal split                |
| `:Toct`      | Open TOC in a new tab                         |
| `:InsertToc` | Insert a bulleted TOC at the cursor position  |
| `:InsertNToc`| Insert a numbered TOC at the cursor position  |

The TOC window uses the location list. Press `Enter` on a header to jump to
it. Both `:InsertToc` and `:InsertNToc` accept an optional argument to limit
the maximum heading level (e.g. `:InsertToc 3` includes only h2 and h3).

Auto-fit the TOC window width to the longest header:

```vim
let g:vim_markdown_toc_autofit = 1
```

### Header level commands

| Command           | Action                                        |
|-------------------|-----------------------------------------------|
| `:HeaderDecrease` | Decrease all header levels by one (h2 -> h1)  |
| `:HeaderIncrease` | Increase all header levels by one (h1 -> h2)  |
| `:SetexToAtx`     | Convert setext-style headers to atx-style (`#`)|

These commands accept a range. For example, to increase header levels only in
the visually selected region: select the lines, then type `:HeaderIncrease`.

### Code block background

Fenced code blocks (`` ``` `` and `~~~`) get a subtle full-line background
color, making them visually distinct from surrounding text. This uses Vim's
sign column with `linehl`, so it works alongside syntax highlighting and at
any `conceallevel`.

The default background is a dark gray (`guibg=#0d0d0d`, `ctermbg=234`). To
customize it, define the `CodeBlockBg` highlight group in your `.vimrc`
before the plugin loads:

```vim
highlight CodeBlockBg ctermbg=17 guibg=#0a0a1a    " navy blue
```

A full color palette is included as comments in `ftplugin/markdown.vim` for
easy switching.

### Header background

Heading lines (`#` through `######`) get a full-line background color that
dims with each level — H1 is the strongest, H6 the most subtle. This uses
the same sign-based approach as code block backgrounds.

The default base color is a warm brown (`guibg=#18100a`, `ctermbg=94`). The
plugin generates six dimming levels automatically:
H1=100%, H2=82%, H3=67%, H4=55%, H5=45%, H6=37% of the base color.

To customize the base color, define `MarkdownHeaderBg` in your `.vimrc`:

```vim
highlight MarkdownHeaderBg ctermbg=17 guibg=#121230    " navy blue
```

A full color palette (blues, purples, teals, indigos, grays, olives, reds,
greens, browns) is included as comments in `ftplugin/markdown.vim`.

### Table formatting

The `:TableFormat` command formats the markdown table under the cursor. It
aligns columns and normalizes the separator line. **Requires the
[Tabularize](https://github.com/godlygeek/tabular) plugin.**

Support borderless tables (tables without leading/trailing `|`):

```vim
let g:vim_markdown_borderless_table = 1
```

## Configuration reference

All configuration is done through global variables set in your `.vimrc`
(before the plugin loads).

### Syntax highlighting options

| Variable | Default | Description |
|----------|---------|-------------|
| `g:vim_markdown_math` | `0` | Enable LaTeX math highlighting |
| `g:vim_markdown_strikethrough` | `0` | Enable `~~strikethrough~~` |
| `g:vim_markdown_frontmatter` | `0` | Enable YAML frontmatter |
| `g:vim_markdown_toml_frontmatter` | `0` | Enable TOML frontmatter |
| `g:vim_markdown_json_frontmatter` | `0` | Enable JSON frontmatter |
| `g:vim_markdown_emphasis_multiline` | `1` | Allow bold/italic to span lines |
| `g:vim_markdown_fenced_languages` | (see above) | List of fenced code languages |

### Concealing options

| Variable | Default | Description |
|----------|---------|-------------|
| `g:vim_markdown_conceal` | `1` | Enable concealing of syntax characters |
| `g:vim_markdown_conceal_code_blocks` | `1` | Enable concealing for code |

### Sync options

| Variable | Default | Description |
|----------|---------|-------------|
| `g:vim_markdown_sync_minlines` | `0` | If set to a number > 0, use `syntax sync minlines=N` instead of `fromstart`. Useful for very large files (10k+ lines) where `fromstart` may cause slow redraws. A value of 500 is a good starting point. |

### Mapping and behavior options

| Variable | Default | Description |
|----------|---------|-------------|
| `g:vim_markdown_no_default_key_mappings` | `0` | Disable all default mappings |
| `g:vim_markdown_edit_url_in` | `''` | How `ge` opens files: `'tab'`, `'vsplit'`, `'hsplit'` |
| `g:vim_markdown_follow_anchor` | `0` | Follow `#anchor` links |
| `g:vim_markdown_anchorexpr` | `''` | Custom expression for anchor matching |
| `g:vim_markdown_autowrite` | `0` | Auto-save before following links |
| `g:vim_markdown_no_extensions_in_markdown` | `0` | Auto-append `.md` to links |
| `g:vim_markdown_auto_extension_ext` | `'md'` | Extension to append |
| `g:vim_markdown_toc_autofit` | `0` | Auto-fit TOC window width |
| `g:vim_markdown_borderless_table` | `0` | Support borderless tables |

## Highlight groups

You can customize colors by setting highlight rules in your `.vimrc` (after
`colorscheme`). The plugin uses these groups:

| Group | Default link | Used for |
|-------|-------------|----------|
| `mkdHeading` | (matchgroup) | `#` characters in headings |
| `htmlH1` ... `htmlH6` | (from HTML syntax) | Heading text |
| `htmlItalic` | (from HTML syntax) | `*italic*` text |
| `htmlBold` | (from HTML syntax) | `**bold**` text |
| `htmlBoldItalic` | (from HTML syntax) | `***bold italic***` text |
| `mkdCode` | `String` | Code (inline, fenced, indented) |
| `mkdCodeDelimiter` | `String` | Backtick/tilde delimiters |
| `mkdCodeStart` | `String` | Opening fence of highlighted code blocks |
| `mkdCodeEnd` | `String` | Closing fence of highlighted code blocks |
| `mkdLink` | `htmlLink` | Link text `[text]` |
| `mkdURL` | `htmlString` | URL in `(url)` |
| `mkdInlineURL` | `htmlLink` | Bare URLs |
| `mkdID` | `Identifier` | Reference ID `[id]` |
| `mkdDelimiter` | `Delimiter` | Brackets, parens in links |
| `mkdLinkDef` | `mkdID` | Link definition ID |
| `mkdLinkDefTarget` | `mkdURL` | Link definition URL |
| `mkdLinkTitle` | `htmlString` | Link definition title |
| `mkdBlockquote` | `Comment` | `> blockquote` text |
| `mkdListItem` | `Identifier` | List markers (`-`, `*`, `1.`) |
| `mkdListItemCheckbox` | `Identifier` | Checkbox `[x]`, `[ ]` |
| `mkdRule` | `Identifier` | Horizontal rules |
| `mkdLineBreak` | `Visual` | Trailing spaces (line break) |
| `mkdFootnotes` | `htmlLink` | Footnote references |
| `mkdFootnote` | `Comment` | Footnote definitions |
| `mkdMath` | `Statement` | LaTeX math delimiters |
| `mkdStrike` | `htmlStrike` | `~~strikethrough~~` text |
| `CodeBlockBg` | (standalone) | Full-line background on fenced code blocks |
| `MarkdownHeaderBg` | (standalone) | Base color for heading backgrounds |
| `MarkdownH1Bg` ... `MarkdownH6Bg` | (generated) | Per-level heading backgrounds (dimmed from base) |

## Plugin structure

```
vim-markdown-syntax-highlight/
  ftdetect/markdown.vim    File type detection for .md files
  syntax/markdown.vim      Syntax highlighting definitions
  ftplugin/markdown.vim    Fenced highlighting, navigation, commands
```

## Requirements

- Vim 7.4+ or Neovim
- [Tabularize](https://github.com/godlygeek/tabular) (only for the
  `:TableFormat` command)

## License

MIT
