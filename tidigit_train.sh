#!/bin/bash

###############################################################################
#Description: script to perform training with tidigit database using HTK
#Author: Subhash Kunnath
#Date: 2/2/2016
#Arguments: tidigits_root_dir
###############################################################################
if [ "$#" -ne 1 ]; then
    echo "Usage $0 tidigits_root_dir"
    exit 1
fi

#check if directory exist or not
if [ ! -d "$1" ]; then
    echo "Directory $1 does not exist"
    exit 1
fi

tidigits_root_dir=$1
#check if there are any wav files
echo "directory exists" 
file_count=$(find $1 -name *.wav | wc -l)
echo "found $file_count wav files"



###########################create prompt.txt###################################
#	
###############################################################################
function create_prompt {
	echo ">>>creating prompt.txt..."
	if [ prompt_list ]
	then
	    
		if [ 0 -lt $file_count ]
		then
			echo "processing"
			echo "$file_count wav files inside $tidigits_root_dir"
			  #creating prompt file prompt.txt
			find $tidigits_root_dir -name \*.wav | (
			    while read file; do
				part=$(echo $file  | sed 's/^.*\/\([1-9|o|z|a|b]*.wav\)$/ \1/')
			   	#convert each digit from the file name into word  <123.wav one two three>
				echo $part $(echo $part | sed  's/[a|b].wav//'|sed 's/o/oh /g'| sed 's/1/one /g'|sed 's/2/two /g'| sed 's/3/three /g' | sed 's/4/four /g' | sed 's/5/five /g'|sed 's/6/six /g'|sed 's/7/seven /g'|sed 's/8/eight /g'|sed 's/9/nine /g'| sed 's/z/zero /g')  
			    done
			  ) > prompt.txt
			#check if the propmpt.txt created or not
			if [ ! -f prompt.txt ]
			then
				echo "Unable to create prompt.txt"
			exit 1
			fi
		fi

		echo "$(pwd)/prompt.txt created"

	fi
	echo "<<<created prompt.txt"
}


###########################create wdlist###################################
#	
###########################################################################
function create_wdlist {
	echo ">>>creating wdlist..."
	if [ word_list ]
	then
		
		if [ ! -f prompt.txt ]
		then	
			echo "Error: Unable to create wdlist: $(pwd)/prompt.txt does not exist"
			exit 1
		fi
		if [ ! -f prompts2wlist ]
		then	
			echo "Error: Unable to create wdlist: $(pwd)/prompts2wlist does not exist"
			exit 1
		fi
		perl ./prompts2wlist prompt.txt wlist
		echo "!ENTER" >> wlist #adde enter and exit entries in wlist
		echo "!EXIT" >> wlist
	
	fi
	echo "<<<created wdlist"
}
#################################create words.mlf###########################
#		 words.mlf contains the .lab entries for each prompt line
############################################################################
function create_wdmlf {
	echo ">>>creating words.mlf..."
	if [ ! -f prompt.txt ]
	then	
		echo "Error: Unable to create words.mlf: $(pwd)/prompt.txt does not exist"
		exit 1
	fi
	if [ ! -f prompts2mlf ]
	then	
		echo "Error: Unable to create wdlist: $(pwd)/prompts2mlf does not exist"
		exit 1
	fi

	if [ word_mlf ]
	then

		#expecting the perl script file in the same directory
		echo "#!MLF!#" > words.mlf
			
		cat prompt.txt  | while read line
		do
		  
			echo $line | awk '{split($1,a,"."); print "\"*/"a[1]".lab\""} { for(i = 2; i <= NF; i++) { print $i; } }; {print "."}' >> words.mlf

		done

	fi
	echo "<<<created words.mlf"

}

#################################create words.mlf###########################
#		 words.mlf contains the .lab entries for each prompt line
############################################################################
function create_dict {

	if [ -f dict -a -f dict_sp ]
	then
		echo "Please create dict files" #user is supposed to mannually create the dict files
		#can be automated if required
	fi

}
############################################################################

#################################create phones0.mlf###########################
#      phones0.mlf contains the phoneme sequence for each utterance 
############################################################################
function create_phones0mlf {
	echo ">>> creating phones0.mlf ..."
	printf "EX\n" > mkphones0.led
	printf "IS sil sil\n" >> mkphones0.led
	printf "DE sp\n" >> mkphones0.led
	if [ ! -f mkphones0.led ]
	then
		echo "Error: mkphones0.led does not exist"
		exit 1
	fi
	if [ ! -f words.mlf ]
	then
		echo "Error: words.mlf does not exist"
		exit 1
	fi
	HLEd -l '*' -d dict_sp -i phones0.mlf mkphones0.led words.mlf
	if [ ! -f phones0.mlf ]
	then
		echo "Error: Unable to create file phones0.mlf"	
	fi
	echo "<<< created phones0.mlf"

}


