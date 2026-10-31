" Set autoindentation
set autoindent

" On pressing tab, insert 2 spaces 
set expandtab 

" Set tab width to x columns
set tabstop=2
set softtabstop=2

" Set shift width to x spaces
set shiftwidth=2

" Add numbers to each line on the left-hand side.
set number

" Turn syntax highlighting on
syntax on

" Show partial command you type in the last line of the screen.
set showcmd

" Show the mode you are on the last line.
set showmode

" Show matching words during a search.
set showmatch

" Use highlighting when doing a search.
set hlsearch

" Highlight cursor line underneath the cursor horizontally.
" set cursorline

" While search through the file incrementally highlight matching characters as you type.
set incsearch

" Ignore capital letters during search.
set ignorecase

" Override the ignorecase option if searching for capital letters.
" This will allow you to search specifically for capital letters.
set smartcase

" Set the commands to save in history default number is 20
set history=1000

" Enable auto completion menu after pressing tab.
set wildmenu

" Make wildmenu behave like similar to Bash completion
set wildmode=list:longest

" There are certain files that we would never want to edit with Vim.
" Wildmenu will ignore files with these extensions.
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx

" Enable type file detection. Vim will be able to try to detect the type of file in use.
filetype on

" Enable plugins and load plugin for the detected file type.
filetype plugin on

" Load an indent file for the detected file type.
filetype indent on

" changing cursor type
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

" " reset the cursor on start (for older versions of vim, usually not required)
" augroup myCmds
" au!
" autocmd VimEnter * silent !echo -ne "\e[2 q"
" augroup END
