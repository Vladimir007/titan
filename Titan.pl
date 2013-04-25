#!/usr/bin/perl
use Encode;
use English;
use strict;
use Cwd qw(cwd);
use File::Copy qw(copy);
use Time::HiRes;
use File::Cat;
########################################################################
# Global variables
########################################################################

# Main base of words
my $main_words = 'base.cfg';

# Directory of this script
my $script_dir;

my $version = 1;
my $patchlevel = 4;
########################################################################
# Subroutine prototypes
########################################################################

# Checks and creates all needed files and directories
sub check_files();

# Starting new test, reads only 'base.cfg' file in 'data'
sub start(@);

# Help message
sub help();

# Generate array of random numbers
sub generate_nums($$);

# Generate new 'base.cfg' file with .cfg files in 'mods'
sub make_base($$);

# Bonds two arrays of russian translate
sub bond_translate($$);

# Read text from 'texts' and ask if you want to add words
sub read_new_text();

# Shuffling array
sub shuffle(@);

# Print word with translation
sub translate_word($);

# Check $task and do it
sub do_task($);

# Learn some words
sub learn_new_words($);

# Create tempfile with some words from base.cfg
sub create_rand_wordfile($);
########################################################################
# Main section
########################################################################
my $name;
my $score = 0;
print "===================================================\n";
print "============== Welcome to the Titan! ==============\n";
print "===================================================\n";
print "Enter your name: ";
$name = <STDIN>;
chomp($name);
$name = 'unknown' if($name eq '');
check_files();
print "Hello, $name!\nLet's start. If you don't know what to do enter 'help'.\n";

my @score_arr;
open(my $savefile, '<', "$script_dir/saves")
	or die("Error 6: couldn't open file 'saves' for read!");
while(my $line = <$savefile>)
{
	chomp($line);
	if($line =~ /^name:(.*);score=(\d+);$/)
	{
		if($1 eq $name)
		{
			$score = int($2);
		}
		else
		{
			push(@score_arr, $line);
		}
	}
}
close($savefile);

while(1)
{
	print "> ";
	my $task = <STDIN>;
	chomp($task);
	do_task($task);
}
########################################################################
# Subroutines
########################################################################

sub check_files()
{
	unless(defined($script_dir))
	{
		$script_dir = $0;
		if($script_dir !~ /^\//)
		{
			$script_dir = Cwd::cwd($script_dir) . '/' . $script_dir;
		}
		if($script_dir =~ /^(.*)\/\w+.pl$/)
		{
			$script_dir = $1;
		}
	}
	unless(-d $script_dir)
	{
		print "Error 1: couldn't find script directory: $script_dir\n";
		exit(1);
	}
	unless(-d "$script_dir/data")
	{
		print "Error 2: unable to find 'data' directory!\n";
		exit(1);
	}
	mkdir("$script_dir/mods") unless(-d "$script_dir/mods");
	mkdir("$script_dir/texts") unless(-d "$script_dir/texts");
	unless(-f "$script_dir/saves")
	{
		open(FILE1, '>', "$script_dir/saves") or die("Error 7: couldn't create file 'saves'!");
		close(FILE1);
	}
	unless(-f "$script_dir/data/$main_words")
	{
		print "Error 3: unable to find main word file: $script_dir/data/$main_words!\n";
		exit(1);
	}
	$main_words = "$script_dir/data/$main_words";
}

sub help()
{
	print << "EOH";
====================================================================
|    Hello!                                                        |
| This is Titan - good helper in learning english words.           |
|                                                                  |
| Here you can see all commands are availabled in                  |
| this programm now:                                               |
| 'start' - start new test;                                        |
|   'start eng' - start test with english words;                   |
|   'start ru' - start test with russian words;                    |
|   'start final' - start final test with ALL english words;       |
| 'learn' - start tests. You will exit from this tests only if     |
|    you learn words that this command give you.                   |
| 'tr <word>' - find <word> translation in base                    |
| 'install' - add all words in mods/*.cfg to the main base;        |
| 'newtext' - add words from texts/*.txt;                          |
|   this command will create new .cfg files in mods/ and           |
|   after translation you can install them;                        |
| 'score' - scores;                                                |
| 'myscore' - your score;                                          |
| 'help' - print this help;                                        |
| 'exit' - exit from this program; also you can use this           |
|   command while testing, but with losing a lot of score points.  |
| 'version' - get information about programm version.              |
|                                                                  |
| After installing you can delete all mods. Texts that were read   |
| are renamed to <file>.done                                       |
====================================================================
EOH
}

sub start(@)
{
	my $return_result = 1;
	my $word_file = shift;
	my $num_of_words = shift;
	my $mode = shift;
	my $lang;
	$lang = 0 if($mode == 0);
	$lang = 1 if($mode == 1);
	
	my %word_database;
	my @arr_for_final;
	my $i = 0;
	open(my $wordfile, '<', $word_file)
		or die("Couldn't open file $word_file for read: $ERRNO");
	while(<$wordfile>)
	{
		chomp($_);
		if($_ =~ /^(\w.*) - (.*?);/)
		{
			$i++;
			push(@arr_for_final, $i) if($mode == 3);
			$word_database{$i} = {
				'eng' => $1,
				'rus' => $2,
				'num' => 1,
				'with_tr' => 0
			};
			my $post = $POSTMATCH;
			while($post =~ /^(.*?);/)
			{
				$word_database{$i}{'rus'} .= ";$1";
				$word_database{$i}{'num'}++;
				$post = $POSTMATCH;
			}
			if($post =~ /(\[.*\])/)
			{
				$word_database{$i}{'tra'} = "$1";
				$word_database{$i}{'with_tr'} = 1;
			}
		}
	}
	close($wordfile) or die("Couldn't close file $word_file!\n");
	if($i == 0)
	{
		print "Word base is empty\n";
		return 1;
	}
	@arr_for_final = shuffle(@arr_for_final) if($mode == 3);
	my @arr_of_nums;
	if($mode == 3)
	{
		$num_of_words = $i;
		@arr_of_nums = @arr_for_final;
	}
	else
	{
		@arr_of_nums = generate_nums($i, $num_of_words);
	}

	my $time1;
	my $time2;
	my $result = 0;
	my $success = 0;
	my $ready = 1;
	my @wrong_ans;

	my $num = 0;
	while($num < $num_of_words)
	{
		my $r = pop(@arr_of_nums);
		$lang = shift(@arr_of_nums) if($mode == 2);
		if($lang == 0)
		{
			print "Enter translate of '$word_database{$r}{'eng'}': > ";
			$time1 = Time::HiRes::time;
			my $my_word = <STDIN>;
			$time2 = Time::HiRes::time;
			chomp($my_word);
			last if($my_word eq 'exit');
			$success = 0;
			my $translates = $word_database{$r}{'rus'};
			$i = 1;
			while($i <= $word_database{$r}{'num'})
			{
				if($translates =~ /^(.*?);/)
				{
					if($1 eq $my_word)
					{
						$success = 1;
						last;
					}
					$translates = $POSTMATCH;
				}
				else
				{
					if($translates eq $my_word)
					{
						$success = 1;
						last;
					}
				}
				$i++;
			}
			if($success == 1)
			{
				my $delta = $time2 - $time1;
				printf("Right! (%.1f sec)", $delta);
				if($delta < 10.0)
				{
					$score += 3;
				}
				elsif($delta < 15.0)
				{
					$score += 2;
				}
				elsif($delta <= 20.0)
				{
					$score++;
					print " But not very fast...";
					$return_result = 0;
				}
				else
				{
					print " But too long :(";
					push(@wrong_ans, $r);
					$return_result = 0;
					$score -= 2;
					$ready = 0;
				}
				print "\n";
				$result++;
			}
			else
			{
				print "Wrong!\n";
				$return_result = 0;
				$score -= 5;
				$ready = 0;
				push(@wrong_ans, $r);
			}
		}
		else
		{
			my $ru_word = $word_database{$r}{'rus'};
			if($word_database{$r}{'num'} > 1)
			{
				my $rand_num_word_from_ru = (int(rand($word_database{$r}{'num'})) + 1);
				$i = 1;
				while(1)
				{
					if(($ru_word =~ /^(.*?);/) and ($i == $rand_num_word_from_ru))
					{
						$ru_word = $1;
						last;
					}
					elsif(($ru_word =~ /^.*?;/) and ($i < $rand_num_word_from_ru))
					{
						$ru_word = $POSTMATCH;
					}
					elsif(($ru_word =~ /^(.*?);/) and ($rand_num_word_from_ru == 1))
					{
						$ru_word = $1;
						last;
					}
					else
					{
						last;
					}
					$i++;
				}
			}
			else
			{
				$ru_word = $word_database{$r}{'rus'};
			}
			print "Enter translate of '$ru_word': > ";
			$time1 = Time::HiRes::time;
			my $my_word = <STDIN>;
			chomp($my_word);
			last if($my_word eq 'exit');
			$time2 = Time::HiRes::time;
			my $delta = $time2 - $time1;
			if($my_word eq $word_database{$r}{'eng'})
			{
				printf("Right! (%.1f sec)", $delta);
				if($delta < 10.0)
				{
					$score += 3;
				}
				elsif($delta < 15.0)
				{
					$score += 2;
				}
				elsif($delta <= 20.0)
				{
					$score++;
					$return_result = 0;
					print " But not very fast...";
				}
				else
				{
					print " But too long :(";
					push(@wrong_ans, $r);
					$return_result = 0;
					$score -= 2;
				}
				print "\n";
				$result++;
			}
			else
			{
				$success = 0;
				foreach my $l(keys %word_database)
				{
					if((($word_database{$l}{'rus'} =~ /$ru_word;/)
						or ($word_database{$l}{'rus'} =~ /$ru_word$/))
						and ($word_database{$l}{'eng'} eq $my_word))
					{
						$success = 1;
					}
				}
				if($success == 1)
				{
					printf("Right! (%.1f sec)", $delta);
					if($delta < 10.0)
					{
						$score += 3;
					}
					elsif($delta < 15.0)
					{
						$score += 2;
					}
					elsif($delta <= 20.0)
					{
						$score++;
						$return_result = 0;
						print " But not very fast...";
					}
					else
					{
						print " But too long :(";
						push(@wrong_ans, $r);
						$return_result = 0;
						$score -= 2;
					}
					print "\n";
					$result++;
				}
				else
				{
					print "Wrong!\n";
					$score -= 5;
					$return_result = 0;
					push(@wrong_ans, $r);
				}
			}
		}
		$num++;
	}
	my @elements;
	while(my $elem = <@wrong_ans>)
	{
		unless(grep $_ == $elem, @elements)
		{
			push(@elements, $elem);
		}
	}
	my $elements_size = @elements;
	$elements_size = 0 if(($elements_size == 1) and (@elements[0] =~ /^\s*$/));
	print "===================================================\n";
	my $percents = int(($result/$num_of_words) * 100);
	print "Your result: $result of $num_of_words ($percents\%);\n";
	if(($mode == 3) and ($ready == 1))
	{
		print "Congratulations! You are ready.\n";
	}
	elsif($mode == 3)
	{
		print "You are not prepared! :(\n";
	}
	$score -= $num_of_words if($percents < 50);
	print "Please learn this words:\n" if($elements_size);
	while(<@elements>)
	{
		print "   $word_database{$_}{'eng'} " if(defined($word_database{$_}{'eng'}));
		print "$word_database{$_}{'tra'} " if($word_database{$_}{'with_tr'} == 1);
		print "- $word_database{$_}{'rus'};\n" if(defined($word_database{$_}{'rus'}));
	}
	return $return_result;
}

sub generate_nums($$)
{
	my $up = shift;
	my $tasks = shift;
	my $rand_num = 1;
	my $tmp = 1;
	my @arr;
	my $j = 1;
	while($j <= $tasks)
	{
		while($tmp == $rand_num)
		{
			$tmp = int(rand($up)) + 1;
		}
		
		$rand_num = int(rand(2));
		push(@arr, $tmp);
		unshift(@arr, $rand_num);
		$rand_num = $tmp;
		$j++;
	}
	return @arr;
}

sub make_base($$)
{
	my $old_file_with_words = shift;
	my $new_file_with_words = shift;
	my $wordfile;
	my $k = 1;
	my %old_tasks;
	my %new_tasks;
	open($wordfile, '<', $old_file_with_words) or die("Couldn't open file $old_file_with_words for read!\n");
	my $num_of_old_tasks = 0;
	while(<$wordfile>)
	{
		chomp($_);
		if($_ =~ /^(\w.*) - (.*;)/)
		{
			$num_of_old_tasks++;
			$old_tasks{$num_of_old_tasks} = {
				'eng' => $1,
				'rus' => $2,
				'tra' => '',
				'with_tr' => 0,
				'is_fin' => 1
			};
			
			if($POSTMATCH =~ /(\[.*\])/)
			{
				$old_tasks{$num_of_old_tasks}{'tra'} = "$1";
				$old_tasks{$num_of_old_tasks}{'with_tr'} = 1;
			}
		}
	}
	close($wordfile) or die("Couldn't close file $old_file_with_words!\n");

	my $num_of_new_tasks = 0;
	open($wordfile, '<', $new_file_with_words) or die("Couldn't open file $new_file_with_words for read!\n");
	while(<$wordfile>)
	{
		my $templine = $_;
		chomp($templine);
		if($templine =~ /^(\w.*) - (.*;)/)
		{
			$num_of_new_tasks++;
			$new_tasks{$num_of_new_tasks} = {
				'eng' => $1,
				'rus' => $2,
				'tra' => '',
				'with_tr' => 0
			};
			if($POSTMATCH =~ /(\[.*\])/)
			{
				$new_tasks{$num_of_new_tasks}{'tra'} = "$1";
				$new_tasks{$num_of_new_tasks}{'with_tr'} = 1;
				$k = 1;
			}
			foreach my $key (keys %new_tasks)
			{
				if(($new_tasks{$num_of_new_tasks}{'eng'} eq $new_tasks{$key}{'eng'}) and ($key != $num_of_new_tasks))
				{
					$new_tasks{$key}{'rus'} = bond_translate($new_tasks{$num_of_new_tasks}{'rus'}, $new_tasks{$key}{'rus'});
					$new_tasks{$key}{'tra'} = $new_tasks{$num_of_new_tasks}{'tra'}
						if($new_tasks{$num_of_new_tasks}{'with_tr'} == 1);
					undef($new_tasks{$num_of_new_tasks});
					$num_of_new_tasks--;
				}
			}
			foreach my $key (keys %old_tasks)
			{
				if($new_tasks{$num_of_new_tasks}{'eng'} eq $old_tasks{$key}{'eng'})
				{
					$old_tasks{$key}{'is_fin'} = 0;
					$new_tasks{$num_of_new_tasks}{'rus'} = bond_translate($new_tasks{$num_of_new_tasks}{'rus'}, $old_tasks{$key}{'rus'});
					$new_tasks{$num_of_new_tasks}{'tra'} = $old_tasks{$key}{'tra'}
						if($old_tasks{$key}{'with_tr'} == 1);
				}
			}
		}
		elsif($templine !~ /^\w*$/)
		{
			print "Warning: string '$templine' is no supported! Fix it before installing.\n";
		}
	}
	close($wordfile) or die("Couldn't close file $new_file_with_words!\n");
	
	my $j = 1;
	my $k = 1;
	open(my $tempfile, '>', $old_file_with_words) or die("Error while opening $old_file_with_words for write!: $ERRNO");
	foreach my $key (keys %old_tasks)
	{
		print($tempfile "$old_tasks{$key}{'eng'} - $old_tasks{$key}{'rus'}$old_tasks{$key}{'tra'}\n")
			if($old_tasks{$key}{'is_fin'} == 1);
	}
	foreach my $key (keys %new_tasks)
	{
		print($tempfile "$new_tasks{$key}{'eng'} - $new_tasks{$key}{'rus'}$new_tasks{$key}{'tra'}\n") if($new_tasks{$key}{'eng'});
	}
	close($tempfile);
}

sub bond_translate($$)
{
	my $rus1 = shift;
	my @translate1;
	my $rus2 = shift;
	my @translate2;
	my $tmp;
	while($rus1 =~ /(.*?);/)
	{
		$tmp = $1;
		$rus1 = $POSTMATCH;
		while($tmp =~ /(.*)\s+(.*)/)
		{
			$tmp = $1 . '_' . $2;
		}
		push(@translate1, $tmp);
	}
	while($rus2 =~ /(.*?);/)
	{
		$tmp = $1;
		$rus2 = $POSTMATCH;
		while($tmp =~ /(.*)\s+(.*)/)
		{
			$tmp = $1 . '_' . $2;
		}
		push(@translate2, $tmp);
	}
	
	while($rus2 = <@translate2>)
	{
		unless(grep $_ eq $rus2, @translate1)
		{
			push(@translate1, $rus2);
		}
	}
	while(<@translate1>)
	{
		$tmp = $_;
		while($tmp =~ /(.*)_(.*)/)
		{
			$tmp = $1 . ' ' . $2;
		}
		$rus2 .= "$tmp;";
	}
	return $rus2;
}

sub read_new_text()
{
	my @new_words;
	my @not_checked_words;
	print "Starting reading files...\n";
	foreach my $file(<$script_dir/texts/*.txt>)
	{
		open(my $new_text, '<', $file);
		while(<$new_text>)
		{
			my $line = $_;
			chomp($line);
			while($line =~ /(\w{3,})/)
			{
				my $pretemp_word = $1;
				$pretemp_word =~ tr/[A-Z]/[a-z]/;
				push(@new_words, $pretemp_word);
				$line = $POSTMATCH;
			}
		}
		close($new_text);
		rename($file, "$1.done") if($file =~ /(.*)\.txt/);
	}
	if(@new_words == 0)
	{
		print "English words were not found!\n";
		return;
	}
	@new_words = shuffle(@new_words);
	
	my $tempfile = 'temp-0.cfg';
	while(-f "$script_dir/mods/$tempfile")
	{
		$tempfile = 'temp-' . int(rand(100)) . '.cfg';
	}
	open(my $temp, '>', "$script_dir/mods/$tempfile");
	while(my $elem_in_new = <@new_words>)
	{
		unless(grep $_ eq $elem_in_new, @not_checked_words)
		{
			print("Do you want to add '$elem_in_new' (1/0)? > ");
			my $ans = int(<STDIN>);
			if($ans == 1)
			{
				print($temp "$elem_in_new - \n");
			}
			push(@not_checked_words, $elem_in_new);
		}
	}
	close($temp);
	print "Done! Your new words at $tempfile. Please translate it and install.\n";
}

sub shuffle(@)
{
	my @arr = @_;
	my $i = @arr;
	while(--$i)
	{
		my $j = rand($i + 1);
		@arr[$i, $j] = @arr[$j, $i];
	}
	return @arr;
}

sub translate_word($)
{
	my $my_word = shift;
	my $is_found = 0;
	chomp($my_word);
	print "-------------------------------------------------\n";
	open(my $wordfile, '<', $main_words) or die("Couldn't open file $main_words for read!\n");
	while(<$wordfile>)
	{
		chomp($_);
		if($_ =~ /$my_word/)
		{
			print "$_\n";
			$is_found = 1;
		}
	}
	close($wordfile) or die("Couldn't close file $main_words!\n");
	print "-------------------------------------------------\n" if($is_found);;
	print "Word wasn't found :(\nIf this word in any file at 'mods' you should install it before use.\n"
		unless($is_found);
}

sub do_task($)
{
	my $l_task = shift;
	if($l_task =~ /start/)
	{
		my $delta_score = $score;
		my $mode = $POSTMATCH;
		my $num_of_words;
		unless($mode =~ /final/)
		{
			print "How many words do you want to check?\n>> ";
			$num_of_words = int(<STDIN>);
			unless($num_of_words)
			{
				print("Failed.\n");
				return;
			}
			if($num_of_words > 200)
			{
				my $test_time = int($num_of_words/10);
				print "This test would take more than $test_time minutes.\nDo you want to continue? (y/n) > ";
				my $warn_ans = <STDIN>;
				return unless($warn_ans =~ /y/);
			}
			if($mode =~ /eng/)
			{
				print "Starting english test with $num_of_words words...\n";
				print "===================================================\n";
				start($main_words, $num_of_words, 0);
			}
			elsif($mode =~ /ru/)
			{
				print "Starting russian test with $num_of_words words...\n";
				print "===================================================\n";
				start($main_words, $num_of_words, 1);
			}
			else
			{
				print "Starting test with $num_of_words words...\n";
				print "===================================================\n";
				start($main_words, $num_of_words, 2);
			}
		}
		else
		{
			$num_of_words = 0;
			open(MYFILE, '<', $main_words)
				or die("Couldn't open file $main_words for read: $ERRNO");
			while(<MYFILE>)
			{
				chomp($_);
				$num_of_words++ if($_ !~ /^\s*$/);
			}
			close(MYFILE);
			if($num_of_words > 200)
			{
				my $test_time = int($num_of_words/10);
				print "This test would take more than $test_time minutes.\nDo you want to continue? (y/n) > ";
				my $warn_ans = <STDIN>;
				return unless($warn_ans =~ /y/);
			}
			print "Starting final test with $num_of_words words.\n";
			print "===================================================\n";
			start($main_words, $num_of_words, 3);
		}
		$score = 0 if($score < 0);
		$delta_score = $score - $delta_score;
		if($delta_score >= 0)
		{
			print "You've got $delta_score points for this test.\n";
		}
		else
		{
			$delta_score = -$delta_score;
			print "You've lost $delta_score points for this test.\n";
		}
	}
	elsif($l_task =~ /learn/)
	{
		print "How much words do you want to learn?\n";
		print "(by default this number is 20)\n>>> ";
		my $num = int(<STDIN>);
		$num = 20 if(($num > 100) or ($num < 10));
		learn_new_words($num);
	}
	elsif($l_task =~ /exit/)
	{
		unshift(@score_arr, "name:$name;score=$score;");
		print "Exiting...\n";
		open($savefile, '>', "$script_dir/saves") or die("Error 7: couldn't open file 'saves' for write!: $ERRNO");
		while(<@score_arr>)
		{
			print($savefile "$_\n");
		}
		close($savefile);
		last;
	}
	elsif($l_task =~ /help/)
	{
		help();
	}
	elsif($l_task =~ /install/)
	{
		print "Making base...\n";
		foreach my $file (<$script_dir/mods/*.cfg>)
		{
			print "Adding '$file'...\n";
			make_base($main_words, $file);
		}
		print "Done!\n";
	}
	elsif($l_task =~ /newtext/)
	{
		read_new_text();
	}
	elsif($l_task =~ /myscore/)
	{
		print "Your score is: $score;\n";
	}
	elsif($l_task =~ /score/)
	{
		print("You - $score;\n");
		if(@score_arr)
		{
			while(<@score_arr>)
			{
				if($_ =~ /name:(.*);score=(\d+);/)
				{
					print("$1 - $2;\n");
				}
			}
		}
	}
	elsif($l_task =~ /^tr \s*(.*)\s*/)
	{
		translate_word($1);
	}
	elsif($l_task =~ /version/)
	{
		print "Titan-$version.$patchlevel\n";
	}
	else
	{
		print "Unknown command. Write 'help' for more info.\n";
	}
}

sub learn_new_words($)
{
	my $num = shift;
	my $tempfile = create_rand_wordfile($num);
	my $success_level = 0;
	print "You will learn now $num words. Repeat it and we will start:\n";
	print "===================================================\n";
	cat($tempfile, \*STDOUT) or die("Couldn't read $tempfile: $ERRNO");
	print "===================================================\n";
	print "Press enter to continue...";
	<STDIN>;
	while(1)
	{
		if($success_level < 5)
		{
			my $score_before_test = $score;
			my $report_num_test = 5 - $success_level;
			print "LEVEL 1: english\n";
			print "You need to be successfuly tested $report_num_test more times to level up.\n";
			print "Press enter when you will be ready to continue.\n";
			<STDIN>;
			if(start($tempfile, int($num * 0.5), 0))
			{
				$success_level++;
			}
			else
			{
				$success_level--;
			}
			$score = $score_before_test;
			$success_level = 50 if($success_level == 5);
		}
		elsif($success_level < 55)
		{
			my $score_before_test = $score;
			my $report_num_test = 55 - $success_level;
			print "LEVEL 2: russian.\n";
			print "You need to be successfuly tested $report_num_test more times to level up.\n";
			print "Press enter when you will be ready.\n";
			<STDIN>;
			if(start($tempfile, int($num * 0.7), 1))
			{
				$success_level++;
			}
			else
			{
				$success_level--;
			}
			$score = $score_before_test;
			$success_level = 100 if($success_level == 55);
		}
		elsif($success_level < 103)
		{
			my $score_before_test = $score;
			my $report_num_test = 103 - $success_level;
			print "LEVEL 3: combined.\n";
			print "You need to be successfuly tested $report_num_test more times to level up.\n";
			print "Press enter when you will be ready.\n";
			<STDIN>;
			if(start($tempfile, $num, 2))
			{
				$success_level++;
			}
			else
			{
				$success_level--;
			}
			$score = $score_before_test;
			$success_level = 150 if($success_level == 103);
		}
		elsif($success_level < 155)
		{
			my $score_before_test = $score;
			print "LEVEL 4: final test.\n";
			print "You have 2 tries.\nIf you failed both you will start from level 1.\n";
			print "Try 1!" if($success_level == 150);
			print "Try 2!" if($success_level == 149);
			print "Press enter when you will be ready.\n";
			<STDIN>;
			if(start($tempfile, 20, 3))
			{
				$success_level = 200;
			}
			else
			{
				$success_level--;
				if($success_level == 148)
				{
					$success_level = 0;
					print "You failed twice!\n";
				}
				else
				{
					print "Failed! But you have one more try. Be careful...\n";
				}
			}
			$score = $score_before_test;
		}
		elsif($success_level == 200)
		{
			my $delta_score = ($num * 2);
			print "You've comleted all tests and got $delta_score points! Congratulations!\n";
			$score += $delta_score;
			last;
		}
		else
		{
			print "Error 11: learn-$success_level\n";
		}
	}
	unlink($tempfile) or die("Couldn't delete $tempfile: $ERRNO");	
}

sub create_rand_wordfile($)
{
	my $num = shift;
	my $tempfile = 'learn-temp-0.cfg';
	my $all_words_num = 0;
	open(MYFILE, '<', $main_words)
		or die("Couldn't open $main_words for read:$ERRNO");
	while(<MYFILE>)
	{
		chomp($_);
		$all_words_num++ if($_ !~ /^\s*$/);
	}
	close(MYFILE);
	
	while(-f "$script_dir/mods/$tempfile")
	{
		$tempfile = 'learn-temp-' . int(rand(100)) . '.cfg';
	}
	$tempfile = "$script_dir/mods/$tempfile";
	my @new_words_for_learning = generate_nums($all_words_num, $num);
	open(MYFILE, '<', $main_words)
		or die("Couldn't open $main_words for read:$ERRNO");
	open(NEWFILE, '>', $tempfile)
		or die("Couldn't open $tempfile for write:$ERRNO");
	my $i = 1;
	while(<MYFILE>)
	{
		chomp($_);
		my $line = $_;
		if($line !~ /^\s*$/)
		{
			$i++;
			if(grep $_ == $i, @new_words_for_learning)
			{
				print(NEWFILE "$line\n");
			}
		}
	}
	close(NEWFILE);
	close(MYFILE);
	return $tempfile;
}

#$ch = uc($ch); # для латиницы
