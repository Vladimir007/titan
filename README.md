titan
=====

Program that help in learning english(or russian) words.

You can use it without installation by running Titan.pl script.


But if you want to start program simply by entering 'Titan' in console,
you need to install it. Script will be copied to '/usr/local/bin'.

1. Installing
You need to do this steps to install this program:
a) cd <TOP_LEVEL_OF_PROG_DIR>
b) make
c) make install
  (IMPORTENT: don't do this under root: sudo make install)
  Program will call you password while installing to copying script.

2. Mods and texts

For installing text files and mods you can copy it to '~/.titan/texts' or
'~/.titan/mods'.

3. Starting

After installing you can start this program in terminal by command 'Titan'.
Then you can read 'help' information about base commands.

4. Starting without installing

If you don't want to install this program but want to try it you should
go to top level of this directory and run programm by command './Titan.pl'.
(In case of error try 'chmod +x ./Titan.pl' and then start).
