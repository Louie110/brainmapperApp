//
//  BRM_AppController.h
//  brainmapper
//
//  Created by Joost Wagenaar on 11/6/12.
//  Copyright (c) 2014 University of Pennsylvania. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BRM_Analysis.h"

@interface BRM_AppController : NSObject
{
    IBOutlet NSTextField *textField;
    IBOutlet NSButton *startButton;

    IBOutlet NSPathControl *targetPathCtl;
    IBOutlet NSPathControl *ctPathCtl;
    IBOutlet NSPathControl *mriPathCtl;
    IBOutlet NSButton *doSegmentationBtn;
 
    dispatch_queue_t bgqueue, main;
 
}

//properties related to view
@property (assign) IBOutlet NSWindow *window;
@property (nonatomic) NSView *corner;

//properties related to coregistration process
@property (copy) NSString *resPath;


//Methods & Actions Involved in Coregistration Process
- (IBAction)start:(id)sender;
- (void)pathControlDoubleClick:(id)sender;
- (BOOL)windowShouldClose:(id)sender;

//Methods & Actions Involved in providing feedback
- (void)generateUpdate:(NSString *)words;
- (void)monitorFile:(NSString*) path;
- (void)threadExited:(NSNotification *)noti;



@end
