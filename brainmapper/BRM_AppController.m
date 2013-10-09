//
//  BRM_AppController.m
//  brainmapper
//
//  Created by Joost Wagenaar on 11/6/12.
//  Contributors: Allison Pearce, Veena Krish
//  Copyright (c) 2012 University of Pennsylvania. All rights reserved.
//

#import "BRM_AppController.h"
//just in case....

#include <sys/event.h>
#include <sys/time.h>
#include <stdlib.h>
#include <stdio.h>

@implementation BRM_AppController;
@synthesize inclSegm, textField, targetPathCtl, destPath, resPath, window, ctPathCtl, mriPathCtl;
@synthesize destPathPopover, checkBoxesPopover, tableViewPopover, progressPopover;

NSString *updateFilePath, *logPath;
NSString *newTime;
NSString *Time;
int stackingCompleted = 0;
int programFinished = 0;

- (id)init
{
	self = [super init];
    if(self){
        NSLog( @"init" );
        destPath = [[NSString alloc] init];
        _mriPath = [[NSString alloc] init];
        _ctPath = [[NSString alloc] init];
        
    }
    
    //This is just for checking to see that we have the right resources, not actually involved in coregistration
    resPath=[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] resourcePath]];
    NSLog(@"resource path is: %@", resPath);
    NSError *err;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:resPath error:&err];
    NSLog(@"contents of respath directory:%@",contents);
    
    return self;
    
}


//initialize everything that's displayed
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [textField setEditable:FALSE];

    [processInd setStyle:NSProgressIndicatorBarStyle];
    [processInd setIndeterminate:NO];
    
    [targetPathCtl setDoubleAction:@selector(pathControlDoubleClick:)];
    [mriPathCtl setDoubleAction:@selector(pathControlDoubleClick:)];
    [ctPathCtl setDoubleAction:@selector(pathControlDoubleClick:)];
    
    //[mriView setAllowsMultipleSelection:YES];
    //[ctView setAllowsMultipleSelection:YES];
    
    //[threshSlider setAltIncrementValue:100];
    //[threshSlider setMinValue:1000];
    //[threshSlider setMaxValue:3000];

    //this might be a good idea
    [self redirectNSLogToFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"NSLogConsole.txt"]];
    NSLog(@"redirectNSLogToFile called");
    
    
    //NSImage *bgImage = [[NSImage alloc] initByReferencingFile:@"/Users/VeenaKrish/Desktop/background.png"];
    //[window setBackgroundColor:[NSColor colorWithPatternImage:bgImage]];
    
    
}


//(Apologies for the repetition....will make this better one day....)
-(IBAction)destPathHelpButtonPushed:(id)sender {
    
    if ([destPathHelpButton state]) {
        NSLog(@"destPathHelpButton pressed");
        [destPathPopover showRelativeToRect:[destPathHelpButton bounds]
                             ofView:destPathHelpButton
                      preferredEdge:NSMaxYEdge];
        
    } else {
        NSLog(@"destPathPopover closing");
        [destPathPopover close];
    }
}
- (IBAction)checkBoxesHelpButtonPushed:(id)sender {
    if ([checkBoxesHelpButton state]) {
        NSLog(@"checkBoxesHelpButton pressed");
        [checkBoxesPopover showRelativeToRect:[checkBoxesHelpButton bounds]
                              ofView:checkBoxesHelpButton
                       preferredEdge:NSMaxYEdge];
        
    } else {
        NSLog(@"popover2 closing");
        [checkBoxesPopover close];
    }
}
- (IBAction)tableViewHelpButtonPushed:(id)sender{
    if ([tableViewHelpButton state]) {
        NSLog(@"helpButton3 pressed");
        [tableViewPopover showRelativeToRect:[tableViewHelpButton bounds]
                              ofView:tableViewHelpButton
                       preferredEdge:NSMaxYEdge];
        
    } else {
        NSLog(@"popover3 closing");
        [tableViewPopover close];
    }    
}
-(IBAction)progressHelpButtonPushed:(id)sender {
    
    if ([progressHelpButton state]) {
        NSLog(@"progressHelpButton pressed");
        [progressPopover showRelativeToRect:[progressHelpButton bounds]
                                     ofView:progressHelpButton
                              preferredEdge:NSMaxYEdge];
        
    } else {
        NSLog(@"progressPopover closing");
        [progressPopover close];
    }
}


