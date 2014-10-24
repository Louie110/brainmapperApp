//
//  BRM_Analysis.m
//  brainmapper
//
//  Created by Joost Wagenaar on 10/20/14.
//  Copyright (c) 2014 University of Pennsylvania. All rights reserved.
//

#import "BRM_Analysis.h"

@implementation BRM_Analysis

@synthesize destPath, ctPath, mriPath, resPath, status, isAborted;
NSString* updateFilePath;
NSTask* coregTask;
NSMutableArray* tasks;
Boolean isAborted = false;
Boolean doSegmentation = false;
Boolean debugMode = false;

-(BRM_Analysis *) initWithMriPath: (NSString *)mri_p ctPath:(NSString*)ct_p destPath:(NSString*)dstPath resPath:(NSString *)rsPath doSegm:(Boolean) segm debugMode:(Boolean) dBugMode
{
    self = [super init];
    if (self){
        [self setMriPath: mri_p];
        [self setCtPath:ct_p];
        [self setDestPath:dstPath];
        [self setResPath:rsPath];
        debugMode = dBugMode;
        doSegmentation = segm;
        _fileManager= [NSFileManager defaultManager];
        updateFilePath = [NSString stringWithFormat:@"%@/updateFile.txt",destPath];
        tasks = [[NSMutableArray alloc]init];
        
        status = 0;
    }
    return self;
}

// To Redirect NSLog to a text file
-(void) redirectNSLogToFile:(NSString*)logPath {
    //logPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"NSLogConsole.txt"];
    NSLog(@"logPath is: %@", logPath);
    freopen([logPath fileSystemRepresentation], "a+",stderr);
}

- (void) startAnalysis {
    
    // Stack Dicoms
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Starting to Stack DICOMS" forKey:@"message"];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"update"
                                                        object:nil
                                                      userInfo:userInfo];
    
    [self stackDicoms];
    
    // StackDicoms creates two new threads that need to finish before continuing.
    while (status < 2 && !isAborted) {
        sleep(1);
    }

    // Do Coregistration
    userInfo = [NSDictionary dictionaryWithObject:@"Starting Coregistration" forKey:@"message"];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"update"
                                                        object:nil
                                                      userInfo:userInfo];
    [self coregScript];
    
    userInfo = [NSDictionary dictionaryWithObject:@"Finished Coregistration --> Cleaning up. " forKey:@"message"];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"update"
                                                            object:nil
                                                          userInfo:userInfo];
    [self cleanUp];
    
}

- (void) abortCoreg {
    if (tasks) {
        for (NSTask *item in tasks){
            NSLog(@"Interupting.....");
            [item interrupt];
            [item terminate];
        }
    }
    isAborted = true;
    
}

- (void)threadExited:(NSNotification *)noti {
    NSLog(@"Sub-thread exited");
    status++;
}


- (void) stackDicoms {
    // Create queue 
    dispatch_queue_t stackQueue = dispatch_queue_create("Stack queue", 0);
    
    NSArray *dcmArray1 = [NSArray arrayWithObjects: mriPath, @"mri", nil];
    NSThread* myThread1 = [[NSThread alloc] initWithTarget:self
                                                  selector:@selector(stack:)
                                                    object: dcmArray1];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(threadExited:) name:NSThreadWillExitNotification
                                              object:myThread1];
    dispatch_async( stackQueue, ^{
        [myThread1 start];
    });
    
    // Stack CT DICOMS
    NSArray *dcmArray2 = [NSArray arrayWithObjects: ctPath, @"ct", nil];
    NSThread* myThread2 = [[NSThread alloc] initWithTarget:self
                                                  selector:@selector(stack:)
                                                    object: dcmArray2];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(threadExited:) name:NSThreadWillExitNotification
                                              object:myThread2];
    dispatch_async( stackQueue, ^{
        [myThread2 start];
    });
}

