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
Boolean programFinished = false;
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
    NSError *err;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:resPath error:&err];
    NSLog(@"contents of respath directory:%@",contents);
    

    
}

-(void)updateNotiHandler: (NSNotification *) notification
{
    NSDictionary *userInfo = notification.userInfo;
    NSString *message = (NSString *)[userInfo  objectForKey:@"message"];
    [textField setStringValue:message];
    NSLog(message);
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
}

-(IBAction)start:(id)sender;{
    
    if (![startButton state])
    {
        // Interupt tasks if user clicks on Stop.
        if (analysisThread) {
            NSLog(@"Aborting Analysis");
            [analysisObj abortCoreg];
        }
    } else
    {
        programFinished = false;
        // Create notification listener
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateNotiHandler:)
                                                     name:@"update"
                                                   object:nil];

        // Run Update Deamon for updates from shell-scripts.
//        [self performSelectorInBackground:@selector(monitorUpdateFile) withObject:nil];
        
        
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
        
        
        [self monitorFile:updateFilePath];
        
        // Redirect Log To results folder
        NSString* logFilePath = [NSString stringWithFormat:@"%@/logFile.txt", destPath];
        [self redirectNSLogToFile:logFilePath];
      
        //Check if MRI array and CT arrays are empty and if destPath hasn't been changed from /Applications......
        //If so, alert the user and return
        if ([destPath isEqualToString:@"/Applications"]) {
            [textField setStringValue:@"Please specify a destination folder for the coregistered images"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (_mriPath == nil) {
            NSLog(@"no mri dcm input");
            [textField setStringValue:@"No MRI dicom images detected. Please drag one DICOM from MRI into path bar"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (_ctPath == nil) {
            NSLog(@"no ct dcm input");
            [textField setStringValue:@"No CT dicom images detected. Please drag one DICOM from CT into path bar"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (![_mriPath hasSuffix:@".dcm"]) {
            NSLog(@"mri images not dicom");
            [textField setStringValue:@"Please drag one DICOM file from the MRI folder into path bar and presss Start again"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        if (![_ctPath hasSuffix:@".dcm"]) {
            [textField setStringValue:@"Please drag one DICOM file from the CT folder into path bar and presss Start again"];
            [self incrementProgress:[NSNumber numberWithDouble:0.0]];
            [startButton setState:0];
            return;
        }
        
        //when running, the title of the button should change to "stop"
        [startButton setTitle:@"Stop"];
  
        analysisObj = [[BRM_Analysis alloc] initWithMriPath:_mriPath
                                                     ctPath:_ctPath
                                                   destPath:destPath
                                                    resPath:resPath
                                                    doSegm:inclSegm];

        analysisThread = [[NSThread alloc] initWithTarget:analysisObj
                                                 selector:@selector(startAnalysis)
                                                   object: nil];
        
        // Redirect Log for tasks to results folder
        [analysisObj redirectNSLogToFile:logFilePath];
        
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
    programFinished = true;
    [self incrementProgress:[NSNumber numberWithDouble:0.0]];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)monitorFile:(NSString*) path {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    int fildes = open([path UTF8String], O_EVTONLY);
    
    __block typeof(self) blockSelf = self;
    __block dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fildes,
                                                              DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND |
                                                              DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME |
                                                              DISPATCH_VNODE_REVOKE, queue);
    dispatch_source_set_event_handler(source, ^{
        unsigned long flags = dispatch_source_get_data(source);
        // NSLog([NSString stringWithFormat:@"%d",flags]);
        if(flags & (DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE | DISPATCH_VNODE_ATTRIB))
        {
            dispatch_source_cancel(source);
            
            NSLog(@"Updating Progress in UI");
            // report the last line of the changed file to another method that will update the gui
            NSString *fileContents = [NSString stringWithContentsOfFile:updateFilePath encoding:NSUTF8StringEncoding error:nil];
            NSArray* sameLine =  [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            if (sameLine && [sameLine count]>2){
                NSString *lastLine = [sameLine objectAtIndex:([sameLine count] -2)];
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:lastLine forKey:@"message"];
                [[NSNotificationCenter defaultCenter] postNotificationName: @"update"
                                                                    object:nil
                                                                  userInfo:userInfo];
            }
            
            //
            // DO WHAT YOU NEED HERE
            //
            [blockSelf monitorFile:path];
        }
    });
    dispatch_source_set_cancel_handler(source, ^(void) {
        close(fildes);
    });
    dispatch_resume(source);
}


-(void) monitorUpdateFile {
    //monitors kernel events (without continuous polling) and reports when changes have been made to a file
    
    //set up kernel queue and get filedes of updateFile.txt
    int kq = kqueue();
    int fildes = [[NSFileHandle fileHandleForReadingAtPath:updateFilePath] fileDescriptor];
    
    //check for event change every second
    struct timespec timeout;
    timeout.tv_sec = 0.5;
    
    struct kevent changeList, eventList; //structures that note kernel events
    EV_SET( &changeList, fildes,
           EVFILT_VNODE,
           EV_ADD | EV_CLEAR ,
           NOTE_DELETE |  NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE,
           0, 0);
    
    while (!programFinished) { //throughout the process
        
        int event_count = kevent(kq, &changeList, 1, &eventList, 1, &timeout);
       // NSLog([NSString stringWithFormat:@"%d",event_count]);
        if (event_count >0) { //if a kernel event has been detected
            
            NSLog(@".....New Event");
            
            // report the last line of the changed file to another method that will update the gui
            NSString *fileContents = [NSString stringWithContentsOfFile:updateFilePath encoding:NSUTF8StringEncoding error:nil];
            NSArray* sameLine =  [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            if (sameLine && [sameLine count]>2){
               NSString *lastLine = [sameLine objectAtIndex:([sameLine count] -2)];
               NSDictionary *userInfo = [NSDictionary dictionaryWithObject:lastLine forKey:@"message"];
               [[NSNotificationCenter defaultCenter] postNotificationName: @"update"
                                                                    object:nil
                                                                  userInfo:userInfo];
            }
            
            
//            // if you echo numbers to updateFile.txt, it'll incrementProgress instead of generateUpdate
//            if ( [lastLine length] <= 3 ) {
//                NSNumber* target = [[NSNumber alloc] initWithInt:[lastLine intValue]];
//                [self performSelectorOnMainThread:@selector(incrementProgress:) withObject:target waitUntilDone:YES];
//            }
//            else {
//                [self performSelectorOnMainThread:@selector(generateUpdate:) withObject:lastLine waitUntilDone:YES]; //make sure that the method that updates has priority over everything else that's happening
//                
//            }
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
