#!/bin/bash 
echo "*****************************************************"
echo "this is post build!! current configure is :$1"
tc32-elf-objcopy -v -O binary $2.elf  $1.bin
../../$3/tl_check_fw.exe  $1.bin
echo "**************** end of post build ******************"