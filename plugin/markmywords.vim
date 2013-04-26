" Vim global plugin for personal bookmarks
" Maintainer:	Barry Arthur <barry.arthur@gmail.com>
" Version:	0.1
" Description:	Arbitrary bookmarks within your files and Vim's help
" Last Change:	2013-04-17
" License:	Vim License (see :help license)
" Location:	plugin/markmywords.vim
" Website:	https://github.com/dahu/markmywords
"
" See markmywords.txt for help.  This can be accessed by doing:
"
" :helptags ~/.vim/doc
" :help markmywords

let g:markmywords_version = '0.1'

" Vimscript Setup: {{{1
" Allow use of line continuation.
let s:save_cpo = &cpo
set cpo&vim

" load guard
" uncomment after plugin development.

"if exists("g:loaded_markmywords")
"      \ || v:version < 700
"      \ || v:version == 703 && !has('patch338')
"      \ || &compatible
"  let &cpo = s:save_cpo
"  finish
"endif
"let g:loaded_markmywords = 1

" Options: {{{1
if !exists('g:markmywords_tagfile')
  let g:markmywords_tagfile = expand('<sfile>:p:h:h') . '/markmywords.tags'
endif

exe 'set tags^=' . g:markmywords_tagfile

" Private Functions: {{{1
function! s:MMW_AddTag(tags, file, line, pattern)
  let tagset = []
  try
    silent! let tagset = readfile(g:markmywords_tagfile)
  endtry
  if len(filter(copy(tagset), 'v:val =~? "^".a:tags'))
    echohl Question
    let input = input('Replace existing tag named "'.a:tags.'"? yes/no: ')
    echohl NONE
    redraw!
    if input !~? '^y\%[es]$'
      return
    endif
    call filter(tagset, 'v:val !~? "^".a:tags."\\t"')
  endif
  let cmd = 'call MMW_OpenTag(' . a:line . ', ' . string(a:pattern) . ')'
  call add(tagset, a:tags . "\t" . a:file . "\t" . cmd)
  call sort(tagset)
  if writefile(tagset, g:markmywords_tagfile) == -1
    echoerr "MMW: Unable to write to tag file " . g:markmywords_tagfile
  endif
endfunction

function! s:ReOpenAsHelp()
  let file = expand('%:t')
  let lnum = line('.')
  bdelete
  exe 'help ' . file
  exe lnum
endfunction

function! s:complete(al, cl, cp)
  return map(filter(taglist(a:al), 'v:val.name =~# "^MMW_"'), 'v:val.name[4:]')
endfunction

" Public Interface: {{{1
function! MMW_MarkLine()
  let tags = ''
  let file = expand('%:p')
  let line = line('.')
  let pattern = getline('.')
  if pattern =~ '^\s*$'
    echohl Warning
    echo "Can't tag empty line."
    echohl NONE
    return
  else
    let pattern = escape(pattern, '\.*^$[]')
  endif
  let tags = input('Tags: ', '', 'tag')
  let tags = 'MMW_' . substitute(tags, ',*\s\+\|,\+\s*', '_', 'g')
  call s:MMW_AddTag(tags, file, line, pattern)
endfunction

function! MMW_Select(terms)
  let terms = substitute(a:terms, '^MMW_', '', '')
  let tselect_pattern = '\%(\_^MMW_\)\@<=.\{-}\%('
  " Double escaped bars because it's an ex command arg.
  let tselect_pattern .= join(split(terms, ',*\s\+\|,\s*'), '\\|')
  let tselect_pattern .= '\)'
  let bt = &bt
  let &bt = ''
  let tags = taglist(tselect_pattern)
  if len(tags) == 1
    let cmd = 'tag ' . tags[0].name
  elseif len(tags) > 1
    let cmd = 'tselect /' . tselect_pattern
  else
    echohl ErrorMsg
    echom 'MarkMyWords: No tag matches the given arguments.'
    echohl None
    return
  endif
  try
    exe cmd
  finally
    let &bt = bt
  endtry
  if &ft =~# 'help'
    call s:ReOpenAsHelp()
  endif
endfunction

function! MMW_OpenTag(line, pattern)
  if empty(a:pattern)
    let line = a:line
  else
    let line = search(a:pattern, 'wcn')
    if !line
      let line = a:line
    endif
  endif
  exec line . 'normal! ^'
endfunction

" Maps: {{{1
nnoremap <Plug>MMW_Select   :MMWSelect<space>
nnoremap <Plug>MMW_MarkLine :MMWMarkLine<CR>

if !hasmapto('<Plug>MMW_Select')
  nmap <unique> <leader>'l <Plug>MMW_Select
endif

if !hasmapto('<Plug>MMW_MarkLine')
  nmap <unique><silent> <leader>ml <Plug>MMW_MarkLine
endif

" Commands: {{{1

" TODO: create a custom completion
" -bar relevant here?
command! -bar -nargs=+ -complete=customlist,s:complete MMWSelect call MMW_Select(<q-args>)
command! -bar -nargs=0 -complete=tag MMWMarkLine call MMW_MarkLine()


" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:save_cpo

" vim: set sw=2 sts=2 et fdm=marker:
