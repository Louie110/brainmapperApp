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

-(BRM_Analysis *) initWithMriPath: (NSString *)mri_p ctPath:(NSString*)ct_p destPath:(NSString*)dstPath resPath:(NSString *)rsPath
{
    self = [super init];
    if (self){
        [self setMriPath: mri_p];
        [self setCtPath:ct_p];
        [self setDestPath:dstPath];
        [self setResPath:rsPath];
        _fileManager= [NSFileManager defaultManager];
        updateFilePath = [NSString stringWithFormat:@"%@/updateFile.txt",destPath];
        tasks = [[NSMutableArray alloc]init];
        
        status = 0;
    }
    return self;
}

- (void) startAnalysis {
    
    // Stack Dicoms
    [self stackDicoms];
    
    // StackDicoms creates two new threads that need to finish before continuing.
    while (status < 2 && !isAborted) {
        sleep(1);
    }

    // do Coregistration
    if (!isAborted){
        [self coregScript];
    }
    
}

- (void) abortCoreg {
    if (tasks) {
        for (NSTask *item in tasks){
            NSLog(@"Interupting.....");
            [item interrupt];
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
    [stackingTask waitUntilExit]; //******* <-- This freezes the ui until the dicoms have been made. Can't generate updates during this task, but it shouldn't take that long
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
        NSLog(@"error: incorrect number of nifti files"); //If it didn't work, return. The counter 'stackingCompleted' should not increment to 2, so the user will be notified to delete problematic nifti's and try again.
        return;
    }
    
    // Move produced nifti file to the specified destination folder
    NSString *movePath = [NSString stringWithFormat:@"%@/%@.nii.gz",destPath,inFile];
    NSString *fromPath = [NSString stringWithFormat:@"%@/%@",dcmPath,nifti];
    NSLog(@"moving .nii.gz files to: %@", movePath);
    
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
        [coregTask setLaunchPath: t];
        [coregTask setArguments: [NSArray arrayWithObjects:execPath, resPath, destPath, updateFilePath, @"false", @"false", @"2000", nil]];
  
        
        
        [coregTask launch];
        [coregTask waitUntilExit];
        [tasks removeObject:coregTask];
    }
    
    

}


@end
