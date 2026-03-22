" syntax/markdown.vim - Markdown syntax highlighting
"
" Drop-in replacement for preservim/vim-markdown syntax highlighting.
" Key improvement: uses `syntax sync fromstart` so highlighting never breaks
" when jumping around the file (e.g. G, Ctrl-D, Ctrl-U).
"
" Uses the same highlight groups (mkd*, html*) and config variables
" (g:vim_markdown_*) as vim-markdown for full compatibility.

scriptencoding utf-8

" Read the HTML syntax to start with (provides htmlH1-H6, htmlBold, etc.)
if v:version < 600
  source <sfile>:p:h/html.vim
else
  runtime! syntax/html.vim
  if exists('b:current_syntax')
    unlet b:current_syntax
  endif
endif

if v:version < 600
  syntax clear
elseif exists('b:current_syntax')
  finish
endif

if v:version < 508
  command! -nargs=+ MkdHiLink highlight link <args>
else
  command! -nargs=+ MkdHiLink highlight default link <args>
endif

syntax spell toplevel
syntax case ignore

" SYNC FIX: This is the core improvement over vim-markdown.
"
" vim-markdown uses `syntax sync linebreaks=1`, which tells Vim to only look
" back 1 line when determining syntax state for redrawing. When you jump to
" the end of a file (G, Ctrl-G, Ctrl-D), Vim doesn't look far enough back to
" see the opening of multi-line regions like fenced code blocks, so everything
" renders as unhighlighted gray text.
"
" `fromstart` makes Vim always parse from line 1 — always correct.
" For very large files (10k+ lines), set g:vim_markdown_sync_minlines to a
" number (e.g. 500) to limit lookback and improve redraw performance.
let s:sync_minlines = get(g:, 'vim_markdown_sync_minlines', 0)
if s:sync_minlines > 0
  execute 'syntax sync minlines=' . s:sync_minlines
else
  syntax sync fromstart
endif

" Conceal setup
let s:conceal = ''
let s:concealends = ''
let s:concealcode = ''
if has('conceal') && get(g:, 'vim_markdown_conceal', 1)
  let s:conceal = ' conceal'
  let s:concealends = ' concealends'
endif
if has('conceal') && get(g:, 'vim_markdown_conceal_code_blocks', 1)
  let s:concealcode = ' concealends'
endif

" Emphasis (bold, italic, bold+italic)
if get(g:, 'vim_markdown_emphasis_multiline', 1)
    let s:oneline = ''
else
    let s:oneline = ' oneline'
endif

syntax region mkdItalic matchgroup=mkdItalic start="\%(\*\|_\)"    end="\%(\*\|_\)"
syntax region mkdBold matchgroup=mkdBold start="\%(\*\*\|__\)"    end="\%(\*\*\|__\)"
syntax region mkdBoldItalic matchgroup=mkdBoldItalic start="\%(\*\*\*\|___\)"    end="\%(\*\*\*\|___\)"
execute 'syntax region htmlItalic matchgroup=mkdItalic start="\%(^\|\s\)\zs\*\ze[^\\\*\t ]\%(\%([^*]\|\\\*\|\n\)*[^\\\*\t ]\)\?\*\_W" end="[^\\\*\t ]\zs\*\ze\_W" keepend contains=@Spell' . s:oneline . s:concealends
execute 'syntax region htmlItalic matchgroup=mkdItalic start="\%(^\|\s\)\zs_\ze[^\\_\t ]" end="[^\\_\t ]\zs_\ze\_W" keepend contains=@Spell' . s:oneline . s:concealends
execute 'syntax region htmlBold matchgroup=mkdBold start="\%(^\|\s\)\zs\*\*\ze\S" end="\S\zs\*\*" keepend contains=@Spell' . s:oneline . s:concealends
execute 'syntax region htmlBold matchgroup=mkdBold start="\%(^\|\s\)\zs__\ze\S" end="\S\zs__" keepend contains=@Spell' . s:oneline . s:concealends
execute 'syntax region htmlBoldItalic matchgroup=mkdBoldItalic start="\%(^\|\s\)\zs\*\*\*\ze\S" end="\S\zs\*\*\*" keepend contains=@Spell' . s:oneline . s:concealends
execute 'syntax region htmlBoldItalic matchgroup=mkdBoldItalic start="\%(^\|\s\)\zs___\ze\S" end="\S\zs___" keepend contains=@Spell' . s:oneline . s:concealends

" Links: [text](url) | [text][id] | [text][] | ![image](url)
syntax region mkdFootnotes matchgroup=mkdDelimiter start="\[^"    end="\]"
execute 'syntax region mkdID matchgroup=mkdDelimiter    start="\["    end="\]" contained oneline' . s:conceal
execute 'syntax region mkdURL matchgroup=mkdDelimiter   start="("     end=")"  contained oneline' . s:conceal
execute 'syntax region mkdLink matchgroup=mkdDelimiter  start="\\\@<!!\?\[\ze[^]\n]*\n\?[^]\n]*\][[(]" end="\]" contains=@mkdNonListItem,@Spell nextgroup=mkdURL,mkdID skipwhite' . s:concealends

