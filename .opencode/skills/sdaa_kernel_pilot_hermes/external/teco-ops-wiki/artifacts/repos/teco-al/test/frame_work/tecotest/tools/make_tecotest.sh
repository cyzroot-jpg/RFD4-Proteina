set -e
root=$(dirname "$PWD") 

pip3 install -r requirements.txt

cd $root
source env.sh
bash build.sh
