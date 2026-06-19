" ftplugin/markdown/folding.vim - Markdown folding setup
"
" Folding by header level, fenced code block, and quote block. The fold logic
" lives in autoload/markdownfold.vim and is driven entirely by 'foldexpr', so
" it works with :syntax off.
"
" Disable with `let g:vim_markdown_folding_disabled = 1` (same flag as
" preservim/vim-markdown). Note: 'foldmethod=expr' can be costly on very large
" files; disable it there if redraws feel slow.

if get(g:, 'vim_markdown_folding_disabled', 0)
  finish
endif

if exists('b:did_markdown_fold')
  finish
endif
let b:did_markdown_fold = 1

setlocal foldmethod=expr
setlocal foldexpr=markdownfold#foldexpr()

" foldmethod and foldexpr are window-local, so they must be reapplied
" whenever this buffer enters a window (e.g. :b switch, :split).
augroup markdown_fold_winlocal
  autocmd! * <buffer>
  autocmd BufEnter <buffer>
        \ if &foldmethod !=# 'expr' || &foldexpr !=# 'markdownfold#foldexpr()' |
        \   setlocal foldmethod=expr foldexpr=markdownfold#foldexpr() |
        \ endif
augroup END

command! -buffer MarkdownFoldBlocks       call markdownfold#close_blocks()
command! -buffer MarkdownUnfoldBlocks     call markdownfold#open_blocks()
command! -buffer MarkdownToggleBlocks     call markdownfold#toggle_blocks()
