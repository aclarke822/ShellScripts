#!/bin/sh
################################################################################################################
## SCRIPT NAME      : E2FileGrabber.sh
## SYSTEM           : UFMS
## AUTHOR           : Larry Neese <larry.neese@usdoj.gov>
## DATE WRITTEN     : 11/10/2022
##
## PURPOSE          : Automatically finds, moves, and archives E2 files given filenames as parameters.
##
## PROGRAMMER NOTES : This script takes any number of filenames as parameters
##
##					  Credit to Austine Clarke and Trey Devillier for assistance with debugging
## CHANGE HISTORY
## MM/DD/YYYY
################################################################################################################

##Establish month name array and folder name
set -A monthnames Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
MOVEDIR="/k8c/ufms/tmp/atc"

#Dictionary mapping, only works in Bash v4+. Bash v4+ is on the AIX LPARs. With line 1, could use bash instead of sh
#declare -A monthNames=( ["01"]="Jan" ["02"]="Feb" ["03"]="Mar" ["04"]="Apr" ["05"]="May" ["06"]="Jun" ["07"]="Jul" ["08"]="Aug" ["09"]="Sep" ["10"]="Oct" ["11"]="Nov" ["12"]="Dec" )
#MONTHNAME="${monthNames[$MONTHNUM]}"
#No need to format $MONTHNUM for array. Just FYI, maybe not worth it for this script but other scripts may be able to make use of it.

FindAndCopyFile()
{
    SEARCHLOCATION=$1
    FILENAME=$2
    DESTDIR=$3
  
    echo "Searching $SEARCHLOCATION"
    if [ -f "$SEARCHLOCATION/$FILENAME" ]; then
        cp "$SEARCHLOCATION/$FILENAME" ${DESTDIR}
        echo "$FILENAME found, copying to ${DESTDIR}."
        return true
    else
        echo "$FILENAME not found."
        return false
    fi
}

FindAndCopyFileTar()
{
    SEARCHLOCATION=$1
    FILENAME=$2
    DESTDIR=$3
    TARFILENAME=$4

    tar -tf $TARFILENAME | grep ${FILENAME} > /dev/null
    if [ "$?" == "0" ]; then
        echo "Looking in $TARFILENAME"
        TARFILE=$(tar -tvf $TARFILENAME | grep $FILENAME)
        TARFILE=$(echo $TARFILE | sed 's/\ /\//g')
        TARFILE=$(echo "$TARFILE" | cut -d"/" -f9)
        tar -xvf "$TARFILENAME" "$TARFILE"  > /dev/null
        mv *${FILENAME}* ${DESTDIR}  > /dev/null
        echo "$TARFILE found, extracting and moving to $DESTDIR"
        return true
    else
        echo "File not found in $TARFILENAME."
        return false
    fi
}

FindAndCopyFileTarGz()
{
    SEARCHLOCATION=$1
    FILENAME=$2
    DESTDIR=$3
    TARGZFILENAME=$4

    gzip -cd $TARGZFILENAME | tar -tvf - | grep "${FILENAME}" > /dev/null
    if [ "$?" == "0" ]; then
        TARFILE=$(gzip -cd ${TARGZFILENAME} | tar -tvf - | grep "${FILENAME}")
        TARFILE=$(echo ${TARFILE} | sed 's/\ /\//g')
        TARFILE=$(echo "$TARFILE" | cut -d"/" -f9)
        gzip -cd ${TARGZFILENAME} | tar -xvf - "${TARFILE}" > /dev/null
        mv *${FILENAME}* ${DESTDIR} > /dev/null
        echo "$TARFILE found, extracting and moving to $DESTDIR"
        return true
    else
        echo "File not found in $TARGZFILENAME."
        return false
    fi
}

