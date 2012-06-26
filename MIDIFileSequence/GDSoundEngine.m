//
//  GDSoundEngine.m
//  MIDIFileSequence
//
//  Just a sampler connected to RemoteIO. No mixer. 
//  Loads a DLS file.
//
//  Created by Gene De Lisa on 6/26/12.
//  Copyright (c) 2012 Rockhopper Technologies. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import "GDCoreAudioUtils.h"
#import "GDSoundEngine.h"

@interface GDSoundEngine()

@property (readwrite) AUGraph processingGraph;
@property (readwrite) AUNode samplerNode;
@property (readwrite) AUNode ioNode;
@property (readwrite) AudioUnit samplerUnit;
@property (readwrite) AudioUnit ioUnit;

@end

@implementation GDSoundEngine

@synthesize playing = _playing;
@synthesize processingGraph = _processingGraph;
@synthesize samplerNode = _samplerNode;
@synthesize ioNode = _ioNode;
@synthesize ioUnit = _ioUnit;
@synthesize samplerUnit = _samplerUnit;
@synthesize presetNumber = _presetNumber;

@synthesize musicSequence = _musicSequence;
@synthesize musicTrack = _musicTrack;
@synthesize musicPlayer = _musicPlayer;

- (id) init 
{
    if ( self = [super init] ) {
        [self createAUGraph];
        [self startGraph];
        [self setupSampler:self.presetNumber];
        [self loadMIDIFile];
    }
    
    return self;
}

#pragma mark - Audio setup
- (BOOL) createAUGraph
{
    NSLog(@"Creating the graph");
    
    CheckError(NewAUGraph(&_processingGraph),
			   "NewAUGraph");
    
    // create the sampler
    // for now, just have it play the default sine tone
	AudioComponentDescription cd = {};
	cd.componentType = kAudioUnitType_MusicDevice;
	cd.componentSubType = kAudioUnitSubType_Sampler;
	cd.componentManufacturer = kAudioUnitManufacturer_Apple;
	cd.componentFlags = 0;
	cd.componentFlagsMask = 0;
	CheckError(AUGraphAddNode(self.processingGraph, &cd, &_samplerNode), "AUGraphAddNode");
    
    
    // I/O unit
    AudioComponentDescription iOUnitDescription;
    iOUnitDescription.componentType          = kAudioUnitType_Output;
    iOUnitDescription.componentSubType       = kAudioUnitSubType_RemoteIO;
    iOUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    iOUnitDescription.componentFlags         = 0;
    iOUnitDescription.componentFlagsMask     = 0;
    
    CheckError(AUGraphAddNode(self.processingGraph, &iOUnitDescription, &_ioNode), "AUGraphAddNode");
    
    // now do the wiring. The graph needs to be open before you call AUGraphNodeInfo
	CheckError(AUGraphOpen(self.processingGraph), "AUGraphOpen");
    
	CheckError(AUGraphNodeInfo(self.processingGraph, self.samplerNode, NULL, &_samplerUnit), 
               "AUGraphNodeInfo");
    
    CheckError(AUGraphNodeInfo(self.processingGraph, self.ioNode, NULL, &_ioUnit), 
               "AUGraphNodeInfo");
    
    AudioUnitElement ioUnitOutputElement = 0;
    AudioUnitElement samplerOutputElement = 0;
    CheckError(AUGraphConnectNodeInput(self.processingGraph, 
                                       self.samplerNode, samplerOutputElement, // srcnode, inSourceOutputNumber
                                       self.ioNode, ioUnitOutputElement), // destnode, inDestInputNumber
               "AUGraphConnectNodeInput");
    
    
	NSLog (@"AUGraph is configured");
	CAShow(self.processingGraph);
    
    return YES;
}

- (void) startGraph
{
    if (self.processingGraph) {
        // this calls the AudioUnitInitialize function of each AU in the graph.
        // validates the graph's connections and audio data stream formats.
        // propagates stream formats across the connections
        Boolean outIsInitialized;
        CheckError(AUGraphIsInitialized(self.processingGraph,
                                        &outIsInitialized), "AUGraphIsInitialized");
        if(!outIsInitialized)
            CheckError(AUGraphInitialize(self.processingGraph), "AUGraphInitialize");
        
        Boolean isRunning;
        CheckError(AUGraphIsRunning(self.processingGraph,
                                    &isRunning), "AUGraphIsRunning");
        if(!isRunning)
            CheckError(AUGraphStart(self.processingGraph), "AUGraphStart");
        self.playing = YES;
    }
}
- (void) stopAUGraph {
    
    NSLog (@"Stopping audio processing graph");
    Boolean isRunning = false;
    CheckError(AUGraphIsRunning (self.processingGraph, &isRunning), "AUGraphIsRunning");
    
    if (isRunning) {
        CheckError(AUGraphStop(self.processingGraph), "AUGraphStop");
        self.playing = NO;
    }
}

#pragma mark - Sampler

