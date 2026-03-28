" ftplugin/markdown.vim - Markdown filetype plugin
"
" Provides fenced code block syntax highlighting, header navigation,
" URL opening, and table-of-contents commands.
"
" Compatible with preservim/vim-markdown config variables and Plug mappings.

scriptencoding utf-8

" ============================================================================
" Fenced code block syntax highlighting
" ============================================================================
" Scans the buffer for ```lang ... ``` blocks, then dynamically includes
" the syntax file for each language found. This gives you highlighted
" code inside fenced blocks.

if exists('g:vim_markdown_fenced_languages')
    let s:filetype_dict = {}
    for s:filetype in g:vim_markdown_fenced_languages
        let key = matchstr(s:filetype, '[^=]*')
        let val = matchstr(s:filetype, '[^=]*$')
        let s:filetype_dict[key] = val
    endfor
else
    let s:filetype_dict = {
        \ 'c++': 'cpp',
        \ 'viml': 'vim',
        \ 'bash': 'sh',
        \ 'ini': 'dosini',
        \ 'hack': 'php'
    \ }
endif

function! s:SyntaxInclude(filetype)
    let grouplistname = '@' . toupper(a:filetype)
    if exists('b:current_syntax')
        let syntax_save = b:current_syntax
        unlet b:current_syntax
    endif
    try
        execute 'syntax include' grouplistname 'syntax/' . a:filetype . '.vim'
        execute 'syntax include' grouplistname 'after/syntax/' . a:filetype . '.vim'
    catch /E484/
        " Ignore missing syntax scripts
    endtry
    if exists('syntax_save')
        let b:current_syntax = syntax_save
    elseif exists('b:current_syntax')
        unlet b:current_syntax
    endif
    return grouplistname
endfunction

function! s:MarkdownHighlightSources(force)
    let filetypes = {}
    for line in getline(1, '$')
        let ft = matchstr(line, '\(`\{3,}\|\~\{3,}\)\s*\zs[0-9A-Za-z_+-]*\ze.*')
        if !empty(ft) && ft !~# '^\d*$' | let filetypes[ft] = 1 | endif
    endfor
    if !exists('b:mkd_known_filetypes')
        let b:mkd_known_filetypes = {}
    endif
    if !exists('b:mkd_included_filetypes')
        let b:mkd_included_filetypes = {}
    endif
    if !a:force && (b:mkd_known_filetypes == filetypes || empty(filetypes))
        return
    endif

    let startgroup = 'mkdCodeStart'
    let endgroup = 'mkdCodeEnd'
    for ft in keys(filetypes)
        if a:force || !has_key(b:mkd_known_filetypes, ft)
            if has_key(s:filetype_dict, ft)
                let filetype = s:filetype_dict[ft]
            else
                let filetype = ft
            endif
            let group = 'mkdSnippet' . toupper(substitute(filetype, '[+-]', '_', 'g'))
            if !has_key(b:mkd_included_filetypes, filetype)
                let include = s:SyntaxInclude(filetype)
                let b:mkd_included_filetypes[filetype] = 1
            else
                let include = '@' . toupper(filetype)
            endif
            " PHP's syntax items live inside phpRegion which requires <?php;
            " use @phpClTop to highlight directly (needed for hack blocks)
            if filetype ==# 'php'
                let include = '@phpClTop'
            endif
            let command_backtick = 'syntax region %s matchgroup=%s start="^\s*`\{3,}\s*%s.*$" matchgroup=%s end="\s*`\{3,}$" keepend contains=%s%s'
            let command_tilde    = 'syntax region %s matchgroup=%s start="^\s*\~\{3,}\s*%s.*$" matchgroup=%s end="\s*\~\{3,}$" keepend contains=%s%s'
            execute printf(command_backtick, group, startgroup, ft, endgroup, include, has('conceal') && get(g:, 'vim_markdown_conceal', 1) && get(g:, 'vim_markdown_conceal_code_blocks', 1) ? ' concealends' : '')
            execute printf(command_tilde,    group, startgroup, ft, endgroup, include, has('conceal') && get(g:, 'vim_markdown_conceal', 1) && get(g:, 'vim_markdown_conceal_code_blocks', 1) ? ' concealends' : '')
            execute printf('syntax cluster mkdNonListItem add=%s', group)

            let b:mkd_known_filetypes[ft] = 1
        endif
    endfor
endfunction

" Re-apply the sync setting after including fenced language syntax files,
" because `syntax include` can alter sync state.
function! s:ApplySync()
    let l:sync_minlines = get(g:, 'vim_markdown_sync_minlines', 0)
    if l:sync_minlines > 0
        execute 'syntax sync minlines=' . l:sync_minlines
    else
        syntax sync fromstart
    endif
endfunction

function! s:IsHighlightSourcesEnabledForBuffer()
    return &filetype =~# 'markdown' || get(b:, 'liquid_subtype', '') =~# 'markdown'
endfunction

function! s:MarkdownRefreshSyntax(force)
    " vint: next-line -ProhibitEqualTildeOperator
    if s:IsHighlightSourcesEnabledForBuffer() && line('$') > 1 && &syntax != 'OFF'
        call s:MarkdownHighlightSources(a:force)
        call s:ApplySync()
    endif
