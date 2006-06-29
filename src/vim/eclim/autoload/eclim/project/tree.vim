" Author:  Eric Van Dewoestine
" Version: ${eclim.version}
"
" Description: {{{
"
" License:
"
" Copyright (c) 2005 - 2006
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"      http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.
"
" }}}

" Global Variables {{{
  " command used (minus the :split) to open the tree window.
  if !exists('g:EclimProjectTreeWincmd')
    if exists('g:Tlist_Use_Horiz_Window') && g:Tlist_Use_Horiz_Window
      let g:EclimProjectTreeWincmd = 'botright'
    elseif exists('g:Tlist_Use_Right_Window') && g:Tlist_Use_Right_Window
      let g:EclimProjectTreeWincmd = 'botright vertical'
    else
      let g:EclimProjectTreeWincmd = 'topleft vertical'
    endif
  endif

  " command used to navigate to a content window before executing a command.
  if !exists('g:EclimProjectTreeContentWincmd')
    if exists('g:Tlist_Use_Horiz_Window') && g:Tlist_Use_Horiz_Window
      let g:EclimProjectTreeContentWincmd =
        \ 'call eclim#project#tree#HorizontalContentWindow()'
    elseif exists('g:Tlist_Use_Right_Window') && g:Tlist_Use_Right_Window
      let g:EclimProjectTreeContentWincmd = 'winc h'
    else
      let g:EclimProjectTreeContentWincmd = 'winc l'
    endif
  endif

  if !exists('g:EclimProjectTreeTaglistRelation')
    let g:EclimProjectTreeTaglistRelation = 'below'
  endif

  if exists('g:Tlist_WinWidth')
    let g:EclimProjectTreeWidth = g:Tlist_WinWidth
  elseif !exists('g:EclimProjectTreeWidth')
    let g:EclimProjectTreeWidth = 30
  endif
  if exists('g:Tlist_WinHeight')
    let g:EclimProjectTreeHeight = g:Tlist_WinHeight
  elseif !exists('g:EclimProjectTreeHeight')
    let g:EclimProjectTreeHeight = 10
  endif

  let g:EclimProjectTreeTitle = 'Project_Tree'
" }}}

" Script Variables {{{
  let s:project_tree_loaded = 0
  let s:project_tree_dirs = ''
" }}}