- (void) setupSampler:(UInt8) pn;
{
    // propagates stream formats across the connections
    Boolean outIsInitialized;
    CheckError(AUGraphIsInitialized(self.processingGraph,
                                    &outIsInitialized), "AUGraphIsInitialized");
    if(!outIsInitialized) {
        return;
    }
    if(pn < 0 || pn > 127) {
        return;
    }
    NSURL *bankURL;
    /*
     bankURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] 
     pathForResource:@"FluidR3_GM" ofType:@"sf2"]];
     */
    bankURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] 
                                                  pathForResource:@"gs_instruments" ofType:@"dls"]];
    NSLog(@"set pn %d", pn);
    
    // fill out a bank preset data structure
    AUSamplerBankPresetData bpdata;
    bpdata.bankURL  = (__bridge CFURLRef) bankURL;
    bpdata.bankMSB  = kAUSampler_DefaultMelodicBankMSB;
    bpdata.bankLSB  = kAUSampler_DefaultBankLSB;
    bpdata.presetID = (UInt8) pn;
    
    // set the kAUSamplerProperty_LoadPresetFromBank property
    CheckError(AudioUnitSetProperty(self.samplerUnit,
                                    kAUSamplerProperty_LoadPresetFromBank,
                                    kAudioUnitScope_Global,
                                    0,
                                    &bpdata,
                                    sizeof(bpdata)), "kAUSamplerProperty_LoadPresetFromBank");
    
    NSLog (@"sampler ready");
}

- (void) setPresetNumber:(UInt8) p
{
    NSLog(@"setPresetNumber %d", p);
    
    _presetNumber = p;
    
    if(self.processingGraph)
        [self setupSampler:p];
}

#pragma mark -
#pragma mark Audio control
- (void)playNoteOn:(UInt32)noteNum :(UInt32)velocity 
{
    UInt32 noteCommand = 0x90 | 0;
    NSLog(@"playNoteOn %lu %lu cmd %lx", noteNum, velocity, noteCommand);
	CheckError(MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, velocity, 0), "NoteOn");
}

- (void)playNoteOff:(UInt32)noteNum
{
	UInt32 noteCommand = 0x80 | 0;
	CheckError(MusicDeviceMIDIEvent(self.samplerUnit, noteCommand, noteNum, 0, 0), "NoteOff");
}

- (void) loadMIDIFile
{
    // NSString * fileName = @"Ya-Gotta-Try;
    //  NSString * fileName = @"006Harpsichord";
    
    NSURL *midiFileURL = [[NSURL alloc] initFileURLWithPath:
                          [[NSBundle mainBundle] pathForResource:@"006Harpsichord" 
                                                          ofType:@"mid"]];
    if (midiFileURL) {
        NSLog(@"midiFileURL = '%@'\n", [midiFileURL description]);
    }
    
    
    
    CheckError(NewMusicPlayer(&_musicPlayer), "NewMusicPlayer");
    
    CheckError(NewMusicSequence(&_musicSequence), "NewMusicSequence");
    
    CheckError(MusicPlayerSetSequence(self.musicPlayer, self.musicSequence), "MusicPlayerSetSequence");
    
    
    CheckError(MusicSequenceFileLoad(self.musicSequence,
                                     (__bridge CFURLRef) midiFileURL,
                                     0, // can be zero in many cases
                                     kMusicSequenceLoadSMF_ChannelsToTracks), "MusicSequenceFileLoad");	
    
    //  MIDIEndpointRef aPlayerDestEndpoint;    
    //  aPlayerDestEndpoint = MIDIGetDestination(0);
    //  CheckError(MusicSequenceSetMIDIEndpoint(self.musicSequence, aPlayerDestEndpoint), "MusicSequenceSetMIDIEndpoint");
    
    CheckError(MusicSequenceSetAUGraph(self.musicSequence, self.processingGraph),
               "MusicSequenceSetAUGraph");
     
    CAShow(self.musicSequence);
    
    UInt32 trackCount;
    CheckError(MusicSequenceGetTrackCount(self.musicSequence, &trackCount), "MusicSequenceGetTrackCount");
    NSLog(@"Number of tracks: %lu", trackCount);
    MusicTrack track;
    for(int i = 0; i < trackCount; i++)
    {
        CheckError(MusicSequenceGetIndTrack (self.musicSequence, i, &track), "MusicSequenceGetIndTrack");
        
        MusicTimeStamp track_length;
        UInt32 tracklength_size = sizeof(MusicTimeStamp);
        CheckError(MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &track_length, &tracklength_size), "kSequenceTrackProperty_TrackLength");
        NSLog(@"Track length %f", track_length);
        
        MusicTrackLoopInfo loopInfo;
        UInt32 lisize = sizeof(MusicTrackLoopInfo);
        CheckError(MusicTrackGetProperty(track,kSequenceTrackProperty_LoopInfo, &loopInfo, &lisize ), "kSequenceTrackProperty_LoopInfo");
        NSLog(@"Loop info: duration %f", loopInfo.loopDuration);
        
        [self iterate:track];
    }
    
    CheckError(MusicPlayerPreroll(self.musicPlayer), "MusicPlayerPreroll");
}