#################################create phones1.mlf###########################
#      phones1.mlf contains the phoneme sequence for each utterance with sp s
##############################################################################
function create_phones1mlf {
	echo ">>> creating phones1.mlf ..."
	printf "EX\n" > mkphones1.led
	printf "IS sil sil\n" >> mkphones1.led
	#check if the file exists or not
	if [ ! -f mkphones1.led ]
	then
		echo "Error: mkphones0.led does not exist"
		exit 1
	fi
	if [ ! -f words.mlf ]
	then
		echo "Error: words.mlf does not exist"
		exit 1
	fi
	HLEd -l '*' -d dict_sp -i phones1.mlf mkphones1.led words.mlf
	if [ ! -f phones1.mlf ]
	then
		echo "Error: Unable to create file phones1.mlf"	
	fi
	echo "<<< created phones1.mlf"

}

#################################create mfcc##################################
#      				Create mfcc files
##############################################################################
function create_mfcc {
	echo ">>> creating mfccs ..."
	find $tidigits_root_dir -name \*.wav | (
        while read file; do
		mfc=$(echo $file | sed 's/\(^.*\/.*\.\)wav$/ \1mfc/' )
		echo $file $mfc  #append to the file train.scp
        done
        ) > train.scp
	if [ ! -f train.scp ]
	then
		echo "Error: Unable to create train.scp"
		exit 1
	fi

	HCopy -C config -S train.scp # create mfc files
	mfc_count=$(find $tidigits_root_dir -name *.mfc | wc -l)
	
	if [ $file_count -gt $mfc_count ]
	then
		echo "found $file_count wav files and $mfc_count mfc files"		
		echo "failed to create mfc files for all the wav files"
		exit 1
	fi
	
	echo ">>> successfully created $mfc_count mfc files ..."

}

#################################create hmm0##################################
#      				Create hmm0 files
##############################################################################
function create_hmm0_3 {


	#create a list of all mfc files
	find $tidigits_root_dir -name \*.mfc | (
        while read file; do
		#mfc=$(echo $file | sed 's/\(^.*\/.*\.\)wav$/ \1mfc/' )
		echo $file
        done
        )  > tidigitmfc.scp 

	if [ ! -f tidigitmfc.scp ]
	then
		echo "Error: Unable to create tidigitsmfc.scp"
		exit 1
	fi
	#create hmm0 directory
	mkdir -p hmm0
	#create a poto file
	cat > proto <<- EOM
	~o <VecSize> 39 <MFCC_0_D_A_Z>
	~h "proto"
	<BeginHMM>
	<NumStates> 5
	<State> 2
	<Mean> 39
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	<Variance> 39
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	<State> 3
	<Mean> 39
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	<Variance> 39
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	<State> 4
	<Mean> 39
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0
	<Variance> 39
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0
	<TransP> 5
	0.0 1.0 0.0 0.0 0.0
	0.0 0.6 0.4 0.0 0.0
	0.0 0.0 0.6 0.4 0.0
	0.0 0.0 0.0 0.7 0.3
	0.0 0.0 0.0 0.0 0.0
	<EndHMM>
	EOM
	#creates proto and vFloors files
	HCompV -C configmf -f 0.01 -m -S tidigitmfc.scp -M hmm0 proto

	if [ ! -f hmm0/proto ]
	then
		echo "Error: Unable to create proto files"
		exit 1
	fi
	if [ ! -f hmm0/vFloors ]
	then
		echo "Error: Unable to create vFloors files"
		exit 1
	fi
	echo "created hmm0 files"

	#creating macros file
	cat > hmm0/macros <<- EOM
	~o
	<VecSize> 39
	<MFCC_0_D_A_Z>
	EOM
	cat hmm0/vFloors >> hmm0/macros 
	###############################create a list of monophones##############
	if [ ! -f dict_sp ]
	then
		echo "Error: dict_sp does not exist"
		exit 1
	fi
	#create a list monophones from dict_sp
	cat dict_sp | awk '{for(i=2;i<=NF;++i)print $i}' | sort | uniq > monophone
	sed -i '/sp/d' monophone
	#######################################################################
	echo "sil" >> monophone

	if [ ! -f monophone ]
	then
		echo "Error: Unable to create monophone files"
		exit 1
	fi

	for phone in $(cat monophone); 
	do 
		cat hmm0/proto | sed "s/proto/"$phone"/"; 
	done > hmm0/hmmdefs

	#reestimation
	mkdir -p hmm1
	HERest -C configmf -I phones0.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H hmm0/macros -H hmm0/hmmdefs -M hmm1 monophone
	mkdir -p hmm2
	HERest -C configmf -I phones0.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H hmm1/macros -H hmm1/hmmdefs -M hmm2 monophone
	mkdir -p hmm3
	HERest -C configmf -I phones0.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H hmm2/macros -H hmm2/hmmdefs -M hmm3 monophone
#TODO add file check here 	
	echo "created hmm3 files"

}
###########################create sil states##################################
#      				Create sil states
##############################################################################
function create_sil {
	echo ">>> fixing silence states"
	if [ ! -f hmm3/hmmdefs ]
	then
		echo "Error: hmm3/hmmdefs does not exist"
		exit 1
	fi
	if [ ! -f hmm3/macros ]
	then
		echo "Error: hmm3/macros does not exist"
		exit 1
	fi

	mkdir -p hmm4
	cp hmm3/hmmdefs hmm4



	strt_no=$(cat hmm4/hmmdefs | awk '/<STATE> 3/ {print NR-1 }' | tail -1)
	end_no=$(cat hmm4/hmmdefs | awk '/<STATE> 4/ {print NR-1 }' | tail -1)
	let "end_no=$end_no+1"
	awk "NR > $strt_no && NR < $end_no" hmm4/hmmdefs | sed 's\<STATE> 3\<STATE> 2\' > hmm4/hmmtmp

	trns_no=$(cat hmm4/hmmdefs | awk '/<TRANSP> 5/ {print NR-1 }' | tail -1)

	awk "NR > $trns_no {print }" hmm4/hmmdefs | sed 's\<TRANSP> 5\<TRANSP> 3\' | awk '{print $1,$2,$3}' | awk "NR!=4 && NR!=5" >> hmm4/hmmtmp


	cat >> hmm4/hmmdefs <<- EOM
	~o <VecSize> 39 <MFCC_0_D_A_Z>
	~h "sp"
	<BeginHMM>
	<NumStates> 3
	EOM

	cat hmm4/hmmtmp >> hmm4/hmmdefs
	rm hmm4/hmmtmp
	
	cp hmm3/macros hmm4/macros

	cat > sil.hed <<- EOM
	AT 2 4 0.2 {sil.transP}
	AT 4 2 0.2 {sil.transP}
	AT 1 3 0.3 {sp.transP}
	TI silst {sil.state[3],sp.state[2]}
	EOM

	#create monophone1
	cat monophone > monophones1
	echo "sp" >> monophones1
	
	mkdir -p hmm5
	HHEd -H hmm4/macros -H hmm4/hmmdefs -M hmm5 sil.hed monophones1
	mkdir -p hmm6
	HERest -C configmf -I phones1.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H hmm5/macros -H hmm5/hmmdefs -M hmm6 monophones1
	mkdir -p hmm7
	HERest -C configmf -I phones1.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H hmm6/macros -H hmm6/hmmdefs -M hmm7 monophones1

	echo "<<< fixing silence states done"


}