//good idea to set this on....need to check, though, that stout from the bins in coreg also gets redirected
- (void) redirectNSLogToFile:(NSString*)logPath {
    //logPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"NSLogConsole.txt"];
    NSLog(@"logPath is: %@", logPath);
    freopen([logPath fileSystemRepresentation], "a+",stderr);
}

-(void)incrementProgress:(NSNumber*)target {
    double delta = [target doubleValue];
    [processInd setDoubleValue:delta];
    [processInd displayIfNeeded];
    }

-(void)pathControlDoubleClick:(id)sender {
    if ([targetPathCtl clickedPathComponentCell] != nil) {
        [[NSWorkspace sharedWorkspace] openURL:[targetPathCtl URL]];
        NSLog(@"targetPathCtl double click");
    }
    else if ([mriPathCtl clickedPathComponentCell] != nil) {
        [[NSWorkspace sharedWorkspace] openURL:[mriPathCtl URL]];
        NSLog(@"mriPathCtl double click");
    }
    else if ([ctPathCtl clickedPathComponentCell] != nil ) {
        [[NSWorkspace sharedWorkspace] openURL:[ctPathCtl URL]];
        NSLog(@"ctPathCtl double click");
    }
}

/*-(void)targetPathControlDoubleClick:(id)sender {
    if ([targetPathCtl clickedPathComponentCell] != nil) {
        [[NSWorkspace sharedWorkspace] openURL:[targetPathCtl URL]];
    }
}

-(void)mriPathControlDoubleClick:(id)sender {
    if ([mriPathCtl clickedPathComponentCell] != nil) {
        [[NSWorkspace sharedWorkspace] openURL:[mriPathCtl URL]];
    }
}

-(void)ctPathControlDoubleClick:(id)sender {
    if ([ctPathCtl clickedPathComponentCell] != nil ) {
        [[NSWorkspace sharedWorkspace] openURL:[ctPathCtl URL]];
    }
}*/

-(void)generateUpdate:(NSString *)words {
    /*
     These are the ways you've tried updating textField. If the current method breaks in the future, you might want to retry some of these
     [ self performSelectorOnMainThread:@selector(generateUpdate:)
     withObject:@"Please drag DICOM files from MRI into window and Start again"
     waitUntilDone:YES ];
     [self generateUpdate:@"Please drag mri dicoms into window"];
     NSLog(@"currentThead: %i", [[NSThread currentThread] isExecuting]); this line might be useful sometime
     (might need a startStart method that performs the start: selector in the background...)
     
     (dispatch queues, though, are prob better to work with than the performSelector method...works pretty well...)
     bgqueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0);
     main = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0);
     */
    
    //PleaseWorkThx
    [textField setStringValue:words];
    [NSThread sleepForTimeInterval:0.5];
    //AndWhereAreYou?
  /*  if (![NSThread isMainThread]) {
        NSLog(@"generateUpdate called with %@ on: %@ with priority %f", words, [[NSThread currentThread] description], [[NSThread currentThread] threadPriority]);
    } else {
        NSLog(@"generateUpdate called with: %@ on main, with priority %f", words, [[NSThread currentThread] threadPriority]);
    } */
    
}

//Here we goooo

