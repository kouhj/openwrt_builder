echo Fixing defaults.vim not found bug ...
if [ ! -f $1/usr/share/vim/defaults.vim ]; then
    ln -s vimrc $1/usr/share/vim/defaults.vim
fi
