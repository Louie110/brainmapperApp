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
    IBOutlet NSProgressIndicator *processInd;

    IBOutlet NSButton *destPathHelpButton;
    IBOutlet NSButton *checkBoxesHelpButton;
    IBOutlet NSButton *tableViewHelpButton;
    IBOutlet NSButton *progressHelpButton;
 
    NSString *destPath;
    Boolean inclSegm;
    dispatch_queue_t bgqueue, main;
   
    
}

//properties related to view
@property (assign) IBOutlet NSWindow *window;
@property (readonly) Boolean inclSegm;
@property (nonatomic) NSView *corner;

//properties related to coregistration process
@property (copy) NSString *destPath, *resPath, *ctPath, *mriPath;
@property (nonatomic) IBOutlet NSPathControl *targetPathCtl;
@property (nonatomic) IBOutlet NSPathControl *mriPathCtl, *ctPathCtl;
@property (strong, nonatomic) IBOutlet NSTextField *threshold;
@property (strong, nonatomic) IBOutlet NSButtonCell *startButtonText;

//properties related to providing feedback
@property (strong, nonatomic) IBOutlet NSTextField *textField;
@property (nonatomic) IBOutlet NSPopover *destPathPopover;
@property (nonatomic) IBOutlet NSPopover *checkBoxesPopover;
@property (nonatomic) IBOutlet NSPopover *tableViewPopover;
@property (nonatomic) IBOutlet NSPopover *progressPopover;


//Methods & Actions Involved in Coregistration Process
- (IBAction)start:(id)sender;
- (void)pathControlDoubleClick:(id)sender;
- (BOOL)windowShouldClose:(id)sender;

//Methods & Actions Involved in providing feedback
- (void)generateUpdate:(NSString *)words;
- (void)incrementProgress:(NSNumber*)target;
- (void)monitorFile:(NSString*) path;
- (void)threadExited:(NSNotification *)noti;



@end
