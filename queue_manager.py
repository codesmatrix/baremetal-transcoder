import os
import sys
import shlex
import subprocess as subp
import logging
from datetime import datetime

#settings global variable
transcodeddir="vidfs"


if __name__ == "__main__":
	logging.basicConfig(level=logging.DEBUG, filename="transcode_log", filemode="a+",format="%(asctime)-15s %(levelname)-8s %(message)s")
	logging.info("=====================================")
	logging.info("hello. manager starting..")

def queue_manage():

	#open queue file
	with open("transcode_queue", "r") as f:
		topline = f.readline()
		temp = topline

		#quit if end of line
		if topline=="":
			print "Py: Reached end of queue file. Exiting Transcoding Manager."
			sys.exit()

	#check if already dir exist
	cr = os.path.join(transcodeddir, os.path.splitext(temp)[0])
	if os.path.isdir(cr):
		prints = "Py - Looks like dir is already there. Unix shell will skip : "+topline
		print prints
		logging.info(prints)

	# execute first queued video for transcoding 
	prints = "Py - Executing transcode on: "+topline
	print prints
	logging.info(prints)
	subp.call(["./tscode-mp4hls-mp4dash.sh", topline, transcodeddir])
	prints = "Py - I am done with: "+topline
	print prints
	logging.info(prints)

	#check if transcodes are created
	#linebase is each individual video element id base folder 
	linebase_fe= topline
	linebase = os.path.splitext(linebase_fe)[0]

	dashbase="dash"
	hlsbase="hls-media"


	dashfile3=os.path.join(transcodeddir, linebase, dashbase, linebase+"-360p_dashinit.mp4")
	dashfile4=os.path.join(transcodeddir, linebase, dashbase, linebase+"-480p_dashinit.mp4")
	dashfile7=os.path.join(transcodeddir, linebase, dashbase, linebase+"-720p_dashinit.mp4")
	dashfile10=os.path.join(transcodeddir, linebase, dashbase, linebase+"-1080p_dashinit.mp4")
	dashfileM=os.path.join(transcodeddir, linebase, dashbase, linebase+".mpd")

	hlsfile3=os.path.join(transcodeddir, linebase, hlsbase, "media-1", "stream.m3u8")
	hlsfile4=os.path.join(transcodeddir, linebase, hlsbase, "media-2", "stream.m3u8")
	hlsfile7=os.path.join(transcodeddir, linebase, hlsbase, "media-3", "stream.m3u8")
	hlsfile10=os.path.join(transcodeddir, linebase, hlsbase, "media-4", "stream.m3u8")
	hlsfileM=os.path.join(transcodeddir, linebase, hlsbase, "playlist.m3u8")

	listd = [dashfile3, dashfile4, dashfile7, dashfile10, dashfileM, hlsfile3, hlsfile4, hlsfile7, hlsfile10, hlsfileM]
	#print listd
	#check for generated files. if exists good trnascoding.
	errorcount=0
	for elem in listd:
		if os.path.exists(elem):
			prints = elem+" exists. Check."
			print prints
			logging.info(prints)
		else:
			errorcount+=1
			prints = elem+" doesnt exists. Wrong."
			print prints
			logging.info(prints)

	prints = "errcount: "+str(errorcount)
	print prints
	logging.info(prints)

	#delete top queue if complete success
	if errorcount==0:
		prints = "i am gonna delete top queue id: "+topline
		print prints
		logging.info(prints)
		command = shlex.split("sed -i '1d' transcode_queue")
		subp.call(command)
	else:
		prints = "saving this item into partial list. file id: "+topline
		print prints
		logging.info(prints)
		#append to partial list
		with open("partial.list", "a") as f:
			f.write("\nPartial")
			err=("\nError count: "+str(errorcount)+" File Id: "+topline)
			timestamp = datetime.now()
			f.write(str(timestamp)+err)
			logging.error(err)
		#clear partial queue item
		command2=shlex.split("sed -i '1d' transcode_queue")
		subp.call(command2)

	#run this program pseudo recursively until quit condition
	queue_manage()


#run main driver program
queue_manage()