" ProjectTree(...) {{{
" Open a tree view of the current or specified projects.
function! eclim#project#tree#ProjectTree (...)
  " no project dirs supplied, use current project
  if len(a:000) == 0
    let dir = eclim#project#GetCurrentProjectRoot()
    if dir == ''
      call eclim#util#Echo('Unable to determine project.')
      return
    endif
    let dirs = [dir]

  " list of dirs supplied (all projects)
  elseif type(a:000[0]) == 3
    let dirs = a:000[0]

  " list or project names
  else
    let dirs = []
    for project in a:000
      call add(dirs, eclim#project#GetProjectRoot(project))
    endfor
  endif

  let dir_list = string(dirs)

  if s:project_tree_dirs != dir_list
    call s:CloseTreeWindow()
  endif

  if bufwinnr(g:EclimProjectTreeTitle) == -1
    call s:OpenTreeWindow()
  endif

  if s:project_tree_dirs != dir_list
    call s:OpenTree(dirs)

    augroup project_tree
      autocmd!
      autocmd BufEnter * call eclim#project#tree#CloseIfLastWindow()
    augroup END
    if exists('g:EclimProjectTreeTaglistRelation')
      augroup project_tree
        autocmd BufWinEnter __Tag_List__ call eclim#project#tree#ReopenTree()
      augroup END
    endif

    let s:project_tree_dirs = dir_list
  endif
endfunction " }}}

" ProjectsTree() {{{
" Open a tree view of all the projects.
function! eclim#project#tree#ProjectsTree ()
  let dirs = eclim#project#GetProjectDirs()
  if !(len(dirs) == 1 && dirs[0] == '0')
    call eclim#project#tree#ProjectTree(dirs)
  endif
endfunction " }}}

" CloseIfLastWindow() {{{
function eclim#project#tree#CloseIfLastWindow ()
  if (winnr('$') == 1 && bufwinnr(g:EclimProjectTreeTitle) != -1) ||
      \  (winnr('$') == 2 &&
      \   bufwinnr(g:TagList_title) != -1 &&
      \   bufwinnr(g:EclimProjectTreeTitle) != -1)
    if tabpagenr('$') > 1
      tabclose
    else
      quitall
    endif
  endif
endfunction " }}}

" ReopenTree() {{{
function eclim#project#tree#ReopenTree ()
  let projectwin = bufwinnr(g:EclimProjectTreeTitle)
  if projectwin != -1
    exec projectwin . 'winc w'
    close
    call s:OpenTreeWindow()

    if g:EclimProjectTreeWincmd =~ 'vert'
      exec 'vertical resize ' . g:EclimProjectTreeWidth
    else
      exec 'resize ' . g:EclimProjectTreeHeight
    endif
  endif
endfunction " }}}

" CloseTreeWindow() " {{{
function! s:CloseTreeWindow ()
  let winnr = bufwinnr(g:EclimProjectTreeTitle)
  if winnr != -1
    exec winnr . 'winc w'
    close
  endif
endfunction " }}}

" OpenTreeWindow() " {{{
function! s:OpenTreeWindow ()
  let taglist_window = bufwinnr(g:TagList_title)
  " taglist relative
  if taglist_window != -1 && exists('g:EclimProjectTreeTaglistRelation')
    let wincmd = taglist_window . 'winc w | ' . g:EclimProjectTreeTaglistRelation . ' '

    if g:EclimProjectTreeWincmd !~ 'vert'
      let wincmd .= g:EclimProjectTreeHeight
    endif

  " absolute location
  else
    if g:EclimProjectTreeWincmd =~ 'vert'
      let wincmd = g:EclimProjectTreeWincmd . ' ' . g:EclimProjectTreeWidth
    else
      let wincmd = g:EclimProjectTreeWincmd . ' ' . g:EclimProjectTreeHeight
    endif
  endif

  "call eclim#util#ExecWithoutAutocmds(wincmd . ' split project_tree')
  silent exec wincmd . 'split ' . g:EclimProjectTreeTitle
  if g:EclimProjectTreeWincmd =~ 'vert'
    set winfixwidth
  else
    set winfixheight
  endif

  setlocal nowrap
  setlocal nonumber
endfunction " }}}

" OpenTree(dirs) " {{{
function! s:OpenTree (dirs)
  if !s:project_tree_loaded
    " remove any settings related to usage of tree as an external filesystem
    " explorer.
    if exists('g:TreeSettingsFunction')
      unlet g:TreeSettingsFunction
    endif
  endif

  call tree#Tree(g:EclimProjectTreeTitle, a:dirs, len(a:dirs) == 1, [])

  if !s:project_tree_loaded
    call tree#RegisterFileAction('.*', 'Split',
      \ "call eclim#project#tree#OpenProjectFile('split', '<file>')")
    call tree#RegisterFileAction('.*', 'Edit',
      \ "call eclim#project#tree#OpenProjectFile('edit', '<file>')")
    call tree#RegisterFileAction('.*', 'Tab', 'tabnew <file>')

    let s:project_tree_loaded = 1
  endif

  setlocal bufhidden=hide
endfunction " }}}

" OpenProjectFile(cmd, file) {{{
" Execute the supplied command in one of the main content windows.
function! eclim#project#tree#OpenProjectFile (cmd, file)
  let cwd = substitute(getcwd(), '\', '/', 'g')
  exec g:EclimProjectTreeContentWincmd
  exec a:cmd . ' ' . cwd . '/' . a:file
endfunction " }}}

" HorizontalContentWindow() {{{
" Command for g:EclimProjectTreeContentWincmd used when relative to a
" horizontal taglist window.
function! eclim#project#tree#HorizontalContentWindow ()
  winc k
  if exists('g:TagList_title') && bufname(bufnr('%')) == g:TagList_title
    winc k
  endif
endfunction " }}}

" vim:ft=vim:fdm=marker