##################################Realign#####################################
#      				
##############################################################################
function realign {
	echo ">>>Starting realignment"
	HVite -l '*' -o SWT -C configmf -a -H hmm7/macros -H hmm7/hmmdefs -i aligned.mlf -m -t 250.0 150.0 1000.0 -y lab -I words.mlf -S tidigitmfc.scp dict_sp monophones1
	echo "IS sil sil" > mkphones.led
	HLEd -n triphones1 -l '*' -i new_aligned.mlf mkphones.led aligned.mlf
	mkdir -p hmm8
	HERest -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H hmm7/macros -H hmm7/hmmdefs -M hmm8 monophones1
	mkdir -p hmm9
	HERest -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H hmm8/macros -H hmm8/hmmdefs -M hmm9 monophones1
	echo "<<<Realignment done"

}

##################################gmm#########################################
#      				
##############################################################################
function gmm {
	#create directories	
	mkdir -p Gauss/{2G,4G,8G,16G}
	echo "MU 2 {*.state[2-4].mix}" > Gauss/2G/2gaussian
	#2 Gaussian model
	mkdir -p Gauss/2G/hmm10
	HHEd -A -T 1 -H hmm9/macros -H hmm9/hmmdefs -M Gauss/2G/hmm10 Gauss/2G/2gaussian monophones1
	mkdir -p Gauss/2G/hmm11
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/2G/hmm10/macros -H Gauss/2G/hmm10/hmmdefs -M Gauss/2G/hmm11 monophones1
	mkdir Gauss/2G/hmm12
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/2G/hmm11/macros -H Gauss/2G/hmm11/hmmdefs -M Gauss/2G/hmm12 monophones1
	mkdir Gauss/2G/hmm13
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/2G/hmm12/macros -H Gauss/2G/hmm12/hmmdefs -M Gauss/2G/hmm13 monophones1
	mkdir -p Gauss/2G/hmm14
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/2G/hmm13/macros -H Gauss/2G/hmm13/hmmdefs -M Gauss/2G/hmm14 monophones1
	#4 Gaussian model
	echo "MU 4 {*.state[2-4].mix}" >> Gauss/4G/4gaussian
	mkdir -p Gauss/4G/hmm15
	HHEd -A -T 1 -H Gauss/2G/hmm14/macros -H Gauss/2G/hmm14/hmmdefs -M Gauss/4G/hmm15 Gauss/4G/4gaussian monophones1
	mkdir -p Gauss/4G/hmm16
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/4G/hmm15/macros -H Gauss/4G/hmm15/hmmdefs -M Gauss/4G/hmm16 monophones1
	mkdir -p Gauss/4G/hmm17
  	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/4G/hmm16/macros -H Gauss/4G/hmm16/hmmdefs -M Gauss/4G/hmm17 monophones1
	mkdir -p Gauss/4G/hmm18
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/4G/hmm17/macros -H Gauss/4G/hmm17/hmmdefs -M Gauss/4G/hmm18 monophones1
 	mkdir -p Gauss/4G/hmm19
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/4G/hmm18/macros -H Gauss/4G/hmm18/hmmdefs -M Gauss/4G/hmm19 monophones1
	#8 Gaussian model
	echo "MU 8 {*.state[2-4].mix}" >> Gauss/8G/8gaussian
	mkdir -p Gauss/8G/hmm20
	HHEd -A -T 1 -H Gauss/4G/hmm19/macros -H Gauss/4G/hmm19/hmmdefs -M Gauss/8G/hmm20 Gauss/8G/8gaussian monophones1
	mkdir -p Gauss/8G/hmm21
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/8G/hmm20/macros -H Gauss/8G/hmm20/hmmdefs -M Gauss/8G/hmm21 monophones1
	mkdir -p Gauss/8G/hmm22
 	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/8G/hmm21/macros -H Gauss/8G/hmm21/hmmdefs -M Gauss/8G/hmm22 monophones1
	mkdir -p Gauss/8G/hmm23
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/8G/hmm22/macros -H Gauss/8G/hmm22/hmmdefs -M Gauss/8G/hmm23 monophones1
	mkdir -p Gauss/8G/hmm24
 	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/8G/hmm23/macros -H Gauss/8G/hmm23/hmmdefs -M Gauss/8G/hmm24 monophones1
	#16 Gaussian model
	echo "MU 16 {*.state[2-4].mix}" >> Gauss/16G/16gaussian
	mkdir -p Gauss/16G/hmm25
	HHEd -A -T 1 -H Gauss/8G/hmm24/macros -H Gauss/8G/hmm24/hmmdefs -M Gauss/16G/hmm25 Gauss/16G/16gaussian monophones1
	mkdir -p Gauss/16G/hmm26
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/16G/hmm25/macros -H Gauss/16G/hmm25/hmmdefs -M Gauss/16G/hmm26 monophones1
	mkdir -p Gauss/16G/hmm27
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/16G/hmm26/macros -H Gauss/16G/hmm26/hmmdefs -M Gauss/16G/hmm27 monophones1
	mkdir -p Gauss/16G/hmm28
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/16G/hmm27/macros -H Gauss/16G/hmm27/hmmdefs -M Gauss/16G/hmm28 monophones1
	mkdir -p Gauss/16G/hmm29
	HERest -A -T 1 -C configmf -I new_aligned.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/16G/hmm28/macros -H Gauss/16G/hmm28/hmmdefs -M Gauss/16G/hmm29 monophones1

}


