//
//  BRM_AppController.m
//  brainmapper
//
//  Created by Joost Wagenaar on 11/6/12.
//  Contributors: Allison Pearce, Veena Krish
//  Copyright (c) 2012 University of Pennsylvania. All rights reserved.
//

#import "BRM_AppController.h"

#include <sys/event.h>
#include <sys/time.h>
#include <stdlib.h>
#include <stdio.h>

@implementation BRM_AppController;
@synthesize inclSegm, textField, targetPathCtl, destPath, resPath, window, ctPathCtl, mriPathCtl;
@synthesize destPathPopover, checkBoxesPopover, tableViewPopover, progressPopover;

NSString *updateFilePath, *logPath, *dcmPath;
NSFileManager *fileManager;
NSString *newTime;
NSString *Time;
NSTask *stackingTask;
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
    
    //For checking to see that we have the right resources, not actually involved in coregistration
    resPath=[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] resourcePath]];
    NSLog(@"resource path is: %@", resPath);
    NSError *err;
    fileManager= [NSFileManager defaultManager];
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:resPath error:&err];
    NSLog(@"contents of respath directory:%@",contents);
    
    return self;
    
}


//initialize everything that's displayed
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [textField setEditable:FALSE];
    [[textField cell] setWraps:TRUE];
    [startButton setTitle:@"start"];
    [processInd setStyle:NSProgressIndicatorBarStyle];
    [processInd setIndeterminate:NO];
    
    [targetPathCtl setDoubleAction:@selector(pathControlDoubleClick:)];
    [mriPathCtl setDoubleAction:@selector(pathControlDoubleClick:)];
    [ctPathCtl setDoubleAction:@selector(pathControlDoubleClick:)];
    
    //Uncomment below to redirect NSLog to a text file:
    //[self redirectNSLogToFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"NSLogConsole.txt"]];
    NSError *err;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:resPath error:&err];
    NSLog(@"contents of respath directory:%@",contents);
    
    
    
    
}



// To Redirect NSLog to a text file
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


