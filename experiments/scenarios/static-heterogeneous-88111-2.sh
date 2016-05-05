#echo "*** Setuping up ***"
#setCpus vm-rubis-0 8
#setCpus vm-rubis-1 8
#setCpus vm-rubis-2 1
#setCpus vm-rubis-3 1
#setCpus vm-rubis-4 1
#sleep 10 # let system settle

echo "*** Running experiments ***"
setStart
setCount 120000
setOpen 1
setThinkTime 5
setConcurrency 2000
#sleep 60
sleep 10 # to let requests finish