endfunction

function! s:MarkdownClearSyntaxVariables()
    if s:IsHighlightSourcesEnabledForBuffer()
        unlet! b:mkd_included_filetypes
    endif
endfunction

augroup MkdHighlight
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> call s:MarkdownRefreshSyntax(1)
    autocmd BufUnload <buffer> call s:MarkdownClearSyntaxVariables()
    autocmd BufWritePost <buffer> call s:MarkdownRefreshSyntax(0)
    autocmd InsertEnter,InsertLeave <buffer> call s:MarkdownRefreshSyntax(0)
    autocmd CursorHold,CursorHoldI <buffer> call s:MarkdownRefreshSyntax(0)
augroup END

" ============================================================================
" Header navigation
" ============================================================================

let s:levelRegexpDict = {
    \ 1: '\v^(#[^#]@=|.+\n\=+$)',
    \ 2: '\v^(##[^#]@=|.+\n-+$)',
    \ 3: '\v^###[^#]@=',
    \ 4: '\v^####[^#]@=',
    \ 5: '\v^#####[^#]@=',
    \ 6: '\v^######[^#]@='
\ }

let s:headersRegexp = '\v^(#|.+\n(\=+|-+)$)'

function! s:is_mkdCode(lnum)
    let name = synIDattr(synID(a:lnum, 1, 0), 'name')
    return (name =~# '^mkd\%(Code$\|Snippet\)' || name !=# '' && name !~? '^\%(mkd\|html\)')
endfunction

function! s:GetHeaderLineNum(...)
    if a:0 == 0
        let l:l = line('.')
    else
        let l:l = a:1
    endif
    while(l:l > 0)
        if join(getline(l:l, l:l + 1), "\n") =~ s:headersRegexp
            return l:l
        endif
        let l:l -= 1
    endwhile
    return 0
endfunction

function! s:MoveToCurHeader()
    let l:lineNum = s:GetHeaderLineNum()
    if l:lineNum !=# 0
        call cursor(l:lineNum, 1)
    else
        echo 'outside any header'
    endif
    return l:lineNum
endfunction

function! s:MoveToNextHeader()
    if search(s:headersRegexp, 'W') == 0
        echo 'no next header'
    endif
endfunction

function! s:MoveToPreviousHeader()
    let l:curHeaderLineNumber = s:GetHeaderLineNum()
    let l:noPreviousHeader = 0
    if l:curHeaderLineNumber <= 1
        let l:noPreviousHeader = 1
    else
        let l:previousHeaderLineNumber = s:GetHeaderLineNum(l:curHeaderLineNumber - 1)
        if l:previousHeaderLineNumber == 0
            let l:noPreviousHeader = 1
        else
            call cursor(l:previousHeaderLineNumber, 1)
        endif
    endif
    if l:noPreviousHeader
        echo 'no previous header'
    endif
endfunction

function! s:GetLevelOfHeaderAtLine(linenum)
    let l:lines = join(getline(a:linenum, a:linenum + 1), "\n")
    for l:key in keys(s:levelRegexpDict)
        if l:lines =~ get(s:levelRegexpDict, l:key)
            return l:key
        endif
    endfor
    return 0
endfunction

function! s:GetHeaderLevel(...)
    if a:0 == 0
        let l:line = line('.')
    else
        let l:line = a:1
    endif
    let l:linenum = s:GetHeaderLineNum(l:line)
    if l:linenum !=# 0
        return s:GetLevelOfHeaderAtLine(l:linenum)
    else
        return 0
    endif
endfunction

function! s:GetNextHeaderLineNumberAtLevel(level, ...)
    if a:0 < 1
        let l:line = line('.')
    else
        let l:line = a:1
    endif
    let l:l = l:line
    while(l:l <= line('$'))
        if join(getline(l:l, l:l + 1), "\n") =~ get(s:levelRegexpDict, a:level)
            return l:l
        endif
        let l:l += 1
    endwhile
    return 0
endfunction

function! s:GetPreviousHeaderLineNumberAtLevel(level, ...)
    if a:0 == 0
        let l:line = line('.')
    else
        let l:line = a:1
    endif
    let l:l = l:line
    while(l:l > 0)
        if join(getline(l:l, l:l + 1), "\n") =~ get(s:levelRegexpDict, a:level)
            return l:l
        endif
        let l:l -= 1
    endwhile
    return 0
endfunction

function! s:GetParentHeaderLineNumber(...)
    if a:0 == 0
        let l:line = line('.')
    else
        let l:line = a:1
    endif
    let l:level = s:GetHeaderLevel(l:line)
    if l:level > 1
        let l:linenum = s:GetPreviousHeaderLineNumberAtLevel(l:level - 1, l:line)
        return l:linenum
    endif
    return 0
endfunction

function! s:MoveToParentHeader()
    let l:linenum = s:GetParentHeaderLineNumber()
    if l:linenum != 0
        call setpos("''", getpos('.'))
        call cursor(l:linenum, 1)
    else
        echo 'no parent header'
    endif
endfunction

function! s:MoveToNextSiblingHeader()
    let l:curHeaderLineNumber = s:GetHeaderLineNum()
    let l:curHeaderLevel = s:GetLevelOfHeaderAtLine(l:curHeaderLineNumber)
    let l:curHeaderParentLineNumber = s:GetParentHeaderLineNumber()
    let l:nextHeaderSameLevelLineNumber = s:GetNextHeaderLineNumberAtLevel(l:curHeaderLevel, l:curHeaderLineNumber + 1)
    let l:noNextSibling = 0
    if l:nextHeaderSameLevelLineNumber == 0
        let l:noNextSibling = 1
    else
        let l:nextHeaderSameLevelParentLineNumber = s:GetParentHeaderLineNumber(l:nextHeaderSameLevelLineNumber)
        if l:curHeaderParentLineNumber == l:nextHeaderSameLevelParentLineNumber
            call cursor(l:nextHeaderSameLevelLineNumber, 1)
        else
            let l:noNextSibling = 1
        endif
    endif
    if l:noNextSibling
        echo 'no next sibling header'
    endif
endfunction

function! s:MoveToPreviousSiblingHeader()
    let l:curHeaderLineNumber = s:GetHeaderLineNum()
    let l:curHeaderLevel = s:GetLevelOfHeaderAtLine(l:curHeaderLineNumber)
    let l:curHeaderParentLineNumber = s:GetParentHeaderLineNumber()
    let l:previousHeaderSameLevelLineNumber = s:GetPreviousHeaderLineNumberAtLevel(l:curHeaderLevel, l:curHeaderLineNumber - 1)
    let l:noPreviousSibling = 0
    if l:previousHeaderSameLevelLineNumber == 0
        let l:noPreviousSibling = 1
    else
        let l:previousHeaderSameLevelParentLineNumber = s:GetParentHeaderLineNumber(l:previousHeaderSameLevelLineNumber)
        if l:curHeaderParentLineNumber == l:previousHeaderSameLevelParentLineNumber
            call cursor(l:previousHeaderSameLevelLineNumber, 1)
        else
            let l:noPreviousSibling = 1
        endif
    endif
    if l:noPreviousSibling
        echo 'no previous sibling header'
    endif
endfunction

" ============================================================================
" Table of contents
" ============================================================================

function! s:GetHeaderList()
    let l:bufnr = bufnr('%')
    let l:fenced_block = 0
    let l:front_matter = 0
    let l:header_list = []
    let l:vim_markdown_frontmatter = get(g:, 'vim_markdown_frontmatter', 0)
    let l:fence_str = ''
    for i in range(1, line('$'))
        let l:lineraw = getline(i)
        let l:l1 = getline(i+1)
        let l:line = substitute(l:lineraw, '#', "\\\#", 'g')
        if l:line =~# '\v^[[:space:]>]*(`{3,}|\~{3,})\s*(\w+)?\s*$'
            if l:fenced_block == 0
                let l:fenced_block = 1
                let l:fence_str = matchstr(l:line, '\v(`{3,}|\~{3,})')
            elseif l:fenced_block == 1 && matchstr(l:line, '\v(`{3,}|\~{3,})') ==# l:fence_str
                let l:fenced_block = 0
                let l:fence_str = ''
            endif
        elseif l:vim_markdown_frontmatter == 1
            if l:front_matter == 1
                if l:line ==# '---'
                    let l:front_matter = 0
                endif
            elseif i == 1
                if l:line ==# '---'
                    let l:front_matter = 1
                endif
            endif
        endif
        if join(getline(i, i + 1), "\n") =~# s:headersRegexp && l:line =~# '^\S'
            let l:is_header = 1
        else
            let l:is_header = 0
        endif
        if l:is_header ==# 1 && l:fenced_block ==# 0 && l:front_matter ==# 0
            if match(l:line, '^#') > -1
                let l:line = substitute(l:line, '\v^#*[ ]*', '', '')
                let l:line = substitute(l:line, '\v[ ]*#*$', '', '')
            endif
            let l:level = s:GetHeaderLevel(i)
            let l:item = {'level': l:level, 'text': l:line, 'lnum': i, 'bufnr': bufnr}
            let l:header_list = l:header_list + [l:item]
        endif
    endfor
    return l:header_list
endfunction

function! s:Toc(...)
    if a:0 > 0
        let l:window_type = a:1
    else
        let l:window_type = 'vertical'
    endif

    let l:cursor_line = line('.')
    let l:cursor_header = 0
    let l:header_list = s:GetHeaderList()
    let l:indented_header_list = []
    if len(l:header_list) == 0
        echomsg 'Toc: No headers.'
        return
    endif
    let l:header_max_len = 0
    let l:vim_markdown_toc_autofit = get(g:, 'vim_markdown_toc_autofit', 0)
    for h in l:header_list
        if l:cursor_header == 0
            let l:header_line = h.lnum
            if l:header_line == l:cursor_line
                let l:cursor_header = index(l:header_list, h) + 1
            elseif l:header_line > l:cursor_line
                let l:cursor_header = index(l:header_list, h)
            endif
        endif
        let l:text = repeat('  ', h.level-1) . h.text
        let l:total_len = strdisplaywidth(l:text)
        if l:total_len > l:header_max_len
            let l:header_max_len = l:total_len
        endif
        let l:item = {'lnum': h.lnum, 'text': l:text, 'valid': 1, 'bufnr': h.bufnr, 'col': 1}
        let l:indented_header_list = l:indented_header_list + [l:item]
    endfor
    call setloclist(0, l:indented_header_list)

    if l:window_type ==# 'horizontal'
        lopen
    elseif l:window_type ==# 'vertical'
        vertical lopen
        if (&columns/2) > l:header_max_len && l:vim_markdown_toc_autofit == 1
            execute 'vertical resize ' . (l:header_max_len + 1 + 3)
        else
            execute 'vertical resize ' . (&columns/2)
        endif
    elseif l:window_type ==# 'tab'
        tab lopen
    else
        lopen
    endif
    setlocal modifiable
    for i in range(1, line('$'))
        let d = getloclist(0)[i-1]
        call setline(i, d.text)
    endfor
    setlocal nomodified
    setlocal nomodifiable
    execute 'normal! ' . l:cursor_header . 'G'
endfunction

" ============================================================================
" URL handling
" ============================================================================

function! s:FindCornerOfSyntax(lnum, col, step)
    let l:col = a:col
    let l:syn = synIDattr(synID(a:lnum, l:col, 1), 'name')
    while synIDattr(synID(a:lnum, l:col, 1), 'name') ==# l:syn
        let l:col += a:step
    endwhile
    return l:col - a:step
endfunction

function! s:FindNextSyntax(lnum, col, name)
    let l:col = a:col
    while synIDattr(synID(a:lnum, l:col, 1), 'name') !=# a:name
        let l:col += 1
    endwhile
    return [a:lnum, l:col]
endfunction

function! s:FindCornersOfSyntax(lnum, col)
    return [<sid>FindCornerOfSyntax(a:lnum, a:col, -1), <sid>FindCornerOfSyntax(a:lnum, a:col, 1)]
endfunction

function! s:Markdown_GetUrlForPosition(lnum, col)
    let l:lnum = a:lnum
    let l:col = a:col
    let l:syn = synIDattr(synID(l:lnum, l:col, 1), 'name')

    if l:syn ==# 'mkdInlineURL' || l:syn ==# 'mkdURL' || l:syn ==# 'mkdLinkDefTarget'
        " Already on the URL
    elseif l:syn ==# 'mkdLink'
        let [l:lnum, l:col] = <sid>FindNextSyntax(l:lnum, l:col, 'mkdURL')
        let l:syn = 'mkdURL'
    elseif l:syn ==# 'mkdDelimiter'
        let l:line = getline(l:lnum)
        let l:char = l:line[col - 1]
        if l:char ==# '<'
            let l:col += 1
        elseif l:char ==# '>' || l:char ==# ')'
            let l:col -= 1
        elseif l:char ==# '[' || l:char ==# ']' || l:char ==# '('
            let [l:lnum, l:col] = <sid>FindNextSyntax(l:lnum, l:col, 'mkdURL')
        else
            return ''
        endif
    else
        return ''
    endif

    let [l:left, l:right] = <sid>FindCornersOfSyntax(l:lnum, l:col)
    return getline(l:lnum)[l:left - 1 : l:right - 1]
endfunction

function! s:VersionAwareNetrwBrowseX(url)
    if has('patch-9.1.1588')
        call netrw#BrowseX(a:url)
    elseif has('patch-7.4.567')
        call netrw#BrowseX(a:url, 0)
    else
        call netrw#NetrwBrowseX(a:url, 0)
    endif
endfunction

function! s:OpenUrlUnderCursor()
    let l:url = s:Markdown_GetUrlForPosition(line('.'), col('.'))
    if l:url !=# ''
      if l:url =~? 'http[s]\?:\/\/[[:alnum:]%\/_#.-]*'
        " external URL — open in browser
      else
        let l:url = expand(expand('%:h').'/'.l:url)
      endif
      call s:VersionAwareNetrwBrowseX(l:url)
    else
        echomsg 'The cursor is not on a link.'
    endif
endfunction

if !exists('*s:EditUrlUnderCursor')
    function s:EditUrlUnderCursor()
        let l:editmethod = ''
        if exists('g:vim_markdown_edit_url_in')
          if g:vim_markdown_edit_url_in ==# 'tab'
            let l:editmethod = 'tabnew'
          elseif g:vim_markdown_edit_url_in ==# 'vsplit'
            let l:editmethod = 'vsp'
          elseif g:vim_markdown_edit_url_in ==# 'hsplit'
            let l:editmethod = 'sp'
          else
            let l:editmethod = 'edit'
          endif
        else
          let l:editmethod = 'edit'
        endif
        let l:url = s:Markdown_GetUrlForPosition(line('.'), col('.'))
        if l:url !=# ''
            if get(g:, 'vim_markdown_autowrite', 0)
                write
            endif
            let l:anchor = ''
            if get(g:, 'vim_markdown_follow_anchor', 0)
                let l:parts = split(l:url, '#', 1)
                if len(l:parts) == 2
                    let [l:url, l:anchor] = parts
                    let l:anchorexpr = get(g:, 'vim_markdown_anchorexpr', '')
                    if l:anchorexpr !=# ''
                        let l:anchor = eval(substitute(
                            \ l:anchorexpr, 'v:anchor',
                            \ escape('"'.l:anchor.'"', '"'), ''))
                    endif
                endif
            endif
            if l:url !=# ''
                let l:ext = ''
                if get(g:, 'vim_markdown_no_extensions_in_markdown', 0)
                    if exists('g:vim_markdown_auto_extension_ext')
                        let l:ext = '.'.g:vim_markdown_auto_extension_ext
                    else
                        let l:ext = '.md'
                    endif
                endif
                let l:url = fnameescape(fnamemodify(expand('%:h').'/'.l:url.l:ext, ':.'))
                execute l:editmethod l:url
            endif
            if l:anchor !=# ''
                call search(l:anchor, 's')
            endif
        else
            execute l:editmethod . ' <cfile>'
        endif
    endfunction
endif

" ============================================================================
" Header increase/decrease and format conversion
" ============================================================================

function! s:SetexToAtx(line1, line2)
    let l:originalNumLines = line('$')
    execute 'silent! ' . a:line1 . ',' . a:line2 . 'substitute/\v(.*\S.*)\n\=+$/# \1/'
    let l:changed = l:originalNumLines - line('$')
    execute 'silent! ' . a:line1 . ',' . (a:line2 - l:changed) . 'substitute/\v(.*\S.*)\n-+$/## \1'
    return l:originalNumLines - line('$')
endfunction

function! s:HeaderDecrease(line1, line2, ...)
    if a:0 > 0
        let l:increase = a:1
    else
        let l:increase = 0
    endif
    if l:increase
        let l:forbiddenLevel = 6
        let l:replaceLevels = [5, 1]
        let l:levelDelta = 1
    else
        let l:forbiddenLevel = 1
        let l:replaceLevels = [2, 6]
        let l:levelDelta = -1
    endif
    for l:line in range(a:line1, a:line2)
        if join(getline(l:line, l:line + 1), "\n") =~ s:levelRegexpDict[l:forbiddenLevel]
            echomsg 'There is an h' . l:forbiddenLevel . ' at line ' . l:line . '. Aborting.'
            return
        endif
    endfor
    let l:numSubstitutions = s:SetexToAtx(a:line1, a:line2)
    let l:flags = (&gdefault ? '' : 'g')
    for l:level in range(replaceLevels[0], replaceLevels[1], -l:levelDelta)
        execute 'silent! ' . a:line1 . ',' . (a:line2 - l:numSubstitutions) . 'substitute/' . s:levelRegexpDict[l:level] . '/' . repeat('#', l:level + l:levelDelta) . '/' . l:flags
    endfor
endfunction

" ============================================================================
" Table formatting (requires Tabularize plugin)
" ============================================================================

function! s:TableFormat()
    let l:pos = getpos('.')
    if get(g:, 'vim_markdown_borderless_table', 0)
      normal! {
      call search('|')
      execute 'silent .,''}s/\v^(\s{0,})\|?([^\|])/\1|\2/e'
      normal! {
      call search('|')
      execute 'silent .,''}s/\v([^\|])\|?(\s{0,})$/\1|\2/e'
    endif
    normal! {
    call search('|')
    normal! j
    let l:flags = (&gdefault ? '' : 'g')
    execute 's/\(:\@<!-:\@!\|[^|:-]\)//e' . l:flags
    execute 's/--/-/e' . l:flags
    Tabularize /\(\\\)\@<!|
    execute 's/:\( \+\)|/\1:|/e' . l:flags
    execute 's/|\( \+\):/|:\1/e' . l:flags
    execute 's/|:\?\zs[ -]\+\ze:\?|/\=repeat("-", len(submatch(0)))/' . l:flags
    call setpos('.', l:pos)
endfunction

" ============================================================================
" Insert table of contents
" ============================================================================

function! s:InsertToc(format, ...)
    if a:0 > 0
        if type(a:1) != type(0)
            echohl WarningMsg
            echomsg '[vim-markdown] Invalid argument, must be an integer >= 2.'
            echohl None
            return
        endif
        let l:max_level = a:1
        if l:max_level < 2
            echohl WarningMsg
            echomsg '[vim-markdown] Maximum level cannot be smaller than 2.'
            echohl None
            return
        endif
    else
        let l:max_level = 0
    endif

    let l:toc = []
    let l:header_list = s:GetHeaderList()
    if len(l:header_list) == 0
        echomsg 'InsertToc: No headers.'
        return
    endif

    if a:format ==# 'numbers'
        let l:h2_count = 0
        for header in l:header_list
            if header.level == 2
                let l:h2_count += 1
            endif
        endfor
        let l:max_h2_number_len = strlen(string(l:h2_count))
    else
        let l:max_h2_number_len = 0
    endif

    let l:h2_count = 0
    for header in l:header_list
        let l:level = header.level
        if l:level == 1
            continue
        elseif l:max_level != 0 && l:level > l:max_level
            continue
        elseif l:level == 2
            if a:format ==# 'bullets'
                let l:indent = ''
                let l:marker = '* '
            else
                let l:h2_count += 1
                let l:number_len = strlen(string(l:h2_count))
                let l:indent = repeat(' ', l:max_h2_number_len - l:number_len)
                let l:marker = l:h2_count . '. '
            endif
        else
            let l:indent = repeat(' ', l:max_h2_number_len + 2 * (l:level - 2))
            let l:marker = '* '
        endif
        let l:text = '[' . header.text . ']'
        let l:link = '(#' . substitute(tolower(header.text), '\v[ ]+', '-', 'g') . ')'
        let l:line = l:indent . l:marker . l:text . l:link
        let l:toc = l:toc + [l:line]
    endfor

    call append(line('.'), l:toc)
endfunction

" ============================================================================
" Mappings
" ============================================================================

function! s:VisMove(f)
    normal! gv
    call function(a:f)()
endfunction

function! s:MapNormVis(rhs, lhs)
    execute 'nnoremap <buffer><silent> ' . a:rhs . ' :call ' . a:lhs . '()<cr>'
    execute 'vnoremap <buffer><silent> ' . a:rhs . ' <esc>:call <sid>VisMove(''' . a:lhs . ''')<cr>'
endfunction

function! s:MapNotHasmapto(lhs, rhs)
    if !hasmapto('<Plug>' . a:rhs)
        execute 'nmap <buffer>' . a:lhs . ' <Plug>' . a:rhs
        execute 'vmap <buffer>' . a:lhs . ' <Plug>' . a:rhs
    endif
endfunction

call <sid>MapNormVis('<Plug>Markdown_MoveToNextHeader', '<sid>MoveToNextHeader')
call <sid>MapNormVis('<Plug>Markdown_MoveToPreviousHeader', '<sid>MoveToPreviousHeader')
call <sid>MapNormVis('<Plug>Markdown_MoveToNextSiblingHeader', '<sid>MoveToNextSiblingHeader')
call <sid>MapNormVis('<Plug>Markdown_MoveToPreviousSiblingHeader', '<sid>MoveToPreviousSiblingHeader')
call <sid>MapNormVis('<Plug>Markdown_MoveToParentHeader', '<sid>MoveToParentHeader')
call <sid>MapNormVis('<Plug>Markdown_MoveToCurHeader', '<sid>MoveToCurHeader')
nnoremap <Plug>Markdown_OpenUrlUnderCursor :call <sid>OpenUrlUnderCursor()<cr>
nnoremap <Plug>Markdown_EditUrlUnderCursor :call <sid>EditUrlUnderCursor()<cr>

if !get(g:, 'vim_markdown_no_default_key_mappings', 0)
    call <sid>MapNotHasmapto(']]', 'Markdown_MoveToNextHeader')
    call <sid>MapNotHasmapto('[[', 'Markdown_MoveToPreviousHeader')
    call <sid>MapNotHasmapto('][', 'Markdown_MoveToNextSiblingHeader')
    call <sid>MapNotHasmapto('[]', 'Markdown_MoveToPreviousSiblingHeader')
    call <sid>MapNotHasmapto(']u', 'Markdown_MoveToParentHeader')
    call <sid>MapNotHasmapto(']h', 'Markdown_MoveToCurHeader')
    call <sid>MapNotHasmapto('gx', 'Markdown_OpenUrlUnderCursor')
    call <sid>MapNotHasmapto('ge', 'Markdown_EditUrlUnderCursor')
endif

" ============================================================================
" Commands
" ============================================================================

command! -buffer -range=% HeaderDecrease call s:HeaderDecrease(<line1>, <line2>)
command! -buffer -range=% HeaderIncrease call s:HeaderDecrease(<line1>, <line2>, 1)
command! -buffer -range=% SetexToAtx call s:SetexToAtx(<line1>, <line2>)
command! -buffer -range TableFormat call s:TableFormat()
command! -buffer Toc call s:Toc()
command! -buffer Toch call s:Toc('horizontal')
command! -buffer Tocv call s:Toc('vertical')
command! -buffer Toct call s:Toc('tab')
command! -buffer -nargs=? InsertToc call s:InsertToc('bullets', <args>)
command! -buffer -nargs=? InsertNToc call s:InsertToc('numbers', <args>)

" ============================================================================
" Code block background highlighting
" ============================================================================
" Uses signs with linehl so it works with syntax highlighting and any conceallevel.
" Customize the background color by setting the CodeBlockBg highlight group
" in your vimrc before this plugin loads, e.g.:
"   highlight CodeBlockBg ctermbg=234 guibg=#141414
"
" Color palette (uncomment one to use):
"highlight CodeBlockBg ctermbg=234 guibg=#141414   " neutral gray
"highlight CodeBlockBg ctermbg=58 guibg=#12120a    " olive
"highlight CodeBlockBg ctermbg=58 guibg=#16160c    " olive, less subtle
"highlight CodeBlockBg ctermbg=17 guibg=#0a0a1a    " navy blue
"highlight CodeBlockBg ctermbg=17 guibg=#0e0e24    " navy blue, less subtle
"highlight CodeBlockBg ctermbg=52 guibg=#1a0a0a    " dark red
"highlight CodeBlockBg ctermbg=52 guibg=#1e0e0e    " dark red, less subtle
"highlight CodeBlockBg ctermbg=22 guibg=#0a1a0a    " dark green
"highlight CodeBlockBg ctermbg=22 guibg=#0e1e0e    " dark green, less subtle
"highlight CodeBlockBg ctermbg=23 guibg=#0a1414    " teal
"highlight CodeBlockBg ctermbg=23 guibg=#0e1a1a    " teal, less subtle
"highlight CodeBlockBg ctermbg=53 guibg=#140a14    " purple
"highlight CodeBlockBg ctermbg=53 guibg=#1a0e1a    " purple, less subtle
"highlight CodeBlockBg ctermbg=235 guibg=#1a1a1a   " neutral gray, less subtle
"highlight CodeBlockBg ctermbg=94 guibg=#18100a    " warm brown
"highlight CodeBlockBg ctermbg=94 guibg=#1e140e    " warm brown, less subtle

if !exists('g:mkd_codeblock_bg_defined')
    let g:mkd_codeblock_bg_defined = 1
    if synIDattr(synIDtrans(hlID('CodeBlockBg')), 'bg') ==# ''
        highlight CodeBlockBg ctermbg=234 guibg=#0d0d0d
    endif
    sign define codeblock linehl=CodeBlockBg
endif

function! s:HighlightCodeBlocks()
    if &filetype !=# 'markdown' | return | endif
    call sign_unplace('codeblock', {'buffer': bufnr('%')})
    let l:in_block = 0
    for l:lnum in range(1, line('$'))
        let l:line = getline(l:lnum)
        if l:line =~# '^\s*```\|^\s*\~\~\~'
            call sign_place(0, 'codeblock', 'codeblock', bufnr('%'), {'lnum': l:lnum})
            let l:in_block = !l:in_block
        elseif l:in_block
            call sign_place(0, 'codeblock', 'codeblock', bufnr('%'), {'lnum': l:lnum})
        endif
    endfor
endfunction

augroup MkdCodeBlockBg
    autocmd! * <buffer>
    autocmd BufEnter,BufWritePost <buffer> call s:HighlightCodeBlocks()
    autocmd TextChanged <buffer> call s:HighlightCodeBlocks()
augroup END

call s:HighlightCodeBlocks()

" ============================================================================
" Header background highlighting
" ============================================================================
" Uses signs with linehl so it works with syntax highlighting and any conceallevel.
" Customize the base header background color by setting the MarkdownHeaderBg
" highlight group in your vimrc before this plugin loads.
" H1 gets the full color; each subsequent level dims toward black.
"
" Color palette (uncomment one to use):
"
" -- Blues (complementary to yellow) --
"highlight MarkdownHeaderBg ctermbg=17 guibg=#0a0a1a   " navy blue, subtle
"highlight MarkdownHeaderBg ctermbg=17 guibg=#0e0e24   " navy blue
"highlight MarkdownHeaderBg ctermbg=17 guibg=#121230   " navy blue, bold
"highlight MarkdownHeaderBg ctermbg=18 guibg=#0a0e20   " royal blue, subtle
"highlight MarkdownHeaderBg ctermbg=18 guibg=#0e1230   " royal blue
"highlight MarkdownHeaderBg ctermbg=18 guibg=#141840   " royal blue, bold
"highlight MarkdownHeaderBg ctermbg=24 guibg=#0a1420   " steel blue, subtle
"highlight MarkdownHeaderBg ctermbg=24 guibg=#0e1a2a   " steel blue
"highlight MarkdownHeaderBg ctermbg=24 guibg=#142036   " steel blue, bold
"
" -- Purples / Violets --
"highlight MarkdownHeaderBg ctermbg=53 guibg=#120a18   " purple, subtle
"highlight MarkdownHeaderBg ctermbg=53 guibg=#180e22   " purple
"highlight MarkdownHeaderBg ctermbg=53 guibg=#1e142e   " purple, bold
"highlight MarkdownHeaderBg ctermbg=54 guibg=#160a20   " magenta-purple, subtle
"highlight MarkdownHeaderBg ctermbg=54 guibg=#1c0e2a   " magenta-purple
"highlight MarkdownHeaderBg ctermbg=54 guibg=#221436   " magenta-purple, bold
"highlight MarkdownHeaderBg ctermbg=60 guibg=#14102a   " slate violet, subtle
"highlight MarkdownHeaderBg ctermbg=60 guibg=#1a1436   " slate violet
"highlight MarkdownHeaderBg ctermbg=60 guibg=#201a42   " slate violet, bold
"
" -- Teals / Cyans (triadic to yellow) --
"highlight MarkdownHeaderBg ctermbg=23 guibg=#0a1414   " teal, subtle
"highlight MarkdownHeaderBg ctermbg=23 guibg=#0e1a1a   " teal
"highlight MarkdownHeaderBg ctermbg=23 guibg=#142222   " teal, bold
"highlight MarkdownHeaderBg ctermbg=30 guibg=#0a1618   " cyan-teal, subtle
"highlight MarkdownHeaderBg ctermbg=30 guibg=#0e1c20   " cyan-teal
"highlight MarkdownHeaderBg ctermbg=30 guibg=#14242a   " cyan-teal, bold
"
" -- Blue-greens --
"highlight MarkdownHeaderBg ctermbg=29 guibg=#0a1816   " blue-green, subtle
"highlight MarkdownHeaderBg ctermbg=29 guibg=#0e1e1c   " blue-green
"highlight MarkdownHeaderBg ctermbg=29 guibg=#142624   " blue-green, bold
"
" -- Indigos --
"highlight MarkdownHeaderBg ctermbg=19 guibg=#0e0a20   " indigo, subtle
"highlight MarkdownHeaderBg ctermbg=19 guibg=#140e2c   " indigo
"highlight MarkdownHeaderBg ctermbg=19 guibg=#1a1438   " indigo, bold
"
" -- Cool grays --
"highlight MarkdownHeaderBg ctermbg=234 guibg=#101014   " cool gray, subtle
"highlight MarkdownHeaderBg ctermbg=234 guibg=#16161c   " cool gray
"highlight MarkdownHeaderBg ctermbg=235 guibg=#1c1c24   " cool gray, bold
"
" -- Neutral grays --
"highlight MarkdownHeaderBg ctermbg=234 guibg=#0d0d0d   " neutral gray, subtle
"highlight MarkdownHeaderBg ctermbg=234 guibg=#141414   " neutral gray
"highlight MarkdownHeaderBg ctermbg=235 guibg=#1a1a1a   " neutral gray, bold
"
" -- Olives --
"highlight MarkdownHeaderBg ctermbg=58 guibg=#12120a    " olive, subtle
"highlight MarkdownHeaderBg ctermbg=58 guibg=#16160c    " olive
"highlight MarkdownHeaderBg ctermbg=58 guibg=#1c1c10    " olive, bold
"
" -- Dark reds --
"highlight MarkdownHeaderBg ctermbg=52 guibg=#1a0a0a    " dark red, subtle
"highlight MarkdownHeaderBg ctermbg=52 guibg=#1e0e0e    " dark red
"highlight MarkdownHeaderBg ctermbg=52 guibg=#241414    " dark red, bold
"
" -- Dark greens --
"highlight MarkdownHeaderBg ctermbg=22 guibg=#0a1a0a    " dark green, subtle
"highlight MarkdownHeaderBg ctermbg=22 guibg=#0e1e0e    " dark green
"highlight MarkdownHeaderBg ctermbg=22 guibg=#142414    " dark green, bold
"
" -- Warm browns --
"highlight MarkdownHeaderBg ctermbg=94 guibg=#1e140e    " warm brown
"highlight MarkdownHeaderBg ctermbg=94 guibg=#241a14    " warm brown, bold

if !exists('g:mkd_header_bg_defined')
    let g:mkd_header_bg_defined = 1
    if synIDattr(synIDtrans(hlID('MarkdownHeaderBg')), 'bg') ==# ''
        highlight MarkdownHeaderBg ctermbg=94 guibg=#18100a
    endif
endif

function! s:HexToRGB(hex)
    let l:h = substitute(a:hex, '^#', '', '')
    return [str2nr(l:h[0:1], 16), str2nr(l:h[2:3], 16), str2nr(l:h[4:5], 16)]
endfunction

function! s:SetupHeaderLevels()
    let l:bg = synIDattr(synIDtrans(hlID('MarkdownHeaderBg')), 'bg#')
    if l:bg ==# '' | return | endif
    let [l:r, l:g, l:b] = s:HexToRGB(l:bg)
    " H1=100%, H2=82%, H3=67%, H4=55%, H5=45%, H6=37%
    let l:factors = [1.0, 0.82, 0.67, 0.55, 0.45, 0.37]
    for l:i in range(6)
        let l:f = l:factors[l:i]
        let l:color = printf('#%02x%02x%02x', float2nr(l:r * l:f), float2nr(l:g * l:f), float2nr(l:b * l:f))
        execute 'highlight MarkdownH' . (l:i+1) . 'Bg guibg=' . l:color
        execute 'sign define mdheader' . (l:i+1) . ' linehl=MarkdownH' . (l:i+1) . 'Bg'
    endfor
endfunction

function! s:HighlightHeaders()
    if &filetype !=# 'markdown' | return | endif
    for l:i in range(1, 6)
        call sign_unplace('mdheader' . l:i, {'buffer': bufnr('%')})
    endfor
    for l:lnum in range(1, line('$'))
        let l:line = getline(l:lnum)
        let l:match = matchstr(l:line, '^#\+')
        if l:match !=# ''
            let l:lvl = min([len(l:match), 6])
            call sign_place(0, 'mdheader' . l:lvl, 'mdheader' . l:lvl, bufnr('%'), {'lnum': l:lnum})
        endif
    endfor
endfunction

augroup MkdHeaderBg
    autocmd! * <buffer>
    autocmd BufEnter,BufWritePost <buffer> call s:SetupHeaderLevels() | call s:HighlightHeaders()
    autocmd TextChanged <buffer> call s:HighlightHeaders()
augroup END

call s:SetupHeaderLevels()
call s:HighlightHeaders()
