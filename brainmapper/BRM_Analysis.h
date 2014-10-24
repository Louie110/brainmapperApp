//
//  BRM_Analysis.h
//  brainmapper
//
//  Created by Joost Wagenaar on 10/20/14.
//  Copyright (c) 2014 University of Pennsylvania. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRM_Analysis : NSObject
-(void) stackDicoms;
-(BRM_Analysis *) initWithMriPath: (NSString *)mri_p
                           ctPath:(NSString *)ct_p
                         destPath:(NSString *)dstPath
                          resPath:(NSString *)rsPath
                           doSegm:(Boolean) segm
                        debugMode:(Boolean) dBugMode;
-(void) stack: (NSArray*) dcmArray;
-(void) startAnalysis;
-(void)cleanUpNiftis:(NSArray*)inputArray;
-(void) abortCoreg;
-(void) redirectNSLogToFile:(NSString*)logPath;
-(void) cleanUp;


@property (copy) NSString *destPath, *resPath, *ctPath, *mriPath, *updateFilePath;
@property int status;
@property NSFileManager *fileManager;
@property Boolean isAborted;


@end

