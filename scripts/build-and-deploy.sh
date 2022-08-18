SCRDIR='../src/lambdas/cmd'
OUTDIR='../src/lambdas/bin'
ZIPDIR='../src/lambdas/archive'

mkdir "${OUTDIR}"
mkdir "${ZIPDIR}"

functions=`ls ${SCRDIR} | grep lmb-`
for i in $functions
do
  echo "Found Lambda project: $i"
  _cwd="$PWD"
  cd "${SCRDIR}/${i}"
  buildstatus=$(GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags '-s -w' -o ${_cwd}/${OUTDIR}/${i}/${i} )
  cd "${_cwd}"
  zip "${ZIPDIR}/${i}.zip" "${OUTDIR}/${i}/"
done


cd ../deploy
terraform init 
terraform plan 
terraform apply
cd ..