-(void)generateUpdate:(NSString *)words {
    /*
     Other things tried:
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
    [textField setStringValue:words];
    [NSThread sleepForTimeInterval:0.5];
    
}

- (IBAction)start:(id)sender;
{
    
    if (![startButton state]) //Close app if it's already running
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(coregScript) object:nil];
        [startButton setTitle:@"start"];
        NSLog(@"starButton state != 0");
        [self incrementProgress:[NSNumber numberWithDouble:0.0]];
        [self cleanUp];
        
    }
    else
    {
        // do Start-button action
        Boolean hasDepth=false;
        NSLog(@"Start started, with: has depth? %i and inclSegm? %i....operations on  %@ with priority: %f", !hasDepth, !inclSegm, [[NSThread currentThread] description], [[NSThread currentThread] threadPriority]);
        
        //specify output directory
        destPath = [[targetPathCtl URL] path];
        _mriPath = [[mriPathCtl URL] path];
        _ctPath = [[ctPathCtl URL] path];
        
        //create txt update file
        updateFilePath = [NSString stringWithFormat:@"%@/updateFile.txt",destPath];
        system([[NSString stringWithFormat:@"echo This is the Update File >> %@", updateFilePath] UTF8String]);
        system([[NSString stringWithFormat:@"echo Loading images >> %@", updateFilePath] UTF8String]);
        NSLog(@"Update File created? %@", updateFilePath);
        
        
        //Check if MRI array and CT arrays are empty and if destPath hasn't been changed from /Applications......
        //If so, alert the user and return
        if ([destPath isEqualToString:@"/Applications"]) {
            [self generateUpdate:@"Please specify a destination folder for the coregistered images"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (_mriPath == nil) {
            NSLog(@"no mri dcm input");
            [self generateUpdate:@"No MRI dicom images detected. Please drag one DICOM from MRI into path bar"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (_ctPath == nil) {
            NSLog(@"no ct dcm input");
            [self generateUpdate:@"No CT dicom images detected. Please drag one DICOM from CT into path bar"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (![_mriPath hasSuffix:@".dcm"]) {
            NSLog(@"mri images not dicom");
            [self generateUpdate:@"MRI image is not recognized as a DICOM. Please make sure the image ends in '.dcm'"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (![_ctPath hasSuffix:@".dcm"]) {
            [self generateUpdate:@"Please drag one DICOM file from CT into path bar and start again"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        
        //when running, the title of the button should change to "stop"
        [startButton setTitle:@"stop"];
        
        
        NSThread *operationThread = [NSThread currentThread];
        
        //Make sure that updates show during process
        [self performSelectorInBackground:@selector(monitorUpdateFile) withObject:nil];
        
        // Convert mri dicoms to nifti
        NSArray *dcmArray = [NSArray arrayWithObjects:_mriPath, @"mri", nil];
        [self performSelector:@selector(stackDicoms:) onThread:operationThread withObject:dcmArray waitUntilDone:YES];
        [self performSelector:@selector(cleanUpNiftis:) onThread:operationThread withObject:dcmArray waitUntilDone:YES];
        [self incrementProgress:[NSNumber numberWithDouble:5.0]];
        
        // Convert ct dicoms to nifti
        NSArray *dcmArrayct = [NSArray arrayWithObjects:_ctPath, @"ct", nil];
        [self performSelector:@selector(stackDicoms:) onThread:operationThread withObject:dcmArrayct waitUntilDone:YES];
        [self performSelector:@selector(cleanUpNiftis:) onThread:operationThread withObject:dcmArrayct waitUntilDone:YES];
        
        // If both previous operations were completed, run coregistration
        if (stackingCompleted == 2) {
            
            [self incrementProgress:[NSNumber numberWithDouble:10.0]];
            [self performSelectorOnMainThread:@selector(generateUpdate:) withObject:@"Coregistration algorithm is running" waitUntilDone:TRUE];
            system([[NSString stringWithFormat:@"echo Coregistration script is running. Please wait. >> %@", updateFilePath] UTF8String]); //Only this one works...
            [self performSelector:@selector(coregScript) onThread:operationThread withObject:nil waitUntilDone:YES]; }
        else {
            [self generateUpdate:@"Error in converting dicoms to niftis. Please delete all non-dicom files from image folders and try again."];
            return;
        }
    }
    
}

-(void) monitorUpdateFile {
    //monitors kernel events (without continuous polling) and reports when changes have been made to a file
    
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
            if ( [lastLine length] <= 3 ) {
                NSNumber* target = [[NSNumber alloc] initWithInt:[lastLine intValue]];
                [self performSelectorOnMainThread:@selector(incrementProgress:) withObject:target waitUntilDone:YES];
            }
            else {
                [self performSelectorOnMainThread:@selector(generateUpdate:) withObject:lastLine waitUntilDone:YES]; //make sure that the method that updates has priority over everything else that's happening
                
            }
        }
    }
}

//This method converts dicoms to nifti's and gzips them. It looks through the folder specified by one image and converts all other dicoms in the folder, as per the executable dcm2nii from MRIcron. This should be called in conjunction with the following method: cleanUpNiftis:NSArray
- (void) stackDicoms:(NSArray*)inputArray
{
    NSString* inDcm = [inputArray objectAtIndex:0];
    
    NSLog(@"stack Dicoms called on main thread");
    
    system([[NSString stringWithFormat:@"echo Converting dicoms to niifti. Zipped nii files will be located in spcified folder >> %@", updateFilePath] UTF8String]);
    
    NSString *execPath = [NSString stringWithFormat:@"%@/dcm2nii",resPath];
    stackingTask = [[NSTask alloc] init];
    [stackingTask setLaunchPath: execPath];
    NSLog(@"exec path is: %@, input arg is %@", execPath, inDcm);

    [stackingTask setArguments:[NSArray arrayWithObject:inDcm]];
    [stackingTask launch];
    [stackingTask waitUntilExit]; //******* <-- This freezes the ui until the dicoms have been made. Can't generate updates during this task, but it shouldn't take that long
    
    //Another way to do this:
    //NSString *execPath = [NSString stringWithFormat:@"%@/dcm2nii %@",resPath, inDcm];
    //const char* arg = [execPath cStringUsingEncoding:[NSString defaultCStringEncoding]];
    //int status = system(arg);
    //NSLog(@"System call returned %d", status);
    
    
}


//This method deletes all other .nii.gz files produced by the dcm2nii executable called in the previous method: stackDicoms:NSArray. It renames the desired output nii.gz's as mri.nii.gz and ct.nii.gz, and moves them into the directory specified at destPath.
-(void)cleanUpNiftis:(NSArray*)inputArray {
    NSLog(@"CleanUPNiftis called");
    NSString* inDcm = [inputArray objectAtIndex:0];
    NSString* inFile = [inputArray objectAtIndex:1];
    NSString *dcmPath = [inDcm stringByDeletingLastPathComponent];
    
    //The dcm2nii algorithm produces multiple nifti files. This figures out which .nii.gz file is needed
    NSError *err;
    NSArray *niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
    NSString *nifti;
    NSLog(@"niftis count: %ld", (unsigned long)[niftis count]);
    if ([niftis count] == 3) {
        nifti = [[niftis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'co'"]] objectAtIndex:0]; //(ie, if there's a co, that's what you need)
    } else if ([niftis count] == 2) {
        nifti = [[niftis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'o'"]] objectAtIndex:0]; //(if there's only an o, it didn't need to crop, so use that)
    } else if ([niftis count] == 1) {
        nifti = [niftis objectAtIndex:0]; //(or just use whatever)
    } else {
        NSLog(@"error: incorrect number of nifti files"); //If it didn't work, return. The counter 'stackingCompleted' should not increment to 2, so the user will be notified to delete problematic nifti's and try again.
        return;
    }
    
    // Move produced nifti file to the specified destination folder
    NSString *movePath = [NSString stringWithFormat:@"%@/%@.nii.gz",destPath,inFile];
    NSString *fromPath = [NSString stringWithFormat:@"%@/%@",dcmPath,nifti];
    NSLog(@"moving .nii.gz files to: %@", movePath);
    
    //Make sure the move doesn't rewrite any existing images. (tacks _1 onto the end of the file if another shares its name)
    if ([fileManager fileExistsAtPath:movePath]) {
        int append = 1;
        while([fileManager fileExistsAtPath: [NSString stringWithFormat:@"%@/%@_%d", destPath, inFile, append]]) {
            append++;
        }
        movePath = [NSString stringWithFormat:@"%@/%@_%d", destPath, inFile, append];
    }
    
    // Move
    NSLog(@"moving %@ to %@", fromPath, movePath);
    system([[NSString stringWithFormat:@"echo Moving niftis to specified folder >> %@", updateFilePath] UTF8String]);
    if(![fileManager moveItemAtPath:fromPath toPath:movePath error:&err]) {
        NSLog(@"error with moving nifti file: %@",err);
    }
    
    //Remove the remaining, unncessesary niftis
    if ([niftis count] > 1) {
        niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath error:&err] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
        for (NSString* nii_file in niftis) {
            if(![fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath,nii_file] error:&err]) { NSLog(@"Error removing additional niftis"); }
        }
    }
    
    stackingCompleted++;
    
}


- (void) coregScript
{
    NSLog(@"coregScript started");
    [self performSelectorOnMainThread:@selector(generateUpdate:) withObject:@"Coregistration algorithm is running" waitUntilDone:TRUE];
    system([[NSString stringWithFormat:@"echo Coregistration algorithm is running. This will take a while. >> %@", updateFilePath] UTF8String]);
    
    //Set the threshold intensity above which electrodes are detected. Future versions might allow the user to specify this.
    int thresh = 2000;
    
    //In this version, debugging is included by default. Future versions might allow the user to opt out.
    Boolean hasDepth= FALSE;

    NSString *execPath = [NSString stringWithFormat:@"source %@/Coregistration.sh %@ %@ %@ %i %i %d",resPath, resPath, destPath, updateFilePath, (!inclSegm), (!hasDepth), thresh];
    NSLog(@"system call: %@",execPath);
    const char* arg = [execPath cStringUsingEncoding:[NSString defaultCStringEncoding]];
    int status = system(arg);
    NSLog(@"System call returned %d", status);
    
    programFinished = 1;
    
    [self cleanUp];
    
    
}

//Method to terminate execution of tasks if the application is stopped and to delete intermediate files at the end
- (void) cleanUp {
    
    NSError *deleteErr;
    
    NSArray *finalImgs = [fileManager contentsOfDirectoryAtPath:destPath error:&deleteErr];
    NSString* fileToDelete;
    NSLog(@"did it get here?");
    
    //Case 1: clean up files after application finishes
    if (programFinished == 1) {
        [self generateUpdate:@"Coregistration process stopped"];
        [self incrementProgress:[NSNumber numberWithDouble:100.0]];
        
        NSLog(@"programFinished in cleanUp: gonna delete files");
        [self generateUpdate:@"Coregistration finished! Please find produced images in Final Images folder"];
        NSLog(@"Deleting all files but the final .nii.gz's");
        NSString *electrodePath;
        if (!inclSegm)   {
            NSLog(@"inclSegm");
            electrodePath = [NSString stringWithFormat:@"%@/unburied_electrode_seg.nii.gz", destPath];
        } else {
            electrodePath = [NSString stringWithFormat:@"%@/unburied_electrode_seg.nii.gz", destPath];
        }
        NSLog(@"electrodePath is %@", electrodePath);
        NSString *brainPath = [NSString stringWithFormat:@"%@/mri_brain.nii.gz", destPath];
        NSString *nslogPath = [NSString stringWithFormat:@"%@/NSLogConsole.txt", destPath];
        
        for (NSString* file in finalImgs) {
            fileToDelete = [NSString stringWithFormat:@"%@/%@", destPath, file];
            NSLog(@"fileToDelete is %@", fileToDelete);
            if ( [fileToDelete isEqualToString:electrodePath] | [fileToDelete isEqualToString:brainPath] | [fileToDelete isEqualToString:nslogPath] ) {
                continue;
            }
            else if(![fileManager removeItemAtPath:fileToDelete error:&deleteErr]) {
                NSLog(@"files: %@, %@", electrodePath, brainPath);
                NSLog(@"Error removing %@: %@", file, deleteErr.localizedDescription);
            }
        }
        
    } else {
        
        NSLog(@"cleanUP called when prgramFinished == 0");
        [self incrementProgress:[NSNumber numberWithDouble:0.0]];
        [startButton setTitle:@"Start"];
        //case for dealing with extra niftis in imagePath if the app is stopped before that task is finished:
        if ([stackingTask isRunning]) {
            
            NSLog(@" stackingTask still Running so terminate and delete extra nii's in imagePath..");
            [stackingTask terminate];
            
            NSString *dcmPath_mri = [_mriPath stringByDeletingLastPathComponent];
            NSString *dcmPath_ct = [_ctPath stringByDeletingLastPathComponent];
            NSError *err;
            
            //delete niis from _mriPath if they exist
            NSArray *niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath_mri error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
            NSLog(@"Removing niis from dcmPath: %@", dcmPath_mri);
            if ([niftis count] > 0) {
                for (NSString* nii_file in niftis) {
                    NSLog(@" nii_file is %@ and fileToDelte is %@/%@", nii_file, dcmPath, nii_file);
                    if(![fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath_mri,nii_file] error:&err]) { NSLog(@"Error removing additional niftis"); }
                }
            }
            //again for _ctPath, if they exist
            niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath_ct error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
            NSLog(@"Removing niis from dcmPath: %@", dcmPath_ct);
            if ([niftis count] > 0) {
                for (NSString* nii_file2 in niftis) {
                    NSLog(@" nii_file is %@ and fileToDelte is %@/%@", nii_file2, dcmPath_ct, nii_file2);
                    if(![fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath_ct,nii_file2] error:&err]) { NSLog(@"Error removing additional niftis"); }
                }
            }
        }
        
        //And delete all files in the destination folder as well:
        
        NSLog(@"Deleting all files in destination folder");
        for (NSString* file in finalImgs) {
            fileToDelete = [NSString stringWithFormat:@"%@/%@", destPath, file];
            //if(![fileManager removeItemAtPath:fileToDelete error:&deleteErr]) {
            //    NSLog(@"Error removing all files"); }
            
        }
        
        
    }
    
    
    //}
    
    
    return;
    
}


@end
