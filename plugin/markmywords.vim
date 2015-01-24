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
function! s:AddTag(tags, file, line, pattern)
  let tagset = []
  try
    silent! let tagset = readfile(g:markmywords_tagfile)
  endtry
  if a:tags =~? 'helpmark'
    call filter(tagset, 'v:val !~? "^".a:tags."\\t"')
  else
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
  endif
  let cmd = 'call MMW_OpenTag(' . a:line . ', "' . escape(a:pattern, '"') . '")'
  call add(tagset, a:tags . "\t" . a:file . "\t" . cmd)
  call sort(tagset)
  if writefile(tagset, g:markmywords_tagfile) == -1
    echoerr "MMW: Unable to write to tag file " . g:markmywords_tagfile
  endif
endfunction

function! s:ReOpenAsHelp()
  let file = expand('%:t')
  let lnum = line('.')
  buffer #
  bwipe #
  if exists('g:MMW_altbuf')
    exe 'buffer ' . g:MMW_altbuf
    buffer #
    unlet g:MMW_altbuf
  endif
  exe 'help ' . file
  exe lnum
endfunction

function! s:complete(al, cl, cp)
  let al = a:al
  if al == ''
    let al = 'MMW_'
  endif
  return map(filter(taglist(al), 'v:val.name =~# "^MMW_"'), 'v:val.name[4:]')
endfunction

" Public Interface: {{{1
function! MMW_MarkLine(...)
  let tags = ''
  let file = expand('%:p')
  let line = line('.')
  let pattern = getline('.')
  if pattern !~ '^\s*$'
    let pattern = escape(pattern, '\.*^$~[]')
  endif
  if a:0
    let tags = join(a:000, ' ')
  else
    let tags = input('Tags: ', '', 'tag')
  endif
  let tags = 'MMW_' . substitute(tags, ',*\s\+\|,\+\s*', '_', 'g')
  call s:AddTag(tags, file, line, pattern)
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
  let g:MMW_altbuf = expand('#')
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
  let line = empty(a:pattern) ? 0 : search(a:pattern, 'wcn')
  if !line
    if get(g:, 'mmw_alert_on_fallback', 1)
      echohl WarningMsg
      echom 'MMW: The line content has changed and can not be found. Moving the cursor to the fallback line number.'
      echohl NONE
    endif
    let line = a:line
  endif
  exec line . 'normal! ^'
endfunction

function! MMW_ListTags()
  return map(taglist('^MMW_'), 'substitute(v:val.name, "^MMW_", "", "")')
endfunction

"""" VimFindsMe plugin

function! s:SID()
  return "<SNR>" . matchstr(expand('<sfile>'), '<SNR>\zs\d\+_\zeSID$')
endfun

function! s:mmw_vfmbrowse_taglist()
  return map(vfm#readfile(g:markmywords_tagfile),
        \ 'substitute(v:val, "^\\S\\+\t\\S\\+\\zs.*", "", "")')
endfunction

function! s:mmw_vfmbrowse_callback()
  return MMW_Select(matchstr(vfm#select_line(), '^\S\+'))
endfunction

function! MMW_VFMBrowse()
  if ! exists('g:vfm_version')
    echohl Warning
    echom 'MMW_VFMBrowse() requires https://github.com/dahu/VimFindsMe'
    echohl None
  else
    call vfm#show_list_overlay(s:mmw_vfmbrowse_taglist())
    call vfm#overlay_controller({'<enter>' : ':call ' . s:SID() . 'mmw_vfmbrowse_callback()'})
  endif
endfunction

" Maps: {{{1
nnoremap <Plug>MMW_Select   :MMWSelect<space>
nnoremap <Plug>MMW_MarkLine :MMWMarkLine<CR>
nnoremap <Plug>MMW_Browse   :MMWBrowse<cr>

if !hasmapto('<Plug>MMW_Select')
  nmap <unique> <leader>'l <Plug>MMW_Select
endif

if !hasmapto('<Plug>MMW_MarkLine')
  nmap <unique><silent> <leader>ml <Plug>MMW_MarkLine
endif

if !hasmapto('<Plug>MMW_Browse')
  nmap <unique> <leader>mb <Plug>MMW_Browse
endif

" Commands: {{{1

" TODO: create a custom completion
" -bar relevant here?
command! -bar -nargs=+ -complete=customlist,s:complete MMWSelect call MMW_Select(<q-args>)
command! -bar -nargs=0 -complete=tag MMWMarkLine call MMW_MarkLine()

command! -bar -nargs=0 MMWList echo join(MMW_ListTags(), ', ')
command! -bar -nargs=0 MMWBrowse call MMW_VFMBrowse()

augroup MMW
  au!
  au BufLeave * if &ft =~? 'help' | call MMW_MarkLine('helpmark') | endif
augroup END

" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:save_cpo

" vim: set sw=2 sts=2 et fdm=marker:
