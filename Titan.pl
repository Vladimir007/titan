#!/usr/bin/perl
use Encode;
use English;
use strict;
use Cwd qw(cwd);
use File::Copy qw(copy);
use Time::HiRes;
use File::Cat;
use utf8;
system("./test-titan.pl 2> /dev/null");
my $tmp_check_exit = $?;
print "TEST: test-titan.pl returned with code '$tmp_check_exit'.\n";
use if($tmp_check_exit == 0), "XML::Twig";
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
sub txt_to_xml($$);
sub start_with_xml(@);
sub calc_res($$);
########################################################################
# Main section
########################################################################
my $name;
my $score = 0;
print "===================================================\n";
print "============== Welcome to the Titan! ==============\n";
print "===================================================\n";
print "WARNING! XML Twig will not be used.\n" if($tmp_check_exit);
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
	my @ret_arr;
	if($up == 0)
	{
		my $j = 1;
		while($j <= $tasks)
		{
			my $rand_lang = int(rand(2));
			push(@ret_arr, $rand_lang);
			$j++;
		}
	}
	else
	{
		my $j = 1;
		while($j <= $tasks)
		{
			my $tmp = 1;
			my $rand_num = 1;
			while($tmp == $rand_num)
			{
				$tmp = int(rand($up)) + 1;
			}
			push(@ret_arr, $tmp);
			$rand_num = $tmp;
			$j++;
		}
	}
	return @ret_arr;
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
	elsif($l_task =~ /xml/)
	{
		print "Testing mode!\n";
		#start_test();
		#print "Error in start_with_xml." if(start_with_xml("test3.xml", 3, 0));
		check_xml_file("test3.xml");
		#txt_to_xml($main_words, "test3.xml");
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

#$ch = uc($ch); # для латиницы сделать все буквы слова $ch заглавными

sub start_test()
{
	my $xml_file = 'test3.xml';
	return 1 unless(-f $xml_file);
	my $twig = new XML::Twig;
	$twig->parsefile("$xml_file");
	my $root = $twig->root('wordbase');
	my @words = $root->children('word');
	my $test_word;
	foreach my $word_from_base (@words)
	{
		my $word_id = $word_from_base->att('id');
		$test_word = $word_from_base if($word_id == 653);
	}
	my @test_word_translations = $test_word->children('ru');
	my $ru_num = @test_word_translations;
	for(my $i = 0; $i < $ru_num; $i++)
	{
		@test_word_translations[$i] = @test_word_translations[$i]->text;
		my $temp_ru_word = @test_word_translations[$i];
		utf8::encode($temp_ru_word);
		print "2:$temp_ru_word\n";
		@test_word_translations[$i] = $temp_ru_word;
	}
	my $test_word = $test_word->first_child('eng')->text;
	print "enter translate of $test_word(@test_word_translations)>";
	my $answere = <STDIN>;
	chomp($answere);
	#utf8::encode($answere);
	print "Your answere is $answere;\n";
	print "Right!!!\n" if(grep $_ eq $answere, @test_word_translations);
	open(my $xml_res, '>', 'test2.xml') or die "Error";
#	binmode($xml_res, ":utf8");
	$twig->set_pretty_print('record');
	$twig->print($xml_res);
	close($xml_res);
	#$twig->print;
}

sub txt_to_xml($$)
{
	my $in_file = shift;
	my $out_file = shift;
	my $cnt = 0;
	my @out_arr = ("<?xml version=\"1.0\"?>", "<wordbase>");
	open(MYFILE, '<', $in_file) or die "ERROR";
	while(<MYFILE>)
	{
		chomp($_);
		my $in_line = $_;
		if($in_line =~ /^(\w.*) - (.*?);/)
		{
			$cnt++;
			push(@out_arr, "  <word id=\"$cnt\">");
			push(@out_arr, "    <eng>$1</eng>");
			push(@out_arr, "    <ru>$2</ru>");
			my $post = $POSTMATCH;
			while($post =~ /^(.*?);/)
			{
				push(@out_arr, "    <ru>$1</ru>");
				$post = $POSTMATCH;
			}
			push(@out_arr, "    <tr>$post</tr>") if($post =~ /\[.*\]/);
			push(@out_arr, "  </word>");
		}
	}
	push(@out_arr, "</wordbase>");
	close(MYFILE);
	open(MYNEW, '>', $out_file) or die "ERROR!!";
	my $cnt = @out_arr;
	foreach my $arrline(@out_arr)
	{
		print(MYNEW "$arrline\n");
	}
	close(MYNEW);
}

sub xml_to_txt($$)
{
	my $xml_file = shift;
	my $txt_file = shift;
	my $cnt = 0;
	my $twig = new XML::Twig;
	$twig->parsefile("$xml_file");
	my $root = $twig->root('wordbase');
	my @words = $root->children('word');
	my @out_arr;
	foreach my $xml_word (@words)
	{
		my $eng_word_from_xml = $xml_word->first_child('eng')->text;
		my $new_txt_line = $eng_word_from_xml;
		my @ru_words_from_xml = $xml_word->children('ru');
		$new_txt_line .= " - ";
		my $ru_num = @ru_words_from_xml;
		for(my $j = 0; $j < $ru_num; $j++)
		{
			@ru_words_from_xml[$j] = @ru_words_from_xml[$j]->text;
			my $temp_ru_word = @ru_words_from_xml[$j];
			utf8::encode($temp_ru_word);
			@ru_words_from_xml[$j] = $temp_ru_word;
			$new_txt_line .=
		}
		my $transc_from_xml = $xml_word->first_child('tr');
		if($transc_from_xml)
		{
			$transc_from_xml = $transc_from_xml->text;
			$new_txt_line .= $transc_from_xml;
		}
		
	}
	open(MYFILE, '<', $xml_file) or die "ERROR";
	while(<MYFILE>)
	{
		chomp($_);
		my $in_line = $_;
		if($in_line =~ /^(\w.*) - (.*?);/)
		{
			$cnt++;
			push(@out_arr, "  <word id=\"$cnt\">");
			push(@out_arr, "    <eng>$1</eng>");
			push(@out_arr, "    <ru>$2</ru>");
			my $post = $POSTMATCH;
			while($post =~ /^(.*?);/)
			{
				push(@out_arr, "    <ru>$1</ru>");
				$post = $POSTMATCH;
			}
			push(@out_arr, "    <tr>$post</tr>") if($post =~ /\[.*\]/);
			push(@out_arr, "  </word>");
		}
	}
	push(@out_arr, "</wordbase>");
	close(MYFILE);
	open(MYNEW, '>', $out_file) or die "ERROR!!";
	my $cnt = @out_arr;
	foreach my $arrline(@out_arr)
	{
		print(MYNEW "$arrline\n");
	}
	close(MYNEW);
}

sub start_with_xml(@)
{
	my $word_file = shift;
	my $num_of_words = shift;
	my $test_mode = shift;
	my $lang;
	$lang = 0 if(($test_mode == 0) or ($test_mode == 3));
	$lang = 1 if($test_mode == 1);
	
	unless(-f $word_file)
	{
		print "Error: Word file '$word_file' wasn't found.";
		return (-1);
	}
	my $twig = new XML::Twig;
	$twig->parsefile("$word_file");
	my $root = $twig->root('wordbase');
	my @words = $root->children('word');

	my $base_size = @words;
	if($base_size == 0)
	{
		print "Word base is empty!\n";
		return (-1);
	}
	elsif($base_size < 5)
	{
		print "Word base is too small (only $base_size words).\n";
		return (-1);
	}

	my @arr_of_nums;
	my @arr_of_lang;
	if($test_mode == 3)
	{
		for(my $j = 1; $j <= $base_size; $j++)
		{
			push(@arr_of_nums, $j);
		}
		shuffle(@arr_of_nums);
	}
	else
	{
		@arr_of_nums = generate_nums($base_size, $num_of_words);
		@arr_of_lang = generate_nums(0, $num_of_words);
	}

	my %xml_map;
	foreach my $word (@words)
	{
		$xml_map{$word->att('id')} = {'word' => $word};
	}

	my $time1;
	my $time2;
	my @wrong_ans;
	my $result = 0;
	my $num = 0;
	while($num < $num_of_words)
	{
		my $word_id = shift(@arr_of_nums);
		$lang = shift(@arr_of_lang) if($test_mode == 2);
		# --------------------------Preparing word-----------------------------------
		my $eng_word = $xml_map{$word_id}{'word'}->first_child('eng')->text;
		my @ru_words = $xml_map{$word_id}{'word'}->children('ru');
		my $ru_num = @ru_words;
		for(my $j = 0; $j < $ru_num; $j++)
		{
			@ru_words[$j] = @ru_words[$j]->text;
			my $temp_ru_word = @ru_words[$j];
			utf8::encode($temp_ru_word);
			@ru_words[$j] = $temp_ru_word;
		}
		my $transcription = $xml_map{$word_id}{'word'}->first_child('tr');
		if($transcription)
		{
			$transcription = $transcription->text;
			utf8::encode($transcription);
		}
		#----------------------------------------------------------------------------
		my $success = 0;
		if($lang == 0)
		{
			print "Enter translate of '$eng_word': > ";
			$time1 = Time::HiRes::time;
			my $my_word = <STDIN>;
			$time2 = Time::HiRes::time;
			chomp($my_word);
			return 0 if($my_word eq 'exit');
			$success = 1 if(grep $_ eq $my_word, @ru_words);
			my $delta = $time2 - $time1;
			my $add_points = calc_res($delta, $success);
			push(@wrong_ans, $word_id) if($add_points <= 0);
			$score += $add_points;
			$result++ if($add_points >=0);
		}
		else
		{
			my $rand_num_word_from_ru = (int(rand(@ru_words)) + 1);
			print "Debug: $rand_num_word_from_ru\n";
			my $ru_word = @ru_words[$rand_num_word_from_ru];
			print "Enter translate of '$ru_word': > ";
			$time1 = Time::HiRes::time;
			my $my_word = <STDIN>;
			$time2 = Time::HiRes::time;
			chomp($my_word);
			return 0 if($my_word eq 'exit');
			if($my_word eq $eng_word)
			{
				$success = 1;
			}
			else
			{
				my @eng_words = $eng_word;
				foreach my $key(keys %xml_map)
				{
					my @tmp_ru_words = $xml_map{$key}{'word'}->children('ru');
					my $tmp_ru_num = @tmp_ru_words;
					for(my $j = 0; $j < $tmp_ru_num; $j++)
					{
						@tmp_ru_words[$j] = @tmp_ru_words[$j]->text;
						my $temp_ru_word = @tmp_ru_words[$j];
						utf8::encode($temp_ru_word);
						@tmp_ru_words[$j] = $temp_ru_word;
					}
					push(@eng_words, $xml_map{$key}{'word'}->first_child('eng')->text)
						if(grep $_ eq $my_word, @tmp_ru_words);
				}
				$success = 1 if(grep $_ eq $my_word, @eng_words);
			}
			my $delta = $time2 - $time1;
			my $add_points = calc_res($delta, $success);
			push(@wrong_ans, $word_id) if($add_points <= 0);
			$score += $add_points;
			$result++ if($add_points >=0);
		}
		$num++;
	}
	my @elements;
	while(my $elem = <@wrong_ans>)
	{
		push(@elements, $elem) unless(grep $_ == $elem, @elements);
	}
	my $elements_size = @elements;
	$elements_size = 0 if(($elements_size == 1) and (@elements[0] =~ /^\s*$/));
	print "===================================================\n";
	my $percents = int(($result/$num_of_words) * 100);
	print "Your result: $result of $num_of_words ($percents\%);\n";
	$score -= $num_of_words if($percents < 50);
	if($elements_size)
	{
		print "Please learn this words:\n";
		while(<@elements>)
		{
			my $eng_to_learn = $xml_map{$_}{'word'}->first_child('eng')->text;
			my @ru_to_learn = $xml_map{$_}{'word'}->children('ru');
			my $ru_learn_num = @ru_to_learn;
			for(my $j = 0; $j < $ru_learn_num; $j++)
			{
				@ru_to_learn[$j] = @ru_to_learn[$j]->text;
				my $temp_ru_word = @ru_to_learn[$j];
				utf8::encode($temp_ru_word);
				@ru_to_learn[$j] = $temp_ru_word . ';';
			}
			my $tr_to_learn;
			if($xml_map{$_}{'word'}->first_child('tr'))
			{
				$tr_to_learn = $xml_map{$_}{'word'}->first_child('tr')->text;
				utf8::encode($tr_to_learn);
			}
			print "   $eng_to_learn " if(defined($eng_to_learn));
			print "$tr_to_learn " if($tr_to_learn);
			print "- @ru_to_learn\n" if($ru_learn_num);
		}
	}
	return 0;
}

sub calc_res($$)
{
	my $time = shift;
	my $success = shift;
	my $add_points = 0;
	if($success == 1)
	{
		printf("Right! (%.1f sec)", $time);
		if($time < 10.0)
		{
			$add_points = 3;
		}
		elsif($time < 15.0)
		{
			$add_points = 2;
		}
		elsif($time <= 20.0)
		{
			$add_points = 0;
			print " But not very fast...";
		}
		else
		{
			print " But too long :(";
			$add_points = -2;
		}
		print "\n";
	}
	else
	{
		print "Wrong!\n";
		$add_points = -5;
	}
	return $add_points;
}

sub check_xml_file($)
{
	my $check_xml_file = shift;
	my $check_twig = new XML::Twig;
	$check_twig->parsefile("$check_xml_file");
	my $check_root = $check_twig->root;
	my @words = $check_root->children('word');
	my $num_of_words = @words;
	if($num_of_words < 3)
	{
		print "Words base is too little ($num_of_words words), you should add more words to learn.\n";
		return 1;
	}
	foreach my $check_word (@words)
	{
		my $check_err_id = $check_word->att('id');
		print "Word without id\n" unless($check_err_id);
		my @check_english_words = $check_word->children('eng');
		if(@check_english_words != 1)
		{
			my $check_eng_arr;
			foreach my $check_eng_word (@check_english_words)
			{
				$check_eng_word = $check_eng_word->text;
				$check_eng_arr .= "$check_eng_word; ";
			}
			print "Word with id $check_err_id should have only one english word: $check_eng_arr;\n";
			return 1;
		}
		my $check_eng_word = $check_word->first_child('eng')->text;
		my @check_russian_words = $check_word->children('ru');
		if(@check_russian_words == 0)
		{
			print "Word with id $check_err_id haven't any russian translates ($check_eng_word);\n";
			return 1;
		}
		my @check_transcriptions = $check_word->children('tr');
		if(@check_transcriptions > 1)
		{
			print "Word with id $check_err_id haven't any russian translates ($check_eng_word);\n";
			return 1;
		}
	}
	print "XML file '$check_xml_file' were successfully checked!\n";
	return 0;
}
