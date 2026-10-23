source /opt/tecoai/setvars.sh

err=0
testList=$(ls)

for p in ${testList}; do
  if [ -d $p ]; then
    cd $p
    make clean
    make all
    testexelist=$(ls *.out)
	for testexe in ${testexelist}; do
	  ./${testexe}
      if [ $? -ne 0 ]; then ((err++)); fi
	done
    cd ..
  fi
done

if [ ${err} == 0 ]; then
  echo "TOTAL CASE SUCCESS !!"
  exit 0
else
  echo "EXIST FAILURE !!"
  exit 1
fi
