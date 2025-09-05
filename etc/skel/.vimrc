"**********************
"* NTS STANDARD VIMRC *
"**********************
" Enable syntax highlighting
syntax on
" Disable vi compatibility mode
set nocompatible
" Enable filetype plugin
filetype plugin on
" Set tabs to two spaces
set expandtab
set tabstop=2
set softtabstop=2
set shiftwidth=2
" Ignore case when searching
set ignorecase
" Line numbers
set number
" Mark column 80
set colorcolumn=80
" Display status line
set laststatus=2
" Display filename on statusline
set statusline=[%F]
" Display total lines on statusline
set statusline+=[%LL]
" Display read-only status on statusline if applicable
set statusline+=%r
" Display modified status on statusline if applicable
set statusline+=%m
" Left/right separator
set statusline+=%=
" Line/column display on statusline
set statusline+=[L%l,C%c]
" Percentage of progress through the file
set statusline+=(%P)