- (void) stack: (NSArray*) dcmArray {
    NSTask *stackingTask;
    
    NSLog(@"Number of tasks is: %lu", [tasks count]);
    NSString* inDcm = [dcmArray objectAtIndex:0];
    NSString *execPath = [NSString stringWithFormat:@"%@/dcm2nii", resPath];
    stackingTask = [[NSTask alloc] init];
    [tasks addObject:stackingTask];
    [stackingTask setLaunchPath: execPath];
    NSLog(@"exec path is: %@, input arg is %@", execPath, inDcm);
    
    [stackingTask setArguments:[NSArray arrayWithObject:inDcm]];
    [stackingTask launch];
    [stackingTask waitUntilExit];
    [self cleanUpNiftis:dcmArray ];
    [tasks removeObject:stackingTask];
}

//This method deletes all other .nii.gz files produced by the dcm2nii executable called in the previous method: stackDicoms:NSArray. It renames the desired output nii.gz's as mri.nii.gz and ct.nii.gz, and moves them into the directory specified at destPath.
-(void)cleanUpNiftis:(NSArray*)inputArray {
    
    NSLog(@"CleanUPNiftis called");
    NSString* inDcm = [inputArray objectAtIndex:0];
    NSString* inFile = [inputArray objectAtIndex:1];
    NSString *dcmPath = [inDcm stringByDeletingLastPathComponent];
    
    //The dcm2nii algorithm produces multiple nifti files. This figures out which .nii.gz file is needed
    NSError *err;
    NSArray *niftis = [[_fileManager contentsOfDirectoryAtPath:dcmPath error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
    NSString *nifti;
    
    NSLog(@"niftis count: %ld", (unsigned long)[niftis count]);
    
    if ([niftis count] == 3) {
        nifti = [[niftis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'co'"]] objectAtIndex:0]; //(ie, if there's a co, that's what you need)
    } else if ([niftis count] == 2) {
        nifti = [[niftis filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'o'"]] objectAtIndex:0]; //(if there's only an o, it didn't need to crop, so use that)
    } else if ([niftis count] == 1) {
        nifti = [niftis objectAtIndex:0]; //(or just use whatever)
    } else {
        NSLog(@"error: incorrect number of nifti files");
        return;
    }
    
    // Move produced nifti file to the specified destination folder
    NSString *movePath = [NSString stringWithFormat:@"%@/%@.nii.gz", destPath, inFile];
    NSString *fromPath = [NSString stringWithFormat:@"%@/%@", dcmPath, nifti];
    
    //Make sure the move doesn't rewrite any existing images. (tacks _1 onto the end of the file if another shares its name)
    if ([_fileManager fileExistsAtPath:movePath]) {
        int append = 1;
        while([_fileManager fileExistsAtPath: [NSString stringWithFormat:@"%@/%@_%d", destPath, inFile, append]]) {
            append++;
        }
        movePath = [NSString stringWithFormat:@"%@/%@_%d", destPath, inFile, append];
    }
    
    // Move
    NSLog(@"moving %@ to %@", fromPath, movePath);

    if(![_fileManager moveItemAtPath:fromPath toPath:movePath error:&err]) {
        NSLog(@"error with moving nifti file: %@",err);
    }
    
    //Remove the remaining, unncessesary niftis
    if ([niftis count] > 1) {
        niftis = [[_fileManager contentsOfDirectoryAtPath:dcmPath error:&err] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
        for (NSString* nii_file in niftis) {
            if(![_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath,nii_file] error:&err]) { NSLog(@"Error removing additional niftis"); }
        }
    }
    
}

- (void) coregScript {

    if (!isAborted) {
        NSString *execPath = [NSString stringWithFormat:@"%@/Coregistration.sh", resPath];

        NSDictionary *environmentDict = [[NSProcessInfo processInfo] environment];
        NSString *shellString = [environmentDict objectForKey:@"SHELL"];
        
        NSLog(@"coregScript started");
        coregTask = [[NSTask alloc] init];
        [tasks addObject:coregTask];
        NSString *t = [NSString stringWithFormat:@"%@",shellString];
        NSString * doSegmStr = (doSegmentation) ? @"true" : @"false";
        [coregTask setLaunchPath: t];
        [coregTask setArguments: [NSArray arrayWithObjects:execPath, resPath, destPath, updateFilePath, doSegmStr, @"false", @"2000", nil]];

        [coregTask launch];
        [coregTask waitUntilExit];
        [tasks removeObject:coregTask];
    }
}

//Method to terminate execution of tasks if the application is stopped and to delete intermediate files at the end
- (void) cleanUp {
    
    NSError *deleteErr;
    NSArray *finalImgs = [_fileManager contentsOfDirectoryAtPath:destPath error:&deleteErr];
    NSString* fileToDelete;
    NSLog(@"In cleanup");
    NSMutableArray *keepFiles = [[NSMutableArray alloc] init];
    
    // Don't clean anything up in DebugMode
    if (debugMode){
        return;
    }
    
    //Case 1: clean up files after application finishes
    if (!isAborted) {

        [keepFiles addObject:[NSString stringWithFormat:@"%@/unburied_electrode_seg.nii.gz", destPath]];
        [keepFiles addObject:[NSString stringWithFormat:@"%@/electrode_seg.nii.gz", destPath]];
        [keepFiles addObject:[NSString stringWithFormat:@"%@/unburied_electrode_aligned.nii.gz", destPath]];
        [keepFiles addObject:[NSString stringWithFormat:@"%@/electrode_aligned.nii.gz", destPath]];
        [keepFiles addObject:[NSString stringWithFormat:@"%@/mri_brain.nii.gz", destPath]];
        [keepFiles addObject:[NSString stringWithFormat:@"%@/logFile.txt", destPath]];
        [keepFiles addObject:[NSString stringWithFormat:@"%@/coregister.log", destPath]];
        
        
        for (NSString* file in finalImgs) {
            fileToDelete = [NSString stringWithFormat:@"%@/%@", destPath, file];
            if ( [keepFiles containsObject:fileToDelete]) {
                continue;
            }
            else if(![_fileManager removeItemAtPath:fileToDelete error:&deleteErr]) {
                NSLog(@"Error removing %@: %@", file, deleteErr.localizedDescription);
            }
        }
    
    } else {

        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Program aborted --> Cleaning up. " forKey:@"message"];
        [[NSNotificationCenter defaultCenter] postNotificationName: @"update"
                                                            object:nil
                                                          userInfo:userInfo];
        
        NSLog(@"Program aborted --> Cleaning up.");
        
        
        NSString *dcmPath_mri = [mriPath stringByDeletingLastPathComponent];
        NSString *dcmPath_ct = [ctPath stringByDeletingLastPathComponent];
        NSError *err;

        //delete niis from _mriPath if they exist
        NSArray *niftis = [[_fileManager contentsOfDirectoryAtPath:dcmPath_mri error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
        NSLog(@"Removing niis from dcmPath: %@", dcmPath_mri);
        if ([niftis count] > 0) {
            for (NSString* nii_file in niftis) {
                NSLog(@" nii_file is %@ and fileToDelte is %@/%@", nii_file, dcmPath_mri, nii_file);
                if(![_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath_mri,nii_file] error:&err]) { NSLog(@"Error removing additional niftis"); }
            }
        }
        //again for _ctPath, if they exist
        niftis = [[_fileManager contentsOfDirectoryAtPath:dcmPath_ct error:&err]filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.nii.gz'"]];
        NSLog(@"Removing niis from dcmPath: %@", dcmPath_ct);
        if ([niftis count] > 0) {
            for (NSString* nii_file2 in niftis) {
                NSLog(@" nii_file is %@ and fileToDelte is %@/%@", nii_file2, dcmPath_ct, nii_file2);
                if(![_fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",dcmPath_ct,nii_file2] error:&err]) { NSLog(@"Error removing additional niftis"); }
            }
        }
        
        [keepFiles addObject:[NSString stringWithFormat:@"%@/logFile.txt", destPath]];

        //And delete all files in the destination folder as well:
        NSLog(@"Deleting all files in destination folder");
        for (NSString* file in finalImgs) {
            fileToDelete = [NSString stringWithFormat:@"%@/%@", destPath, file];
            if ( [keepFiles containsObject:fileToDelete]) {
                continue;
            }
            else if(![_fileManager removeItemAtPath:fileToDelete error:&deleteErr]) {
                NSLog(@"Error removing %@: %@", file, deleteErr.localizedDescription);
            }

        }
        
        NSLog(@"Cleanup finished.");

    }

return;
    
}



@end