" Autolinks (without angle brackets)
syntax match   mkdInlineURL /https\?:\/\/\(\w\+\(:\w\+\)\?@\)\?\([A-Za-z0-9][-_0-9A-Za-z]*\.\)\{1,}\(\w\{2,}\.\?\)\{1,}\(:[0-9]\{1,5}\)\?[^] \t]*/

" Autolinks (with parentheses)
syntax region  mkdInlineURL matchgroup=mkdDelimiter start="(\(https\?:\/\/\(\w\+\(:\w\+\)\?@\)\?\([A-Za-z0-9][-_0-9A-Za-z]*\.\)\{1,}\(\w\{2,}\.\?\)\{1,}\(:[0-9]\{1,5}\)\?[^] \t]*)\)\@=" end=")"

" Autolinks (with angle brackets)
syntax region mkdInlineURL matchgroup=mkdDelimiter start="\\\@<!<\ze[a-z][a-z0-9,.-]\{1,22}:\/\/[^> ]*>" end=">"

" Link definitions: [id]: URL (Optional Title)
syntax region mkdLinkDef matchgroup=mkdDelimiter   start="^ \{,3}\zs\[\^\@!" end="]:" oneline nextgroup=mkdLinkDefTarget skipwhite
syntax region mkdLinkDefTarget start="<\?\zs\S" excludenl end="\ze[>[:space:]\n]"   contained nextgroup=mkdLinkTitle,mkdLinkDef skipwhite skipnl oneline
syntax region mkdLinkTitle matchgroup=mkdDelimiter start=+"+     end=+"+  contained
syntax region mkdLinkTitle matchgroup=mkdDelimiter start=+'+     end=+'+  contained
syntax region mkdLinkTitle matchgroup=mkdDelimiter start=+(+     end=+)+  contained

" Headings (atx-style: # through ######)
syntax region htmlH1       matchgroup=mkdHeading     start="^\s*#"                   end="$" contains=@mkdHeadingContent,@Spell
syntax region htmlH2       matchgroup=mkdHeading     start="^\s*##"                  end="$" contains=@mkdHeadingContent,@Spell
syntax region htmlH3       matchgroup=mkdHeading     start="^\s*###"                 end="$" contains=@mkdHeadingContent,@Spell
syntax region htmlH4       matchgroup=mkdHeading     start="^\s*####"                end="$" contains=@mkdHeadingContent,@Spell
syntax region htmlH5       matchgroup=mkdHeading     start="^\s*#####"               end="$" contains=@mkdHeadingContent,@Spell
syntax region htmlH6       matchgroup=mkdHeading     start="^\s*######"              end="$" contains=@mkdHeadingContent,@Spell

" Headings (setext-style: underlined with = or -)
syntax match  htmlH1       /^.\+\n=\+$/ contains=@mkdHeadingContent,@Spell
syntax match  htmlH2       /^.\+\n-\+$/ contains=@mkdHeadingContent,@Spell

" Block elements
syntax match  mkdLineBreak    /  \+$/
syntax region mkdBlockquote   start=/^\s*>/                   end=/$/ contains=mkdLink,mkdInlineURL,mkdLineBreak,@Spell

" Inline code (single backtick, double backtick)
execute 'syntax region mkdCode matchgroup=mkdCodeDelimiter start=/\(\([^\\]\|^\)\\\)\@<!`/                     end=/`/'  . s:concealcode
execute 'syntax region mkdCode matchgroup=mkdCodeDelimiter start=/\(\([^\\]\|^\)\\\)\@<!``/ skip=/[^`]`[^`]/   end=/``/' . s:concealcode

" Fenced code blocks (``` and ~~~)
execute 'syntax region mkdCode matchgroup=mkdCodeDelimiter start=/^\s*\z(`\{3,}\)[^`]*$/                       end=/^\s*\z1`*\s*$/'            . s:concealcode
execute 'syntax region mkdCode matchgroup=mkdCodeDelimiter start=/\(\([^\\]\|^\)\\\)\@<!\~\~/  end=/\(\([^\\]\|^\)\\\)\@<!\~\~/'               . s:concealcode
execute 'syntax region mkdCode matchgroup=mkdCodeDelimiter start=/^\s*\z(\~\{3,}\)\s*[0-9A-Za-z_+-]*\s*$/      end=/^\s*\z1\~*\s*$/'           . s:concealcode

" HTML code tags
execute 'syntax region mkdCode matchgroup=mkdCodeDelimiter start="<pre\(\|\_s[^>]*\)\\\@<!>"                   end="</pre>"'                   . s:concealcode
execute 'syntax region mkdCode matchgroup=mkdCodeDelimiter start="<code\(\|\_s[^>]*\)\\\@<!>"                  end="</code>"'                  . s:concealcode

syntax region mkdFootnote     start="\[^"                     end="\]"

" Indented code blocks (8+ spaces or 2+ tabs for nested, 4+ spaces or tab for top-level)
syntax match  mkdCode         /^\s*\n\(\(\s\{8,}[^ ]\|\t\t\+[^\t]\).*\n\)\+/
syntax match  mkdCode         /\%^\(\(\s\{4,}[^ ]\|\t\+[^\t]\).*\n\)\+/
syntax match  mkdCode         /^\s*\n\(\(\s\{4,}[^ ]\|\t\+[^\t]\).*\n\)\+/ contained

