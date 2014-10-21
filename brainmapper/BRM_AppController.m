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
NSThread* analysisThread;
BRM_Analysis *analysisObj;

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
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
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
-(void) redirectNSLogToFile:(NSString*)logPath {
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
    [textField setStringValue:words];
    [NSThread sleepForTimeInterval:0.5];
    
}
-(IBAction)start:(id)sender;{
    
    if (![startButton state]) //Close app if it's already running
    {
        if (analysisThread) {
            NSLog(@"Aborting Analysis");
            [analysisObj abortCoreg];
        }
        
//        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(coregScript) object:nil];
//        [startButton setTitle:@"start"];
//        NSLog(@"starButton state != 0");
//        [self incrementProgress:[NSNumber numberWithDouble:0.0]];
//        [self cleanUp];
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
//            [self generateUpdate:@"Please specify a destination folder for the coregistered images"];
//            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (_mriPath == nil) {
            NSLog(@"no mri dcm input");
//            [self generateUpdate:@"No MRI dicom images detected. Please drag one DICOM from MRI into path bar"];
//            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (_ctPath == nil) {
            NSLog(@"no ct dcm input");
//            [self generateUpdate:@"No CT dicom images detected. Please drag one DICOM from CT into path bar"];
//            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (![_mriPath hasSuffix:@".dcm"]) {
            NSLog(@"mri images not dicom");
//            [self generateUpdate:@"MRI image is not recognized as a DICOM. Please make sure the image ends in '.dcm'"];
//            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (![_ctPath hasSuffix:@".dcm"]) {
//            [self generateUpdate:@"Please drag one DICOM file from CT into path bar and start again"];
//            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        
        //when running, the title of the button should change to "stop"
        [startButton setTitle:@"stop"];
  
        analysisObj = [[BRM_Analysis alloc] initWithMriPath:_mriPath
                                                                   ctPath:_ctPath
                                                                 destPath:destPath
                                                                  resPath:resPath];

        analysisThread = [[NSThread alloc] initWithTarget:analysisObj
                                                           selector:@selector(startAnalysis)
                                                             object: nil];
        
        [[NSNotificationCenter defaultCenter]addObserver:self
                                                selector:@selector(threadExited:)
                                                    name:NSThreadWillExitNotification
                                                  object:analysisThread];
        
        [analysisThread start];
        NSLog(@"Finished Back in Main");
    }
}

- (void)threadExited:(NSNotification *)noti {
    // Done with the analysis... Time to clean up.
    NSLog(@"Analysis finished...");
    if ([analysisObj isAborted]) {
        NSLog(@"Analysis aborted");
    }
    [startButton setTitle:@"Start"];
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



////Method to terminate execution of tasks if the application is stopped and to delete intermediate files at the end
//- (void) cleanUp {
//    
//    NSError *deleteErr;
//    
//    NSArray *finalImgs = [fileManager contentsOfDirectoryAtPath:destPath error:&deleteErr];
//    NSString* fileToDelete;
//    NSLog(@"In cleanup");
//    
////    //Case 1: clean up files after application finishes
////    if (programFinished == 1) {
////        [self generateUpdate:@"Coregistration process stopped"];
////        [self incrementProgress:[NSNumber numberWithDouble:100.0]];
////        
////        NSLog(@"programFinished in cleanUp: gonna delete files");
////        [self generateUpdate:@"Coregistration finished! Please find produced images in Final Images folder"];
////        NSLog(@"Deleting all files but the final .nii.gz's");
////        NSString *electrodePath;
////        if (!inclSegm)   {
////            NSLog(@"inclSegm");
////            electrodePath = [NSString stringWithFormat:@"%@/unburied_electrode_seg.nii.gz", destPath];
////        } else {
////            electrodePath = [NSString stringWithFormat:@"%@/unburied_electrode_seg.nii.gz", destPath];
////        }
////        NSLog(@"electrodePath is %@", electrodePath);
////        NSString *brainPath = [NSString stringWithFormat:@"%@/mri_brain.nii.gz", destPath];
////        NSString *nslogPath = [NSString stringWithFormat:@"%@/NSLogConsole.txt", destPath];
////        
////        for (NSString* file in finalImgs) {
////            fileToDelete = [NSString stringWithFormat:@"%@/%@", destPath, file];
////            NSLog(@"fileToDelete is %@", fileToDelete);
////            if ( [fileToDelete isEqualToString:electrodePath] | [fileToDelete isEqualToString:brainPath] | [fileToDelete isEqualToString:nslogPath] ) {
////                continue;
////            }
////            else if(![fileManager removeItemAtPath:fileToDelete error:&deleteErr]) {
////                NSLog(@"files: %@, %@", electrodePath, brainPath);
////                NSLog(@"Error removing %@: %@", file, deleteErr.localizedDescription);
////            }
////        }
////        
////    } else {
////        
////        NSLog(@"cleanUP called when prgramFinished == 0");
////        [self incrementProgress:[NSNumber numberWithDouble:0.0]];
////        [startButton setTitle:@"Start"];
////        //case for dealing with extra niftis in imagePath if the app is stopped before that task is finished:
////        if ([stackingTask isRunning]) {
////            
////            NSLog(@" stackingTask still Running so terminate and delete extra nii's in imagePath..");
////            [stackingTask terminate];
////            
////            NSString *dcmPath_mri = [_mriPath stringByDeletingLastPathComponent];
////            NSString *dcmPath_ct = [_ctPath stringByDeletingLastPathComponent];
////            NSError *err;
////            
////            //delete niis from _mriPath if they exist
////            NSArray *niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath_mri error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
////            NSLog(@"Removing niis from dcmPath: %@", dcmPath_mri);
////            if ([niftis count] > 0) {
////                for (NSString* nii_file in niftis) {
////                    NSLog(@" nii_file is %@ and fileToDelte is %@/%@", nii_file, dcmPath, nii_file);
////                    if(![fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath_mri,nii_file] error:&err]) { NSLog(@"Error removing additional niftis"); }
////                }
////            }
////            //again for _ctPath, if they exist
////            niftis = [[fileManager contentsOfDirectoryAtPath:dcmPath_ct error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
////            NSLog(@"Removing niis from dcmPath: %@", dcmPath_ct);
////            if ([niftis count] > 0) {
////                for (NSString* nii_file2 in niftis) {
////                    NSLog(@" nii_file is %@ and fileToDelte is %@/%@", nii_file2, dcmPath_ct, nii_file2);
////                    if(![fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath_ct,nii_file2] error:&err]) { NSLog(@"Error removing additional niftis"); }
////                }
////            }
////        }
////        
////        //And delete all files in the destination folder as well:
////        NSLog(@"Deleting all files in destination folder");
////        for (NSString* file in finalImgs) {
////            fileToDelete = [NSString stringWithFormat:@"%@/%@", destPath, file];
////            //if(![fileManager removeItemAtPath:fileToDelete error:&deleteErr]) {
////            //    NSLog(@"Error removing all files"); }
////            
////        }
////        
////        
////    }
//    
//    
//    //}
//    
//    
//    return;
//    
//}

@end
