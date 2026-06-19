" autoload/markdownfold.vim - Markdown folding by header, code block, and quote
" block. Merged in from the standalone vim-markdown-fold plugin.
"
" Folding is driven entirely by 'foldexpr' over raw buffer text (no syntax
" engine calls), so it keeps working with :syntax off.

" Build a lookup of fence lines and code-block regions.
" Cached per buffer change via b:changedtick.
"
" Fence detection mirrors s:HighlightCodeBlocks() in ftplugin/markdown.vim:
" any line opening with ``` or ~~~ toggles the in-code state. Keeping the same
" rule here means folding agrees with the rest of the plugin about what counts
" as a fenced code block (including ~~~ fences, which the standalone plugin
" missed).
function! s:ensure_cache() abort
  if exists('b:_mkfold_tick') && b:_mkfold_tick == b:changedtick
    return
  endif
  let b:_mkfold_tick = b:changedtick
  let b:_mkfold_fence = {}
  let b:_mkfold_in_code = {}
  let in_code = 0
  let i = 1
  let last = line('$')
  while i <= last
    if getline(i) =~# '^\s*```\|^\s*\~\~\~'
      if in_code
        let b:_mkfold_fence[i] = 'close'
        let in_code = 0
      else
        let b:_mkfold_fence[i] = 'open'
        let in_code = 1
      endif
    elseif in_code
      let b:_mkfold_in_code[i] = 1
    endif
    let i += 1
  endwhile
endfunction

function! markdownfold#foldexpr() abort
  call s:ensure_cache()
  let lnum = v:lnum
  let line = getline(lnum)

  " --- Fenced code blocks ------------------------------------------------
  let fence = get(b:_mkfold_fence, lnum, '')
  if fence ==# 'open'
    return "a1"
  endif
  " Closing fence: fold ends after this line (line itself stays inside fold).
  if fence ==# 'close'
    return "s1"
  endif
  " Lines between fences inherit level; skip all other rules.
  if get(b:_mkfold_in_code, lnum, 0)
    return "="
  endif

  " --- Headers ------------------------------------------------------------
  let h = matchstr(line, '^#\+')
  if !empty(h)
    return ">" . len(h)
  endif

  " --- Quote blocks -------------------------------------------------------
  if line =~# '^>'
    let prev_is_q = lnum > 1 && getline(lnum - 1) =~# '^>'
    let next_is_q = lnum < line('$') && getline(lnum + 1) =~# '^>'
    if !prev_is_q && next_is_q
      " First line of a multi-line quote run: start a nested fold.
      return "a1"
    endif
    if prev_is_q && !next_is_q
      " Last line of a quote run: fold ends after this line.
      return "s1"
    endif
    " Single-line quote (no fold) or middle of a run.
    return "="
  endif

  return "="
endfunction

" Close all code-block and quote-block folds (leave header folds alone).
function! markdownfold#close_blocks() abort
  call s:ensure_cache()
  let save_pos = getpos('.')
  " Code blocks: fold at every opening fence (only if visible).
  for lnum in keys(b:_mkfold_fence)
    if b:_mkfold_fence[lnum] ==# 'open' && foldclosed(lnum) == -1
      execute lnum . 'foldclose'
    endif
  endfor
  " Quote blocks: fold at the first line of each multi-line quote run (only if visible).
  let last = line('$')
  let lnum = 1
  while lnum <= last
    if getline(lnum) =~# '^>' && (lnum == 1 || getline(lnum - 1) !~# '^>')
          \ && lnum < last && getline(lnum + 1) =~# '^>'
          \ && foldclosed(lnum) == -1
      execute lnum . 'foldclose'
    endif
    let lnum += 1
  endwhile
  call setpos('.', save_pos)
endfunction

" Toggle all code-block and quote-block folds.
" If any block fold is closed, open all; otherwise close all.
function! markdownfold#toggle_blocks() abort
  call s:ensure_cache()
  let any_closed = 0
  for lnum in keys(b:_mkfold_fence)
    if b:_mkfold_fence[lnum] ==# 'open' && foldclosed(lnum) == +lnum
      let any_closed = 1
      break
    endif
  endfor
  if !any_closed
    let last = line('$')
    let lnum = 1
    while lnum <= last
      if getline(lnum) =~# '^>' && (lnum == 1 || getline(lnum - 1) !~# '^>')
            \ && lnum < last && getline(lnum + 1) =~# '^>'
            \ && foldclosed(lnum) == lnum
        let any_closed = 1
        break
      endif
      let lnum += 1
    endwhile
  endif
  if any_closed
    call markdownfold#open_blocks()
  else
    call markdownfold#close_blocks()
  endif
endfunction

" Open all code-block and quote-block folds (leave header folds alone).
function! markdownfold#open_blocks() abort
  call s:ensure_cache()
  let save_pos = getpos('.')
  for lnum in keys(b:_mkfold_fence)
    if b:_mkfold_fence[lnum] ==# 'open' && foldclosed(lnum) == +lnum
      execute lnum . 'foldopen'
    endif
  endfor
  let last = line('$')
  let lnum = 1
  while lnum <= last
    if getline(lnum) =~# '^>' && (lnum == 1 || getline(lnum - 1) !~# '^>')
          \ && lnum < last && getline(lnum + 1) =~# '^>'
          \ && foldclosed(lnum) == lnum
      execute lnum . 'foldopen'
    endif
    let lnum += 1
  endwhile
  call setpos('.', save_pos)
endfunction