" Lists
syntax match  mkdListItem     /^\s*\%([-*+]\|\d\+\.\)\ze\s\+/ contained nextgroup=mkdListItemCheckbox
syntax match  mkdListItemCheckbox     /\[[xXoO ]\]\ze\s\+/ contained contains=mkdListItem
syntax region mkdListItemLine start="^\s*\%([-*+]\|\d\+\.\)\s\+" end="$" oneline contains=@mkdNonListItem,mkdListItem,mkdListItemCheckbox,@Spell
syntax region mkdNonListItemBlock start="\(\%^\(\s*\([-*+]\|\d\+\.\)\s\+\)\@!\|\n\(\_^\_$\|\s\{4,}[^ ]\|\t+[^\t]\)\@!\)" end="^\(\s*\([-*+]\|\d\+\.\)\s\+\)\@=" contains=@mkdNonListItem,@Spell

" Horizontal rules
syntax match  mkdRule         /^\s*\*\s\{0,1}\*\s\{0,1}\*\(\*\|\s\)*$/
syntax match  mkdRule         /^\s*-\s\{0,1}-\s\{0,1}-\(-\|\s\)*$/
syntax match  mkdRule         /^\s*_\s\{0,1}_\s\{0,1}_\(_\|\s\)*$/

" YAML frontmatter
if get(g:, 'vim_markdown_frontmatter', 0)
  syntax include @yamlTop syntax/yaml.vim
  syntax region Comment matchgroup=mkdDelimiter start="\%^---$" end="^\(---\|\.\.\.\)$" contains=@yamlTop keepend
  unlet! b:current_syntax
endif

if get(g:, 'vim_markdown_toml_frontmatter', 0)
  try
    syntax include @tomlTop syntax/toml.vim
    syntax region Comment matchgroup=mkdDelimiter start="\%^+++$" end="^+++$" transparent contains=@tomlTop keepend
    unlet! b:current_syntax
  catch /E484/
    syntax region Comment matchgroup=mkdDelimiter start="\%^+++$" end="^+++$"
  endtry
endif

if get(g:, 'vim_markdown_json_frontmatter', 0)
  try
    syntax include @jsonTop syntax/json.vim
    syntax region Comment matchgroup=mkdDelimiter start="\%^{$" end="^}$" contains=@jsonTop keepend
    unlet! b:current_syntax
  catch /E484/
    syntax region Comment matchgroup=mkdDelimiter start="\%^{$" end="^}$"
  endtry
endif

" LaTeX math
if get(g:, 'vim_markdown_math', 0)
  syntax include @tex syntax/tex.vim
  syntax region mkdMath start="\\\@<!\$" end="\$" skip="\\\$" contains=@tex keepend
  syntax region mkdMath start="\\\@<!\$\$" end="\$\$" skip="\\\$" contains=@tex keepend
endif

" Strikethrough
if get(g:, 'vim_markdown_strikethrough', 0)
    execute 'syntax region mkdStrike matchgroup=htmlStrike start="\%(\~\~\)" end="\%(\~\~\)"' . s:concealends
    MkdHiLink mkdStrike        htmlStrike
endif

" Syntax clusters
syntax cluster mkdHeadingContent contains=htmlItalic,htmlBold,htmlBoldItalic,mkdFootnotes,mkdLink,mkdInlineURL,mkdStrike,mkdCode
syntax cluster mkdNonListItem contains=@htmlTop,htmlItalic,htmlBold,htmlBoldItalic,mkdFootnotes,mkdInlineURL,mkdLink,mkdLinkDef,mkdLineBreak,mkdBlockquote,mkdCode,mkdRule,htmlH1,htmlH2,htmlH3,htmlH4,htmlH5,htmlH6,mkdMath,mkdStrike

" Highlight links
MkdHiLink mkdString           String
MkdHiLink mkdCode             String
MkdHiLink mkdCodeDelimiter    String
MkdHiLink mkdCodeStart        String
MkdHiLink mkdCodeEnd          String
MkdHiLink mkdFootnote         Comment
MkdHiLink mkdBlockquote       Comment
MkdHiLink mkdListItem         Identifier
MkdHiLink mkdListItemCheckbox Identifier
MkdHiLink mkdRule             Identifier
MkdHiLink mkdLineBreak        Visual
MkdHiLink mkdFootnotes        htmlLink
MkdHiLink mkdLink             htmlLink
MkdHiLink mkdURL              htmlString
MkdHiLink mkdInlineURL        htmlLink
MkdHiLink mkdID               Identifier
MkdHiLink mkdLinkDef          mkdID
MkdHiLink mkdLinkDefTarget    mkdURL
MkdHiLink mkdLinkTitle        htmlString
MkdHiLink mkdDelimiter        Delimiter
MkdHiLink mkdMath             Statement

let b:current_syntax = 'mkd'

delcommand MkdHiLink