- (IBAction)start:(id)sender;
{
    
    Boolean hasDepth=false;
    NSLog(@"Start started, with: has depth? %i and inclSegm? %i....operations on  %@ with priority: %f", !hasDepth, !inclSegm, [[NSThread currentThread] description], [[NSThread currentThread] threadPriority]);
    
    //specifying output directory
    destPath = [[targetPathCtl URL] path];
    _mriPath = [[mriPathCtl URL] path];
    _ctPath = [[ctPathCtl URL] path];
    logPath = [destPath stringByAppendingPathComponent:@"NSLogConsole.txt"];
    [self redirectNSLogToFile:logPath];
    
    
    //creating log file
    updateFilePath = [NSString stringWithFormat:@"%@/udpateFile.txt",destPath];
    system([[NSString stringWithFormat:@"echo This is the Update File >> %@", updateFilePath] UTF8String]);
    system([[NSString stringWithFormat:@"echo continuing to Stack DICOMs and convert images >> %@", updateFilePath] UTF8String]);
    NSLog(@"Update File created? %@", updateFilePath);



    //Check if MRI array and CT arrays are empty and if destPath hasn't been changed from /Applications......if so, alert the user
      //if ([mriArray count] == 0) {
    if (![_mriPath hasSuffix:@".dcm"]) {
        [destPathPopover close];
            NSLog(@"no mri dcm input");
                [self generateUpdate:@"Please drag one DICOM file from MRI into path bar"];
            [tableViewHelpButton setState:1];
            [self tableViewHelpButtonPushed:self];
            return;
        }
        else if (![_ctPath hasSuffix:@".dcm"]) {
                [self generateUpdate:@"Please drag one DICOM file from CT into path bar and start again"];
            [tableViewHelpButton setState:1];
            [self tableViewHelpButtonPushed:self];
            return;
        } else if ([destPath isEqualToString:@"/Applications"]) {
                [self generateUpdate:@"Please specify a destination folder for the coregistered images"];
                [destPathHelpButton setState:1];
                [self destPathHelpButtonPushed:self];
                return;
        }
        
    
    
    [self stackDicoms:_mriPath forFile:@"mri"];
    [self performSelectorInBackground:@selector(monitorUpdateFile) withObject:nil];
    [self stackDicoms:_ctPath forFile:@"ct"];
    
    //and if both stackDicomArray calls returned successfully, start coregScript
    if ( stackingCompleted == 2 ) {
        [self incrementProgress:[NSNumber numberWithDouble:6.0]];
        [self performSelectorInBackground:@selector(coregScript) withObject:nil];
        }
    
}

-(void) monitorUpdateFile {
    //monitors kernel events (supposedly without polling) and reports when changes have been made to a file
    
    //set up kernel queue and get filedes of updateFile.txt
    int kq = kqueue(); 
    int fildes = [[NSFileHandle fileHandleForReadingAtPath:updateFilePath] fileDescriptor];
    
    //check for event change every second
    struct timespec timeout; 
    timeout.tv_sec = 1;
    
    struct kevent changeList, eventList; //structures that note kernel events
    EV_SET( &changeList, fildes, 
           EVFILT_VNODE,
           EV_ADD | EV_CLEAR | EV_ERROR,
           NOTE_DELETE | NOTE_WRITE | NOTE_RENAME | NOTE_EXTEND,
           0, 0);

    while (!programFinished) { //throughout the process
        
        int event_count = kevent(kq, &changeList, 1, &eventList, 1, &timeout);
        if (event_count) { //if a kernel event has been detected
            
            // report the last line of the changed file to another method that will update the gui
            NSString *fileContents = [NSString stringWithContentsOfFile:updateFilePath encoding:NSUTF8StringEncoding error:nil];
            NSArray* sameLine = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSString *lastLine = [sameLine objectAtIndex:([sameLine count] -2)];

            // if you echo numbers to updateFile.txt, it'll incrementProgress instead of generateUpdate
            if ( [lastLine length] <= 2 ) {
                NSNumber* target = [[NSNumber alloc] initWithInt:[lastLine intValue]];
                [self performSelectorOnMainThread:@selector(incrementProgress:) withObject:target waitUntilDone:YES];
            }
            else {
                [self performSelectorOnMainThread:@selector(generateUpdate:) withObject:lastLine waitUntilDone:YES]; //make sure that the method that updates has priority over everything else that's happening
                
            }
        }
    }
}

- (void) stackDicoms:(NSString*) inDcm
                 forFile:(NSString*) inFile
{ //This method converts dicoms to nii's and gzips them. Should output the images:
  // mri.nii.gz and ct.nii.gz into the directory specified at destPath


    NSLog(@"background operations for stackDicomArray...on main? %i", [NSThread isMainThread]);

    NSError *err;
    NSFileManager *fileManager= [[NSFileManager alloc] init];
    
    system([[NSString stringWithFormat:@"echo Stacking Dicoms, zipped nii files will be located in spcified folder >> %@", updateFilePath] UTF8String]);
    
    //[self performSelectorOnMainThread:@selector(generateUpdate:) withObject:@"Stacking DICOMS...zipped nii files will be located in specified folder" waitUntilDone:YES];
    

        NSString *execPath = [NSString stringWithFormat:@"%@/dcm2nii",resPath]; 
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: execPath];
        NSLog(@"exec path is: %@, input arg is %@", execPath, inDcm);
        //[task setArguments:[NSArray arrayWithObject:[arr objectAtIndex:0]]];
        [task setArguments:[NSArray arrayWithObject:inDcm]];
        [task launch];
        [task waitUntilExit];
    
    NSNumber *prog = [NSNumber numberWithDouble:5.0];
    [self incrementProgress:prog];
        
    //figure out which .nii.gz file is the one we need
        NSString *dcmPath = [inDcm stringByDeletingLastPathComponent];
        NSArray *niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
        NSString *nifti;
        NSLog(@"niftis count: %ld", (unsigned long)[niftis count]);
    
        
        if ([niftis count] == 3) {
            nifti = [[niftis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'co'"]] objectAtIndex:0]; //(ie, if there's a co, that's what you need)
        } else if ([niftis count] == 2) {
            nifti = [[niftis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'o'"]] objectAtIndex:0]; //(if there's only an o, it didn't need to crop, so use that)
        } else if ([niftis count] == 1) {
            nifti = [niftis objectAtIndex:0]; //(or just use whatever?)
        } else {
            NSLog(@"error: incorrect number of nifti files"); //unless it didn't work...
            return;
        }
        NSString *movePath = [NSString stringWithFormat:@"%@/%@.nii.gz",destPath,inFile]; //move
        NSString *fromPath = [NSString stringWithFormat:@"%@/%@",dcmPath,nifti];
    
    NSLog(@"moving .nii.gz files to: %@", movePath);

        //make sure there aren't multiple files of the same name
        if ([fileManager fileExistsAtPath:movePath]) {
            int append = 1;
            while([fileManager fileExistsAtPath: [NSString stringWithFormat:@"%@/%@_%d", destPath, inFile, append]]) {
                append++;
            }
            movePath = [NSString stringWithFormat:@"%@/%@_%d", destPath, inFile, append];
        }
        
        NSLog(@"moving %@ to %@", fromPath, movePath);
        system([[NSString stringWithFormat:@"echo Moving niftis to specified folder >> %@", updateFilePath] UTF8String]);
        if(![fileManager moveItemAtPath:fromPath toPath:movePath error:&err]) {
            NSLog(@"error with moving nifti file: %@",err);
        }
        
        //remove the remaining niftis
        if ([niftis count] > 1) {
            niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath error:&err] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
            for (NSString* nii_file in niftis) {
                if(![fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath,nii_file] error:&err]) { NSLog(@"Error removing additional niftis"); }
            }
        }
    
    
    
        stackingCompleted++;
    return;
    
}


- (void) coregScript
{
    NSLog(@"coregScript started");
    
    //(to do: allow user to set threshold value)
    int thresh = 2000;
    
    Boolean hasDepth= false;
    NSString *execPath = [NSString stringWithFormat:@"source %@/Coregistration.sh %@ %@ %@ %i %i %d",resPath, resPath, destPath, updateFilePath, (!inclSegm), (hasDepth), thresh];
    NSLog(@"system call: %@",execPath);
    const char* arg = [execPath cStringUsingEncoding:[NSString defaultCStringEncoding]];
    int status = system(arg);
    NSLog(@"System call returned %d", status);
    
    programFinished = 1;


}


//possibly rewrite digElectrodes here.....it works as the .sh but it's extremely slow because of all the math....

                       
                
/*
#pragma mark TableView methods
- (void) acceptFilenameDrag:(NSArray *) filename
{
    
    if([filename objectAtIndex:1]==mriView){
        [mriArray addObject:[filename objectAtIndex:0]];
        NSLog(@"addObject");
        [mriView reloadData];
    }
    else if([filename objectAtIndex:1] == ctView){
        [ctArray addObject:[filename objectAtIndex:0]];
        NSLog(@"addObject");
        NSLog([NSString stringWithFormat:@"%ld",[ctArray count] ] );
        [ctView reloadData];
        
    }
    
    
	
} 
 
- (int)numberOfRowsInTableView:(NSTableView *)tableView {
    
    if(tableView==mriView){
        
        return (int)[mriArray count];
    }
    else if(tableView == ctView){
        return (int)[ctArray count];
    }
    else
    {
        return 0;
    }
}


- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(int)row
{
    
    if(tableView==mriView){
        
        return [mriArray objectAtIndex:row];    }
    else if(tableView == ctView){
        return [ctArray  objectAtIndex:row];
    }
    else {
        return 0;
    }
    
}
 */


@end
