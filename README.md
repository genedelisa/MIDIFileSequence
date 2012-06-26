MIDIFileSequence
======

Core Audio example from my [Blog Post](http://rockhoppertech.com/blog/ios-midifile-sequence/ "Blog post") 


What is MIDIFileSequence?
---------------
This is an iOS 5 app that will set up an Audio Unit graph with a sampler Audio Unit and a RemoteIO unit. It uses a MusicPlayer to play a MusicSequence that is loaded from a file.

The audio frobs are all in GDSoundEngine. The UI classes know nothing about any of the audio stuff. The controller gets a cookie to the sound engine and asks it to do any audio tasks.

The UI is a single button which plays a standard MIDI file.
 
The graph is as simple as possible; the sampler unit feeding directly into the RemoteIO unit. 

The sound played is from the DLS file and/or a SountFont2 that you copied into the project bundle and specified in GDSoundEngine's setupSampler method.
You can use the gs_instruments.dls file that is probably already on your mac, or download one.

I've specified (but not included) one MIDI file from the [Buzzwood MIDI Voice Tester](http://www.personalcopy.com/home.htm) page. There are several more files there. The footer of the page says "Copying/distribution is prohibited", so I'm pointing you there instead of giving you one of the files. Or, use one of your own!

All errors are checked using a modified version of Chris Adamson's CheckError function.
Get his [book](http://www.amazon.com/gp/product/0321636848/ref=as_li_ss_tl?ie=UTF8&tag=httpwwwrockhc-20&linkCode=as2&camp=1789&creative=390957&creativeASIN=0321636848) if you are doing any Core Audio programming. If you're not, then why are you here? :)

Loading the MIDI file is fairly straighforward. What is a pain is the timbres. Here I'm iterating though the track (using MusicEventIteratorGetEventInfo) and changing the preset in the SF2 or DLS file to any program change message that is encountered.  Nothing special, but the last one wins. The real problem is a midi file with many tracks each with its own program change. What do you do? No problem if you send the messages to an external device, but so you want to set up a sampler audio unit for each track for local playback? I guess that's what you have to do.

License
-------

You may incorporate this code in your own applications.

Attribution is welcomed, but not required.

Copyright (c) 2010-2012 Gene De Lisa. All rights reserved.


Release Notes
-------------

* Latest
Initial release