###############################create triphone################################
#      				
##############################################################################
function create_triphone {

	cat > mktri.led <<- EOM
	WB sp
	WB sil
	TC
	EOM

	HLEd -n triphones1 -l '*' -i wintri.mlf mktri.led phones1.mlf
	perl maketrihed monophones1 triphones1 > mktri.hed
	mkdir -p Gauss/hmm30
	HHEd -A -T 1 -H Gauss/16G/hmm29/macros -H Gauss/16G/hmm29/hmmdefs -M Gauss/hmm30 mktri.hed monophones1
	mkdir -p Gauss/hmm31
	HERest -A -T 1 -C configmf -I wintri.mlf -t 250.0 150.0 1000.0 -s Gauss/stats26 -S tidigitmfc.scp -H Gauss/hmm30/macros -H Gauss/hmm30/hmmdefs -M Gauss/hmm31 triphones1
	mkdir -p Gauss/hmm32
	HERest -A -T 1 -C configmf -I wintri.mlf -t 250.0 150.0 1000.0 -s Gauss/stats27 -S tidigitmfc.scp -H Gauss/hmm31/macros -H Gauss/hmm31/hmmdefs -M Gauss/hmm32 triphones1

	perl mkclscript.prl TC 350 monophones1 > Gauss/treetmp
cat > Gauss/tree.hed <<- EOM
RO 100.0 stats
TR 0
QS  "R_NonBoundary"	{ *+* }
QS  "R_Silence"		{ *+sil }
QS  "R_Stop"		{ *+p,*+pd,*+b,*+t,*+td,*+d,*+dd,*+k,*+kd,*+g }
QS  "R_Nasal"		{ *+m,*+n,*+en,*+ng }
QS  "R_Fricative"	{ *+s,*+sh,*+z,*+f,*+v,*+ch,*+jh,*+th,*+dh }
QS  "R_Liquid"		{ *+l,*+el,*+r,*+w,*+y,*+hh }
QS  "R_Vowel"		{ *+eh,*+ih,*+ao,*+aa,*+uw,*+ah,*+ax,*+er,*+ay,*+oy,*+ey,*+iy,*+ow }
QS  "R_C-Front"		{ *+p,*+pd,*+b,*+m,*+f,*+v,*+w }
QS  "R_C-Central"	{ *+t,*+td,*+d,*+dd,*+en,*+n,*+s,*+z,*+sh,*+th,*+dh,*+l,*+el,*+r }
QS  "R_C-Back"		{ *+sh,*+ch,*+jh,*+y,*+k,*+kd,*+g,*+ng,*+hh }
QS  "R_V-Front"		{ *+iy,*+ih,*+eh }
QS  "R_V-Central"	{ *+eh,*+aa,*+er,*+ao }
QS  "R_V-Back"		{ *+uw,*+aa,*+ax,*+uh }
QS  "R_Front"		{ *+p,*+pd,*+b,*+m,*+f,*+v,*+w,*+iy,*+ih,*+eh }
QS  "R_Central"		{ *+t,*+td,*+d,*+dd,*+en,*+n,*+s,*+z,*+sh,*+th,*+dh,*+l,*+el,*+r,*+eh,*+aa,*+er,*+ao }
QS  "R_Back"		{ *+sh,*+ch,*+jh,*+y,*+k,*+kd,*+g,*+ng,*+hh,*+aa,*+uw,*+ax,*+uh }
QS  "R_Fortis"		{ *+p,*+pd,*+t,*+td,*+k,*+kd,*+f,*+th,*+s,*+sh,*+ch }
QS  "R_Lenis"		{ *+b,*+d,*+dd,*+g,*+v,*+dh,*+z,*+sh,*+jh }
QS  "R_UnFortLenis"	{ *+m,*+n,*+en,*+ng,*+hh,*+l,*+el,*+r,*+y,*+w }
QS  "R_Coronal"		{ *+t,*+td,*+d,*+dd,*+n,*+en,*+th,*+dh,*+s,*+z,*+sh,*+ch,*+jh,*+l,*+el,*+r }
QS  "R_NonCoronal"	{ *+p,*+pd,*+b,*+m,*+k,*+kd,*+g,*+ng,*+f,*+v,*+hh,*+y,*+w }
QS  "R_Anterior"	{ *+p,*+pd,*+b,*+m,*+t,*+td,*+d,*+dd,*+n,*+en,*+f,*+v,*+th,*+dh,*+s,*+z,*+l,*+el,*+w }
QS  "R_NonAnterior"	{ *+k,*+kd,*+g,*+ng,*+sh,*+hh,*+ch,*+jh,*+r,*+y }
QS  "R_Continuent"	{ *+m,*+n,*+en,*+ng,*+f,*+v,*+th,*+dh,*+s,*+z,*+sh,*+hh,*+l,*+el,*+r,*+y,*+w }
QS  "R_NonContinuent"	{ *+p,*+pd,*+b,*+t,*+td,*+d,*+dd,*+k,*+kd,*+g,*+ch,*+jh }
QS  "R_Strident"	{ *+s,*+z,*+sh,*+ch,*+jh }
QS  "R_NonStrident"	{ *+f,*+v,*+th,*+dh,*+hh }
QS  "R_UnStrident"	{ *+p,*+pd,*+b,*+m,*+t,*+td,*+d,*+dd,*+n,*+en,*+k,*+kd,*+g,*+ng,*+l,*+el,*+r,*+y,*+w }
QS  "R_Glide"		{ *+hh,*+l,*+el,*+r,*+y,*+w }
QS  "R_Syllabic"	{ *+en,*+m,*+l,*+el,*+er }
QS  "R_Unvoiced-Cons"	{ *+p,*+pd,*+t,*+td,*+k,*+kd,*+s,*+sh,*+f,*+th,*+hh,*+ch }
QS  "R_Voiced-Cons"	{ *+jh,*+b,*+d,*+dd,*+dh,*+g,*+y,*+l,*+el,*+m,*+n,*+en,*+ng,*+r,*+v,*+w,*+z }
QS  "R_Unvoiced-All"	{ *+p,*+pd,*+t,*+td,*+k,*+kd,*+s,*+sh,*+f,*+th,*+hh,*+ch,*+sil }
QS  "R_Long"		{ *+iy,*+aa,*+ow,*+ao,*+uw,*+en,*+m,*+l,*+el }
QS  "R_Short"		{ *+eh,*+ey,*+aa,*+ih,*+ay,*+oy,*+ah,*+ax,*+uh }
QS  "R_Dipthong"	{ *+ey,*+ay,*+oy,*+aa,*+er,*+en,*+m,*+l,*+el }
QS  "R_Front-Start"	{ *+ey,*+aa,*+er }
QS  "R_Fronting"	{ *+ay,*+ey,*+oy }
QS  "R_High"		{ *+ih,*+uw,*+aa,*+ax,*+iy }
QS  "R_Medium"		{ *+ey,*+er,*+aa,*+ax,*+eh,*+en,*+m,*+l,*+el }
QS  "R_Low"		{ *+eh,*+ay,*+aa,*+aw,*+ao,*+oy }
QS  "R_Rounded"		{ *+ao,*+uw,*+aa,*+ax,*+oy,*+w }
QS  "R_Unrounded"	{ *+eh,*+ih,*+aa,*+er,*+ay,*+ey,*+iy,*+aw,*+ah,*+ax,*+en,*+m,*+hh,*+l,*+el,*+r,*+y }
QS  "R_NonAffricate"	{ *+s,*+sh,*+z,*+f,*+v,*+th,*+dh }
QS  "R_Affricate"	{ *+ch,*+jh }
QS  "R_IVowel"		{ *+ih,*+iy }
QS  "R_EVowel"		{ *+eh,*+ey }
QS  "R_AVowel"		{ *+eh,*+aa,*+er,*+ay,*+aw }
QS  "R_OVowel"		{ *+ao,*+oy,*+aa }
QS  "R_UVowel"		{ *+aa,*+ax,*+en,*+m,*+l,*+el,*+uw }
QS  "R_Voiced-Stop"	{ *+b,*+d,*+dd,*+g }
QS  "R_Unvoiced-Stop"	{ *+p,*+pd,*+t,*+td,*+k,*+kd }
QS  "R_Front-Stop"	{ *+p,*+pd,*+b }
QS  "R_Central-Stop"	{ *+t,*+td,*+d,*+dd }
QS  "R_Back-Stop"	{ *+k,*+kd,*+g }
QS  "R_Voiced-Fric"	{ *+z,*+sh,*+dh,*+ch,*+v }
QS  "R_Unvoiced-Fric"	{ *+s,*+sh,*+th,*+f,*+ch }
QS  "R_Front-Fric"	{ *+f,*+v }
QS  "R_Central-Fric"	{ *+s,*+z,*+th,*+dh }
QS  "R_Back-Fric"	{ *+sh,*+ch,*+jh }
QS  "R_aa"		{ *+aa }
QS  "R_ae"		{ *+ae }
QS  "R_ah"		{ *+ah }
QS  "R_ao"		{ *+ao }
QS  "R_aw"		{ *+aw }
QS  "R_ax"		{ *+ax }
QS  "R_ay"		{ *+ay }
QS  "R_b"		{ *+b }
QS  "R_ch"		{ *+ch }
QS  "R_d"		{ *+d }
QS  "R_dd"		{ *+dd }
QS  "R_dh"		{ *+dh }
QS  "R_dx"		{ *+dx }
QS  "R_eh"		{ *+eh }
QS  "R_el"		{ *+el }
QS  "R_en"		{ *+en }
QS  "R_er"		{ *+er }
QS  "R_ey"		{ *+ey }
QS  "R_f"		{ *+f }
QS  "R_g"		{ *+g }
QS  "R_hh"		{ *+hh }
QS  "R_ih"		{ *+ih }
QS  "R_iy"		{ *+iy }
QS  "R_jh"		{ *+jh }
QS  "R_k"		{ *+k }
QS  "R_kd"		{ *+kd }
QS  "R_l"		{ *+l }
QS  "R_m"		{ *+m }
QS  "R_n"		{ *+n }
QS  "R_ng"		{ *+ng }
QS  "R_ow"		{ *+ow }
QS  "R_oy"		{ *+oy }
QS  "R_p"		{ *+p }
QS  "R_pd"		{ *+pd }
QS  "R_r"		{ *+r }
QS  "R_s"		{ *+s }
QS  "R_sh"		{ *+sh }
QS  "R_t"		{ *+t }
QS  "R_td"		{ *+td }
QS  "R_th"		{ *+th }
QS  "R_ts"		{ *+ts }
QS  "R_uh"		{ *+uh }
QS  "R_uw"		{ *+uw }
QS  "R_v"		{ *+v }
QS  "R_w"		{ *+w }
QS  "R_y"		{ *+y }
QS  "R_z"		{ *+z }
QS  "L_NonBoundary"	{ *-* }
QS  "L_Silence"		{ sil-* }
QS  "L_Stop"		{ p-*,pd-*,b-*,t-*,td-*,d-*,dd-*,k-*,kd-*,g-* }
QS  "L_Nasal"		{ m-*,n-*,en-*,ng-* }
QS  "L_Fricative"	{ s-*,sh-*,z-*,f-*,v-*,ch-*,jh-*,th-*,dh-* }
QS  "L_Liquid"		{ l-*,el-*,r-*,w-*,y-*,hh-* }
QS  "L_Vowel"		{ eh-*,ih-*,ao-*,aa-*,uw-*,ah-*,ax-*,er-*,ay-*,oy-*,ey-*,iy-*,ow-* }
QS  "L_C-Front"		{ p-*,pd-*,b-*,m-*,f-*,v-*,w-* }
QS  "L_C-Central"	{ t-*,td-*,d-*,dd-*,en-*,n-*,s-*,z-*,sh-*,th-*,dh-*,l-*,el-*,r-* }
QS  "L_C-Back"		{ sh-*,ch-*,jh-*,y-*,k-*,kd-*,g-*,ng-*,hh-* }
QS  "L_V-Front"		{ iy-*,ih-*,eh-* }
QS  "L_V-Central"	{ eh-*,aa-*,er-*,ao-* }
QS  "L_V-Back"		{ uw-*,aa-*,ax-*,uh-* }
QS  "L_Front"		{ p-*,pd-*,b-*,m-*,f-*,v-*,w-*,iy-*,ih-*,eh-* }
QS  "L_Central"		{ t-*,td-*,d-*,dd-*,en-*,n-*,s-*,z-*,sh-*,th-*,dh-*,l-*,el-*,r-*,eh-*,aa-*,er-*,ao-* }
QS  "L_Back"		{ sh-*,ch-*,jh-*,y-*,k-*,kd-*,g-*,ng-*,hh-*,aa-*,uw-*,ax-*,uh-* }
QS  "L_Fortis"		{ p-*,pd-*,t-*,td-*,k-*,kd-*,f-*,th-*,s-*,sh-*,ch-* }
QS  "L_Lenis"		{ b-*,d-*,dd-*,g-*,v-*,dh-*,z-*,sh-*,jh-* }
QS  "L_UnFortLenis"	{ m-*,n-*,en-*,ng-*,hh-*,l-*,el-*,r-*,y-*,w-* }
QS  "L_Coronal"		{ t-*,td-*,d-*,dd-*,n-*,en-*,th-*,dh-*,s-*,z-*,sh-*,ch-*,jh-*,l-*,el-*,r-* }
QS  "L_NonCoronal"	{ p-*,pd-*,b-*,m-*,k-*,kd-*,g-*,ng-*,f-*,v-*,hh-*,y-*,w-* }
QS  "L_Anterior"	{ p-*,pd-*,b-*,m-*,t-*,td-*,d-*,dd-*,n-*,en-*,f-*,v-*,th-*,dh-*,s-*,z-*,l-*,el-*,w-* }
QS  "L_NonAnterior"	{ k-*,kd-*,g-*,ng-*,sh-*,hh-*,ch-*,jh-*,r-*,y-* }
QS  "L_Continuent"	{ m-*,n-*,en-*,ng-*,f-*,v-*,th-*,dh-*,s-*,z-*,sh-*,hh-*,l-*,el-*,r-*,y-*,w-* }
QS  "L_NonContinuent"	{ p-*,pd-*,b-*,t-*,td-*,d-*,dd-*,k-*,kd-*,g-*,ch-*,jh-* }
QS  "L_Strident"	{ s-*,z-*,sh-*,ch-*,jh-* }
QS  "L_NonStrident"	{ f-*,v-*,th-*,dh-*,hh-* }
QS  "L_UnStrident"	{ p-*,pd-*,b-*,m-*,t-*,td-*,d-*,dd-*,n-*,en-*,k-*,kd-*,g-*,ng-*,l-*,el-*,r-*,y-*,w-* }
QS  "L_Glide"		{ hh-*,l-*,el-*,r-*,y-*,w-* }
QS  "L_Syllabic"	{ en-*,m-*,l-*,el-*,er-* }
QS  "L_Unvoiced-Cons"	{ p-*,pd-*,t-*,td-*,k-*,kd-*,s-*,sh-*,f-*,th-*,hh-*,ch-* }
QS  "L_Voiced-Cons"	{ jh-*,b-*,d-*,dd-*,dh-*,g-*,y-*,l-*,el-*,m-*,n-*,en-*,ng-*,r-*,v-*,w-*,z-* }
QS  "L_Unvoiced-All"	{ p-*,pd-*,t-*,td-*,k-*,kd-*,s-*,sh-*,f-*,th-*,hh-*,ch-*,sil-* }
QS  "L_Long"		{ iy-*,aa-*,ow-*,ao-*,uw-*,en-*,m-*,l-*,el-* }
QS  "L_Short"		{ eh-*,ey-*,aa-*,ih-*,ay-*,oy-*,ah-*,ax-*,uh-* }
QS  "L_Dipthong"	{ ey-*,ay-*,oy-*,aa-*,er-*,en-*,m-*,l-*,el-* }
QS  "L_Front-Start"	{ ey-*,aa-*,er-* }
QS  "L_Fronting"	{ ay-*,ey-*,oy-* }
QS  "L_High"		{ ih-*,uw-*,aa-*,ax-*,iy-* }
QS  "L_Medium"		{ ey-*,er-*,aa-*,ax-*,eh-*,en-*,m-*,l-*,el-* }
QS  "L_Low"		{ eh-*,ay-*,aa-*,aw-*,ao-*,oy-* }
QS  "L_Rounded"		{ ao-*,uw-*,aa-*,ax-*,oy-*,w-* }
QS  "L_Unrounded"	{ eh-*,ih-*,aa-*,er-*,ay-*,ey-*,iy-*,aw-*,ah-*,ax-*,en-*,m-*,hh-*,l-*,el-*,r-*,y-* }
QS  "L_NonAffricate"	{ s-*,sh-*,z-*,f-*,v-*,th-*,dh-* }
QS  "L_Affricate"	{ ch-*,jh-* }
QS  "L_IVowel"		{ ih-*,iy-* }
QS  "L_EVowel"		{ eh-*,ey-* }
QS  "L_AVowel"		{ eh-*,aa-*,er-*,ay-*,aw-* }
QS  "L_OVowel"		{ ao-*,oy-*,aa-* }
QS  "L_UVowel"		{ aa-*,ax-*,en-*,m-*,l-*,el-*,uw-* }
QS  "L_Voiced-Stop"	{ b-*,d-*,dd-*,g-* }
QS  "L_Unvoiced-Stop"	{ p-*,pd-*,t-*,td-*,k-*,kd-* }
QS  "L_Front-Stop"	{ p-*,pd-*,b-* }
QS  "L_Central-Stop"	{ t-*,td-*,d-*,dd-* }
QS  "L_Back-Stop"	{ k-*,kd-*,g-* }
QS  "L_Voiced-Fric"	{ z-*,sh-*,dh-*,ch-*,v-* }
QS  "L_Unvoiced-Fric"	{ s-*,sh-*,th-*,f-*,ch-* }
QS  "L_Front-Fric"	{ f-*,v-* }
QS  "L_Central-Fric"	{ s-*,z-*,th-*,dh-* }
QS  "L_Back-Fric"	{ sh-*,ch-*,jh-* }
QS  "L_aa"		{ aa-* }
QS  "L_ae"		{ ae-* }
QS  "L_ah"		{ ah-* }
QS  "L_ao"		{ ao-* }
QS  "L_aw"		{ aw-* }
QS  "L_ax"		{ ax-* }
QS  "L_ay"		{ ay-* }
QS  "L_b"		{ b-* }
QS  "L_ch"		{ ch-* }
QS  "L_d"		{ d-* }
QS  "L_dd"		{ dd-* }
QS  "L_dh"		{ dh-* }
QS  "L_dx"		{ dx-* }
QS  "L_eh"		{ eh-* }
QS  "L_el"		{ el-* }
QS  "L_en"		{ en-* }
QS  "L_er"		{ er-* }
QS  "L_ey"		{ ey-* }
QS  "L_f"		{ f-* }
QS  "L_g"		{ g-* }
QS  "L_hh"		{ hh-* }
QS  "L_ih"		{ ih-* }
QS  "L_iy"		{ iy-* }
QS  "L_jh"		{ jh-* }
QS  "L_k"		{ k-* }
QS  "L_kd"		{ kd-* }
QS  "L_l"		{ l-* }
QS  "L_m"		{ m-* }
QS  "L_n"		{ n-* }
QS  "L_ng"		{ ng-* }
QS  "L_ow"		{ ow-* }
QS  "L_oy"		{ oy-* }
QS  "L_p"		{ p-* }
QS  "L_pd"		{ pd-* }
QS  "L_r"		{ r-* }
QS  "L_s"		{ s-* }
QS  "L_sh"		{ sh-* }
QS  "L_t"		{ t-* }
QS  "L_td"		{ td-* }
QS  "L_th"		{ th-* }
QS  "L_ts"		{ ts-* }
QS  "L_uh"		{ uh-* }
QS  "L_uw"		{ uw-* }
QS  "L_v"		{ v-* }
QS  "L_w"		{ w-* }
QS  "L_y"		{ y-* }
QS  "L_z"		{ z-* }
TR 1
EOM

cat Gauss/treetmp >> Gauss/tree.hed
	#TODO check if this step is correct
cat >> Gauss/tree.hed <<- EOM
TR 2
CO "tiedlist"
ST "trees"
EOM
	mkdir -p Gauss/hmm33
	HHEd -A -T 1 -H Gauss/hmm32/macros -H Gauss/hmm32/hmmdefs -M Gauss/hmm33 Gauss/tree.hed triphones1
	mkdir -p Gauss/hmm34
	HERest -A -T 1 -C configmf -I wintri.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/hmm33/macros -H Gauss/hmm33/hmmdefs -M Gauss/hmm34 tiedlist
	mkdir -p Gauss/hmm35
	HERest -A -T 1 -C configmf -I wintri.mlf -t 250.0 150.0 1000.0 -S tidigitmfc.scp -H Gauss/hmm34/macros -H Gauss/hmm34/hmmdefs -M Gauss/hmm35 tiedlist


}
##############################################################################
#front end menu
PS3='Please enter your choice: '
options=("Create prompt.txt" "Create word list" "Create word.mlf" "Create phones0.mlf" "Create phones1.mlf" "Create mfcc" "Create hmm0_3"   "Create SIL states" "Realign" "Create GMM" "Create triphone" "Execute all"  "Quit")