##Loops through filename parameters
while [ ! -z "$1" ]; do
	FILETOFIND=${1}

	echo "Searching for ${FILETOFIND}, this may take awhile..."
	shift
	echo $

    DATENUM=$(echo "$FILETOFIND" | cut -d"_" -f4)

    YEARNUM=$(echo "$DATENUM" | awk '{print substr($0,1,2)}')
    MONTHNUM=$(echo "$DATENUM" | awk '{print substr($0,3,2)}'  | awk '{sub(/^0*/,"");}1')
    DAYNUM=$(echo "$DATENUM" | awk '{print substr($0,5,2)}')

    MONTHNAME=${monthnames[${"$((MONTHNUM - 1))"}]}
    TARFILENAME=${MONTHNAME}"20"${YEARNUM}.tar
    TARGZFILENAME=${TARBALL}".gz"

	if [[ ${FILETOFIND} == *"STATUS"* ]]; then
		SEARCHLOCATION1="/k8g/appprod79/application/ufintg/root/INTERFACE/E2/OUT/STATUSUPDATE"
		SEARCHLOCATION2="/k8g/appprod79/application/ufintg/root/ARCHIVE/E2/OUT/STATUSUPDATE"
		
        if FindAndCopyFile $SEARCHLOCATION1 $FILETOFIND $MOVEDIR; then continue; fi
        if FindAndCopyFile $SEARCHLOCATION2 $FILETOFIND $MOVEDIR; then continue; fi
        
        if [ -f "$SEARCHLOCATION2/$TARFILENAME" ]; then
            if FindAndCopyFileTar $SEARCHLOCATION3 $FILETOFIND $MOVEDIR $TARFILENAME; then continue; fi
        elif [ -f "$SEARCHLOCATION2/$TARGZFILENAME" ]; then
            if FindAndCopyFileTarGz $SEARCHLOCATION3 $FILETOFIND $MOVEDIR $TARGZFILENAME; then continue; fi
        else 
            echo "Neither Tar nor TarGz found."
        fi
        
	elif [[ ${FILETOFIND} == *"err"* ]]; then
		SEARCHLOCATION1="/k8g/appprod79/application/ufintg/root/INTERFACE/E2/IN/ERROR"
		SEARCHLOCATION2="/k8g/appprod79/application/ufintg/root/ARCHIVE/E2/IN/ERROR"
		
        if FindAndCopyFile $SEARCHLOCATION1 $FILETOFIND $MOVEDIR; then continue; fi
        if FindAndCopyFile $SEARCHLOCATION2 $FILETOFIND $MOVEDIR; then continue; fi

	else
		SEARCHLOCATION1="/k8g/appprod79/application/ufintg/root/INTERFACE/E2/IN/TRANSACTIONS"
		SEARCHLOCATION2="/k8g/appprod79/application/ufintg/root/ARCHIVE/E2/IN/ERROR"
		SEARCHLOCATION3="/k8g/appprod79/application/ufintg/root/ARCHIVE/E2/IN/TRANSACTIONS"

		if FindAndCopyFile $SEARCHLOCATION1 $FILETOFIND $MOVEDIR; then continue; fi
        if FindAndCopyFile $SEARCHLOCATION2 $FILETOFIND $MOVEDIR; then continue; fi
        if FindAndCopyFile $SEARCHLOCATION3 $FILETOFIND $MOVEDIR; then continue; fi

        if [ -f "$SEARCHLOCATION3/$TARFILENAME" ]; then
            if FindAndCopyFileTar $SEARCHLOCATION3 $FILETOFIND $MOVEDIR $TARFILENAME; then continue; fi
        elif [ -f "$SEARCHLOCATION3/$TARGZFILENAME" ]; then
            if FindAndCopyFileTarGz $SEARCHLOCATION3 $FILETOFIND $MOVEDIR $TARGZFILENAME; then continue; fi
        else 
            echo "Neither Tar nor TarGz found."
        fi
	fi
    
    echo "$FILETOFIND not found."
done

Archives found files
cd ${MOVEDIR}
echo "Creating archive E2Files.zip in ${MOVEDIR}"
zip -q E2Files.zip *
rm !("E2Files.zip")