- (void) iterate: (MusicTrack) track
{
	MusicEventIterator	iterator;
	CheckError(NewMusicEventIterator (track, &iterator), "NewMusicEventIterator");
    
    
    MusicEventType eventType;
	MusicTimeStamp eventTimeStamp;
    UInt32 eventDataSize;
    const void *eventData;
    
    Boolean	hasCurrentEvent = NO;
    CheckError(MusicEventIteratorHasCurrentEvent(iterator, &hasCurrentEvent), "MusicEventIteratorHasCurrentEvent");
    while (hasCurrentEvent)
    {
        MusicEventIteratorGetEventInfo(iterator, &eventTimeStamp, &eventType, &eventData, &eventDataSize);
        NSLog(@"event timeStamp %f ", eventTimeStamp);
        switch (eventType) {
                
            case kMusicEventType_ExtendedNote : {
                ExtendedNoteOnEvent* ext_note_evt = (ExtendedNoteOnEvent*)eventData;
                NSLog(@"extended note event, instrumentID %lu", ext_note_evt->instrumentID);

            }
                break ;
                
            case kMusicEventType_ExtendedTempo : {
                ExtendedTempoEvent* ext_tempo_evt = (ExtendedTempoEvent*)eventData;
                NSLog(@"ExtendedTempoEvent, bpm %f", ext_tempo_evt->bpm);

            }
                break ;
                
            case kMusicEventType_User : {
                MusicEventUserData* user_evt = (MusicEventUserData*)eventData;
                 NSLog(@"MusicEventUserData, data length %lu", user_evt->length);
            }
                break ;
                
            case kMusicEventType_Meta : {
                MIDIMetaEvent* meta_evt = (MIDIMetaEvent*)eventData;
                NSLog(@"MIDIMetaEvent, event type %d", meta_evt->metaEventType);

            }
                break ;
                
            case kMusicEventType_MIDINoteMessage : {
                MIDINoteMessage* note_evt = (MIDINoteMessage*)eventData;
                NSLog(@"note event channel %d", note_evt->channel);
                NSLog(@"note event note %d", note_evt->note);
                NSLog(@"note event duration %f", note_evt->duration); 
                NSLog(@"note event velocity %d", note_evt->velocity);}
                break ;
                
            case kMusicEventType_MIDIChannelMessage : {
                MIDIChannelMessage* channel_evt = (MIDIChannelMessage*)eventData;
                NSLog(@"channel event status %X", channel_evt->status);
                NSLog(@"channel event d1 %X", channel_evt->data1);
                NSLog(@"channel event d2 %X", channel_evt->data2);
                
                if(channel_evt->status == (0xC0 & 0xF0)) {
                    [self setPresetNumber:channel_evt->data1];
                }
            }
                break ;
                
            case kMusicEventType_MIDIRawData : {
                MIDIRawData* raw_data_evt = (MIDIRawData*)eventData;
                NSLog(@"MIDIRawData, length %lu", raw_data_evt->length);

            }
                break ;
                
            case kMusicEventType_Parameter : {
                ParameterEvent* parameter_evt = (ParameterEvent*)eventData;
                NSLog(@"ParameterEvent, parameterid %lu", parameter_evt->parameterID);

            }
                break ;
                
            default :
                break ;
        }
        
        CheckError(MusicEventIteratorHasNextEvent(iterator, &hasCurrentEvent), "MusicEventIteratorHasCurrentEvent");
        CheckError(MusicEventIteratorNextEvent(iterator), "MusicEventIteratorNextEvent");
    }
}

- (void) playMIDIFile
{
    NSLog(@"starting music player");
    CheckError(MusicPlayerStart(self.musicPlayer), "MusicPlayerStart");   
}

- (void) stopPlayintMIDIFile
{
    NSLog(@"stopping music player");
    CheckError(MusicPlayerStop(self.musicPlayer), "MusicPlayerStop");   
}


-(void) cleanup
{    
    CheckError(MusicPlayerStop(self.musicPlayer), "MusicPlayerStop");
    
    UInt32 trackCount;
    CheckError(MusicSequenceGetTrackCount(self.musicSequence, &trackCount), "MusicSequenceGetTrackCount");
    MusicTrack track;
    for(int i = 0;i < trackCount; i++)
    {
        CheckError(MusicSequenceGetIndTrack (self.musicSequence,0,&track), "MusicSequenceGetIndTrack");
        CheckError(MusicSequenceDisposeTrack(self.musicSequence, track), "MusicSequenceDisposeTrack");
    }
    
    CheckError(DisposeMusicPlayer(self.musicPlayer), "DisposeMusicPlayer");
    CheckError(DisposeMusicSequence(self.musicSequence), "DisposeMusicSequence");
    CheckError(DisposeAUGraph(self.processingGraph), "DisposeAUGraph");
}

@end