select opt in "${options[@]}"
do
    case $opt in
        "Create prompt.txt")
            echo "You have chosen to create prompt.txt"
	    create_prompt #call create prompt function	
	    ;;
        "Create word list")
            echo "you have chosen to create wordlist"
	    create_wdlist #call create wdlist function
            ;;
        "Create word.mlf")
            echo "you chosen to create word.mlf"
	    create_wdmlf
	    ;;
        "Create phones0.mlf")
            echo "you chosen to create phones0.mlf"
	    create_phones0mlf
            ;;
	"Create phones1.mlf")
            echo "you chosen to create phones1.mlf"
	    create_phones1mlf
            ;;
	"Create mfcc")
            echo "you chosen to create mfcc"
	    create_mfcc
            ;;
	"Create hmm0_3")
            echo "you chosen to create hmm 0 - 3"
	    create_hmm0_3
            ;;
	"Create SIL states")
            echo "you have chosen to create silence states"
	    create_sil
            ;;
	"Realign")
            echo "you have chosen to realign"
	    realign
            ;;
	"Create GMM")
            echo "you have chosen to create GMM"
	    gmm
            ;;
	"Create triphone")
            echo "you have chosen to create triphone models"
	    create_triphone
            ;;
	"Execute all")
            echo "All steps will be executed"
	    create_prompt
	    create_wdlist
	    create_wdmlf
	    create_phones0mlf
	    create_phones1mlf
	    create_mfcc
	    create_hmm0_3
	    create_sil
	    realign
	    create_triphone
            ;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done

#################################End of file##################################
